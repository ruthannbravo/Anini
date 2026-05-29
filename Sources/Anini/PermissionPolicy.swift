import Foundation

/// Path helpers for any user-supplied path (workspace, protected paths, deny rule
/// construction). Centralized so tilde expansion and quoting can't silently no-op
/// the way `URL(fileURLWithPath:)` does with a bare `~/`.
enum Path {
    /// Expand a leading `~` or `~/` segment against the current user's home
    /// directory. Returns the input unchanged if it doesn't start with `~`.
    static func expand(_ s: String) -> String {
        (s as NSString).expandingTildeInPath
    }

    /// Shell-quote a path for use as a single argument. Wraps in single quotes
    /// and escapes any embedded single quotes via `'\''`. Safe for paths that
    /// contain spaces, parens, dollar signs, etc.
    static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escape a path for embedding inside an SBPL double-quoted string
    /// (sandbox-exec profile). Escapes backslashes and double quotes only.
    static func sbplEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

/// Verifies that a candidate executable is safe to launch with the user's
/// privileges and API key in its environment. A binary is trusted only if its
/// real (symlink-resolved) target exists, is executable, is a regular file, is
/// owned by root or the current user, and is not writable by group or other —
/// so a less-trusted process cannot plant or replace it. Used instead of
/// PATH/`which` resolution, which would honor an attacker-influenced PATH.
enum ExecutableTrust {
    /// Canonicalize a path, following symlinks, to its real on-disk location.
    /// Returns nil for a missing path or a broken link. We vet the *resolved*
    /// target rather than blanket-rejecting symlinks: the official `claude`
    /// installer ships `~/.local/bin/claude` as a symlink into
    /// `~/.local/share/claude/versions/<v>`, so rejecting all symlinks would
    /// make every official install untrusted. The trust guarantee is unchanged
    /// — it's the file that actually executes that must be a root/user-owned,
    /// non-group/other-writable regular file.
    static func realPath(_ path: String) -> String? {
        guard let c = realpath(path, nil) else { return nil }
        defer { free(c) }
        return String(cString: c)
    }

    static func isTrustedExecutable(_ path: String) -> Bool {
        let fm = FileManager.default
        guard let real = realPath(path) else { return false }
        guard fm.isExecutableFile(atPath: real) else { return false }
        // After resolution the target is symlink-free, so `.typeRegular` rejects
        // directories/devices/etc. without rejecting a symlinked launcher.
        guard let attrs = try? fm.attributesOfItem(atPath: real),
              (attrs[.type] as? FileAttributeType) == .typeRegular else { return false }

        // Owner must be root (0) or the current user.
        guard let ownerID = (attrs[.ownerAccountID] as? NSNumber)?.uintValue,
              ownerID == 0 || ownerID == UInt(getuid()) else { return false }

        // Must not be group- or other-writable.
        guard let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value,
              (perms & 0o022) == 0 else { return false }

        return true
    }

    /// Resolve `name` from `candidates`, returning a diagnostic when it can't be
    /// used. The reasons are ordered most-specific-first so Settings can tell the
    /// user exactly what to do: a trusted hit wins; otherwise we distinguish
    /// "exists but failed the safety check", "exists only in an ignored location
    /// (PATH/npm-global)", and "not found anywhere".
    static func resolve(name: String, candidates: [String], ignoredHints: [String]) -> ExecutableResolution {
        for path in candidates where isTrustedExecutable(path) {
            return .found(path: path)
        }
        let fm = FileManager.default
        for path in candidates where fm.fileExists(atPath: path) {
            return .unavailable(reason:
                "Found \(name) at \(abbreviate(path)), but it failed Anini's safety check — the "
                + "real file must be owned by you or root and not writable by group or others. "
                + "Anini won't launch it with your API key in its environment.")
        }
        let hits = ignoredHints.filter { fm.fileExists(atPath: $0) }
        if !hits.isEmpty {
            return .unavailable(reason:
                "\(name) is installed at \(hits.map(abbreviate).joined(separator: ", ")), but Anini "
                + "ignores PATH and npm-global locations for security — a package install or auto-update "
                + "could plant a binary there that would run with your API key. Install \(name) into one "
                + "of: \(candidates.map(abbreviate).joined(separator: ", ")).")
        }
        return .unavailable(reason:
            "No \(name) binary found in any location Anini trusts: "
            + "\(candidates.map(abbreviate).joined(separator: ", ")).")
    }

