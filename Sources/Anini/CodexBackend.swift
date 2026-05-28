import Foundation

class CodexBackend: Backend {
    let displayName = "Codex"
    private(set) var sessionId: String? = nil
    private var currentProcess: Process?

    var isAvailable: Bool { CodexBackend.checkAvailable() }

    static func checkAvailable() -> Bool {
        resolveExecutable() != nil
    }

    private static func resolveExecutable() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "\(home)/.local/bin/codex",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["codex"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        try? which.run()
        which.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return out.isEmpty ? nil : out
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
            env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/Library/Frameworks/Python.framework/Versions/3.14/bin:\(NSHomeDirectory())/.npm-global/bin:" + (env["PATH"] ?? "")
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
            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                if let url = profileURLForCleanup {
                    try? FileManager.default.removeItem(at: url)
                }
                SecurityLayer.shared.log("Codex exit=\(proc.terminationStatus)")
                let text = output.snapshot().trimmingCharacters(in: .whitespacesAndNewlines)

                if proc.terminationStatus == 0 || !text.isEmpty {
                    continuation.resume(returning: text)
                } else {
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(throwing: BackendError.processError(errMsg))
                }
            }

            do {
                try process.run()
                currentProcess = process
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func compact(onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        "Codex doesn't support /compact. Clear the session to start fresh."
    }

    func interrupt() { currentProcess?.interrupt() }
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
