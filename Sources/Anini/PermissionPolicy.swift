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
            protectedPaths: deduped
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

    /// Builds an SBPL profile that denies reads & writes on every protected
    /// path. Returns nil when nothing is protected so we don't pay for
    /// sandbox-exec when not needed.
    func sandboxProfile() -> String? {
        guard !protectedPaths.isEmpty else { return nil }
        var lines = ["(version 1)", "(allow default)"]
        for expanded in protectedPaths {
            let escaped = Path.sbplEscaped(expanded)
            lines.append("(deny file-read* file-write* (subpath \"\(escaped)\"))")
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