    /// Render `~` for the home prefix so diagnostics read cleanly in the UI.
    static func abbreviate(_ path: String) -> String {
        let home = Path.expand("~")
        if path == home { return "~" }
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}

/// Subprocess interrupt helper. The directly-owned process is normally
/// `/usr/bin/sandbox-exec`; the real CLI (and any Bash subprocesses it spawns)
/// are its descendants. SIGINT to sandbox-exec is forwarded to that child by
/// the kernel, but a wedged child could ignore it — so we escalate to SIGTERM
/// after a short grace period rather than leaving it running with the API key
/// in its environment.
enum ProcessGroup {
    /// No-op placeholder kept for call-site symmetry: on macOS we do not move
    /// the child into a separate process group (there is no stock `setsid`, and
    /// signaling a misattributed group risks the host app). Interrupt handles
    /// containment via SIGINT-then-SIGTERM escalation on the owned process.
    static func makeLeader(_ process: Process) {}

    /// Interrupt (SIGINT) the owned process, then escalate to terminate
    /// (SIGTERM) after a grace period if it is still running.
    static func interrupt(_ process: Process) {
        guard process.isRunning else { return }
        process.interrupt()
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            // Re-check the same process is still alive before escalating.
            if process.isRunning && process.processIdentifier == pid {
                process.terminate()
            }
        }
    }
}

/// Thread-safe ownership of the single in-flight subprocess a backend may be
/// running. Both backends launch at most one CLI process at a time and must be
/// able to interrupt it from another thread (the stop button) without racing a
/// concurrent launch. The lock guards every read/write of the owned process so
/// `interrupt()` can never observe a half-assigned value or signal a process
/// that has already been replaced.
final class ProcessOwner {
    private let lock = NSLock()
    private var current: Process?

    /// Atomically install `next` as the owned process and return the prior one
    /// (so the caller can interrupt it instead of orphaning it).
    func swap(_ next: Process?) -> Process? {
        lock.lock()
        defer { lock.unlock() }
        let prior = current
        current = next
        return prior
    }

    /// Clear ownership, but only if `proc` is still the owned process — avoids
    /// a late termination handler clobbering a process that already replaced it.
    func clear(if proc: Process) {
        lock.lock()
        defer { lock.unlock() }
        if current === proc { current = nil }
    }

    /// Snapshot the currently-owned process for signaling.
    func snapshot() -> Process? {
        lock.lock()
        defer { lock.unlock() }
        return current
    }
}

/// Single source of truth for "what the AI is allowed to touch" that both
/// backends consult. Derived from `WorkspaceConfig` + `SecurityLayer` once per
/// invocation; both backends build their CLI args + sandbox profile from this
/// rather than reading config ad-hoc.
struct PermissionPolicy {
    /// Mirrors `WorkspaceConfig.dangerouslySkipPermissions`. When false the
    /// backend must use its safest non-bypass mode.
    let allowFullAuto: Bool

    /// Absolute, tilde-expanded, deduped list of paths the AI must not touch.
    /// Filtered against the user's `unprotectedPaths` opt-outs.
    let protectedPaths: [String]

    /// Absolute, tilde-expanded workspace directory the subprocess is allowed to
    /// read and write. The sandbox re-allows this subtree after denying the home
    /// credential surface.
    let workspace: String

    static func current() -> PermissionPolicy {
        let config = WorkspaceConfig.shared
        let unprotected = config.unprotectedPaths
        let raw = SecurityLayer.shared.sensitivePaths
            .filter { !unprotected.contains($0.id) }
            .map { Path.expand($0.path) }

        // Dedupe while preserving order.
        var seen = Set<String>()
        var deduped: [String] = []
        for p in raw where seen.insert(p).inserted {
            deduped.append(p)
        }

        return PermissionPolicy(
            allowFullAuto: config.dangerouslySkipPermissions,
            protectedPaths: deduped,
            workspace: Path.expand(config.workspacePath)
        )
    }

    // MARK: - Claude Code CLI deny rules

    /// Tool-specific deny rules for Claude. Covers the file-tool surface
    /// (Read/Edit/Write/MultiEdit/NotebookEdit) plus a set of Bash patterns
    /// matching the protected substring — defense in depth on top of the
    /// kernel sandbox.
    ///
    /// Paths containing spaces are quoted with single quotes; the rule parser
    /// treats a single-quoted segment as one token, so the rule
    /// `Read('~/Library/Application Support/...')` parses correctly.
    var claudeDenyRules: [String] {
        guard !protectedPaths.isEmpty else { return [] }
        let fileTools = ["Read", "Edit", "Write", "MultiEdit", "NotebookEdit"]
        var rules: [String] = []
        for expanded in protectedPaths {
            let quotedForRule = expanded.contains(" ")
                ? "'" + expanded.replacingOccurrences(of: "'", with: "\\'") + "'"
                : expanded
            for tool in fileTools {
                rules.append("\(tool)(\(quotedForRule))")
                rules.append("\(tool)(\(quotedForRule)/**)")
            }
            // Bash rule uses `*<path>*` substring matching; quote the path
            // segment so paths with spaces parse as a single token. The
            // semantic match against runtime commands is best-effort
            // (rename/symlink/encode still evade); the sandbox-exec wrapper
            // is the actual guarantee.
            rules.append("Bash(*\(quotedForRule)*)")
        }
        return rules
    }

