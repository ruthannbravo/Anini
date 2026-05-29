import Foundation

class CodexBackend: Backend {
    let displayName = "Codex"
    private(set) var sessionId: String? = nil
    private let processOwner = ProcessOwner()

    var isAvailable: Bool { CodexBackend.checkAvailable() }

    static func checkAvailable() -> Bool {
        availability().isAvailable
    }

    /// Full diagnostic resolution — Settings uses the `.unavailable` reason to
    /// explain *why* the backend can't be used instead of a bare "Not installed".
    static func availability() -> ExecutableResolution {
        ExecutableTrust.resolve(name: "codex",
                                candidates: trustedCandidates,
                                ignoredHints: ignoredLocations)
    }

    private static func resolveExecutable() -> String? {
        availability().path
    }

    // Resolve only from trusted absolute locations. We deliberately do NOT fall
    // back to `which`/PATH (an attacker-influenced PATH could point at a planted
    // binary that would run with the user's privileges and the OPENAI_API_KEY in
    // its env), and we drop the npm-writable ~/.npm-global candidate. Each
    // candidate's real (symlink-resolved) target is verified to be owned by root
    // or the user and not group/other-writable.
    private static var trustedCandidates: [String] {
        let home = NSHomeDirectory()
        return [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
        ]
    }

    /// Where `codex` commonly lives but Anini refuses to run it from. Surfaced
    /// in the unavailable diagnostic so a working CLI that's only in npm-global
    /// produces a clear explanation rather than a silent "not installed".
    private static var ignoredLocations: [String] {
        ["\(NSHomeDirectory())/.npm-global/bin/codex"]
    }

    func send(_ text: String, imagePath: String? = nil, onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        guard let execPath = CodexBackend.resolveExecutable() else {
            throw BackendError.notFound("codex")
        }

        let policy = PermissionPolicy.current()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.currentDirectoryURL = URL(fileURLWithPath: Path.expand(WorkspaceConfig.shared.workspacePath))
            var codexArgs = [
                "exec",
                "--skip-git-repo-check",
                "--color", "never",
            ]
            // Bug 1: previously this flag was hardcoded, so Safe-mode users got
            // full-auto anyway. Now honor the policy: bypass only when the user
            // explicitly opted into full-auto. In Safe mode use codex's
            // `workspace-write` sandbox, which allows reads everywhere but
            // restricts writes (and arbitrary shell side effects) to the cwd.
            // codex exec is non-interactive, so we can't fall back to live
            // approvals — workspace-write is the safest non-bypass option.
            if policy.allowFullAuto {
                codexArgs.append("--dangerously-bypass-approvals-and-sandbox")
            } else {
                codexArgs += ["--sandbox", "workspace-write"]
            }
            let model = WorkspaceConfig.shared.codexModel
            if model != "default" { codexArgs += ["-m", model] }
            if let img = imagePath { codexArgs += ["-i", img] }
            codexArgs.append(text)

            // OS-level path protection: if any sensitive paths are still protected,
            // wrap codex in sandbox-exec so the kernel itself blocks reads/writes
            // to those paths — even when Codex shells out via Bash.
            var sandboxProfileURL: URL? = nil
            if let url = policy.writeSandboxProfile(prefix: "codex") {
                sandboxProfileURL = url
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
                process.arguments = ["-f", url.path, execPath] + codexArgs
                SecurityLayer.shared.log("Codex sandboxed via \(url.lastPathComponent)")
            } else {
                process.executableURL = URL(fileURLWithPath: execPath)
                process.arguments = codexArgs
            }

            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(NSHomeDirectory())/.npm-global/bin:" + (env["PATH"] ?? "")
            if let key = Keychain.load(for: "openai_api_key"), !key.isEmpty {
                env["OPENAI_API_KEY"] = key
            }
            process.environment = env

            process.standardInput  = FileHandle.nullDevice
            process.standardOutput = stdoutPipe
            process.standardError  = stderrPipe

            let output = CodexOutputBuffer()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                guard let chunk = String(data: handle.availableData, encoding: .utf8) else { return }
                onProgress(output.append(chunk))
            }

            let profileURLForCleanup = sandboxProfileURL
            process.terminationHandler = { [weak self] proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                if let url = profileURLForCleanup {
                    try? FileManager.default.removeItem(at: url)
                }
                self?.processOwner.clear(if: proc)
                SecurityLayer.shared.log("Codex exit=\(proc.terminationStatus)")
                let text = output.snapshot().trimmingCharacters(in: .whitespacesAndNewlines)

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: text)
                } else if !text.isEmpty {
                    // Partial output but a non-zero exit: surface the failure as
                    // an appended warning instead of silently reporting success.
                    continuation.resume(returning: text
                        + "\n\n⚠️ Codex exited with an error (code \(proc.terminationStatus)); this answer may be incomplete.")
                } else {
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(throwing: BackendError.processError(errMsg))
                }
            }

            // Publish ownership before launching so interrupt() can never race
            // a partial assignment, and so any prior in-flight process gets
            // stopped instead of orphaned.
            let prior = processOwner.swap(process)
            if let prior { ProcessGroup.interrupt(prior) }
            // Put the child in its own process group so interrupt() can signal
            // the whole tree (sandbox-exec + codex + its Bash subprocesses).
            ProcessGroup.makeLeader(process)
            do {
                try process.run()
            } catch {
                processOwner.clear(if: process)
                continuation.resume(throwing: error)
            }
        }
    }

    func compact(onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        "Codex doesn't support /compact. Clear the session to start fresh."
    }

    func interrupt() {
        guard let proc = processOwner.snapshot() else { return }
        // Signal the child's whole process group (sandbox-exec + codex + any
        // Bash subprocesses) so nothing is orphaned with the API key still live.
        ProcessGroup.interrupt(proc)
    }
    func clearSession() {}
}

private final class CodexOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    func append(_ chunk: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        text += chunk
        return text
    }

    func snapshot() -> String {
        lock.lock()
        defer { lock.unlock() }
        return text
    }
}