    /// Writes a Claude settings JSON containing the deny rules and returns
    /// its URL. Used with `claude --settings <path>` so protected paths do
    /// not appear in the subprocess argv (where `ps` could read them).
    /// Returns nil when there are no rules to write.
    func writeClaudeSettings(prefix: String) -> URL? {
        let rules = claudeDenyRules
        guard !rules.isEmpty else { return nil }
        let payload: [String: Any] = [
            "permissions": ["deny": rules]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [])
        else { return nil }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("anini-\(prefix)-\(UUID().uuidString).json")
        guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return url
    }

    /// Sweep orphaned profile/settings files in the temp dir left over from
    /// previous Anini runs that died before their `terminationHandler` could
    /// clean up (SIGKILL, panic, machine reboot). Called once at app launch.
    /// Only files older than `minAgeSeconds` are removed so an active
    /// subprocess from a sibling Anini instance is never disturbed.
    static func cleanupOrphans(minAgeSeconds: TimeInterval = 3600) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-minAgeSeconds)
        for url in entries {
            let name = url.lastPathComponent
            guard name.hasPrefix("anini-"),
                  name.hasSuffix(".sb") || name.hasSuffix(".json")
            else { continue }
            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date.distantPast
            if mtime < cutoff {
                try? fm.removeItem(at: url)
            }
        }
    }

    // MARK: - macOS Seatbelt sandbox profile

    /// Builds a default-deny SBPL profile for the credential surface. The whole
    /// home directory is denied for both read and write, then the workspace and
    /// the CLIs' own config/state dirs are re-allowed. This protects *every*
    /// secret under $HOME — not just the hardcoded `protectedPaths` list — so an
    /// unanticipated credential store (e.g. ~/.kube, ~/.docker, browser cookie
    /// DBs) is contained by default.
    ///
    /// Non-file operations (exec, network, signals) stay allowed so the CLI can
    /// run and reach its provider. The profile is always produced (never nil),
    /// so containment never depends on the bypassable string-match deny rules.
    /// The explicit `protectedPaths` are denied last as defense-in-depth.
    func sandboxProfile() -> String? {
        let home = Path.expand("~")
        func deny(_ p: String) -> String {
            "(deny file-read* file-write* (subpath \"\(Path.sbplEscaped(p))\"))"
        }
        func allow(_ p: String) -> String {
            "(allow file-read* file-write* (subpath \"\(Path.sbplEscaped(p))\"))"
        }

        var lines = ["(version 1)", "(allow default)"]

        let ws = Path.expand(workspace)
        if !ws.isEmpty && ws != home && !home.hasPrefix(ws + "/") {
            // Workspace is outside (or a strict subdir of) home: deny the whole
            // home credential surface, then re-allow only the workspace and the
            // CLIs' own config/state dirs.
            lines.append(deny(home))
            lines.append(allow(ws))
            for dir in ["\(home)/.claude", "\(home)/.codex", "\(home)/.cache", "\(home)/.config/anini"] {
                lines.append(allow(dir))
            }
        } else {
            // Workspace is the home directory itself (the default), so we cannot
            // blanket-deny home without breaking legitimate work. Fall back to
            // denying the known credential subtrees explicitly.
            for dir in SecurityLayer.shared.sensitivePaths.map({ Path.expand($0.path) }) {
                lines.append(deny(dir))
            }
        }

        // Explicit protected paths denied last as defense-in-depth — they win
        // even if a re-allow subtree above ever overlapped them.
        for expanded in protectedPaths {
            lines.append(deny(expanded))
        }

        return lines.joined(separator: "\n")
    }

    /// Writes the profile to a temp file and returns its URL. Caller is
    /// responsible for cleanup in the process termination handler.
    func writeSandboxProfile(prefix: String) -> URL? {
        guard let contents = sandboxProfile() else { return nil }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("anini-\(prefix)-\(UUID().uuidString).sb")
        guard let data = contents.data(using: .utf8),
              (try? data.write(to: url, options: .atomic)) != nil
        else { return nil }
        return url
    }
}
