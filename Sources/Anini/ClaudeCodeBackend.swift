import Foundation

class ClaudeCodeBackend: Backend {
    let displayName = "Claude Code"
    private(set) var sessionId: String?
    private let processLock = NSLock()
    private var currentProcess: Process?

    private func swapCurrent(_ next: Process?) -> Process? {
        processLock.lock()
        defer { processLock.unlock() }
        let prior = currentProcess
        currentProcess = next
        return prior
    }

    private func clearCurrent(if proc: Process) {
        processLock.lock()
        defer { processLock.unlock() }
        if currentProcess === proc { currentProcess = nil }
    }

    private func snapshotCurrent() -> Process? {
        processLock.lock()
        defer { processLock.unlock() }
        return currentProcess
    }

    var isAvailable: Bool { ClaudeCodeBackend.checkAvailable() }

    static func checkAvailable() -> Bool {
        resolveExecutable() != nil
    }

    private static func resolveExecutable() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "\(home)/.local/bin/claude",
            "\(home)/node_modules/.bin/claude",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["claude"]
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
        try await run(input: text, imagePath: imagePath, onProgress: onProgress)
    }

    func compact(onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        try await run(input: "/compact", onProgress: onProgress)
    }

    func interrupt() {
        snapshotCurrent()?.interrupt()
    }

    func clearSession() {
        sessionId = nil
    }

    private func run(input: String, imagePath: String? = nil, onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        guard let execPath = ClaudeCodeBackend.resolveExecutable() else {
            throw BackendError.notFound("claude")
        }

        let policy = PermissionPolicy.current()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.currentDirectoryURL = URL(fileURLWithPath: Path.expand(WorkspaceConfig.shared.workspacePath))

            var args = ["-p", input, "--output-format", "stream-json", "--verbose",
                        "--model", WorkspaceConfig.shared.claudeModel]

            var systemPromptAdditions: [String] = []
            if WorkspaceConfig.shared.allowedCapabilities.contains("imessage") {
                systemPromptAdditions.append(
                    """
                    When the user asks you to send an iMessage or text message to someone:
                    1. First look up their phone number via the Contacts app:
                         osascript -e 'tell application "Contacts" to value of first phone of (first person whose name contains "NAME")'
                    2. Then send the message via Messages using the PHONE NUMBER (not the name) as the buddy:
                         osascript -e 'tell application "Messages" to send "MESSAGE" to buddy "PHONE_NUMBER" of (1st service whose service type = iMessage)'
                    3. Messages.app requires a phone number or email — it cannot send to a contact name directly.
                    4. If the contact has multiple phone numbers, ask the user which one to use before sending.
                    5. If Contacts lookup returns nothing, ask the user to provide the phone number directly.
                    """
                )
            } else {
                systemPromptAdditions.append(
                    "Sending iMessages is disabled. If the user asks you to send a text or iMessage, politely tell them this feature is off and they can enable it in Settings → Capabilities → Send iMessages."
                )
            }
            if WorkspaceConfig.shared.allowedCapabilities.contains("facetime") {
                systemPromptAdditions.append(
                    """
                    When the user asks you to start, place, or make a FaceTime call to someone:
                    1. Look up their phone number or Apple ID email via the Contacts app:
                         osascript -e 'tell application "Contacts" to value of first phone of (first person whose name contains "NAME")'
                       A FaceTime call can use either a phone number or an email/Apple ID.
                    2. Start a FaceTime VIDEO call by opening the facetime: URL. This single command starts the call directly — it needs no special permission:
                         open "facetime://+15551234567"
                       For a FaceTime AUDIO (voice-only) call, use the facetime-audio: scheme instead:
                         open "facetime-audio://+15551234567"
                    3. Do NOT use System Events or UI scripting to start the call — the open command above already starts it. UI scripting from this environment is blocked and will only produce spurious "enable Accessibility" errors, so never go down that path for placing a call.
                    4. Default to a VIDEO call unless the user explicitly asks for an audio or voice call.
                    5. If the Contacts lookup returns nothing, ask the user for the phone number or Apple ID directly.

                    When the user asks you to end, hang up, or leave the current FaceTime call:
                    1. End the active call by quitting FaceTime (quitting drops the current call). Try the graceful quit first:
                         osascript -e 'tell application "FaceTime" to quit'
                    2. If that command is blocked or the call is still up after ~1 second, force-quit FaceTime, which always ends the call and needs no special permission:
                         killall FaceTime
                    3. Do NOT try to click FaceTime's on-screen "End" button via System Events / UI scripting — that requires Accessibility access this environment cannot use, and it is why ending calls failed before. Quitting the app is the reliable method.
                    """
                )
            } else {
                systemPromptAdditions.append(
                    "FaceTime calling is disabled. If the user asks you to start or end a FaceTime call, politely tell them this feature is off and they can enable it in Settings → Capabilities → FaceTime calls."
                )
            }
            if let img = imagePath {
                systemPromptAdditions.append(
                    "A screenshot of the user's screen was just captured and saved to \(img). Use the Read tool to read this file immediately — you CAN see the screen this way. Do not say you lack screen access."
                )
            }
            args += ["--append-system-prompt", systemPromptAdditions.joined(separator: "\n\n")]
            if let sid = sessionId {
                args += ["--resume", sid]
            }
            let allCapsEnabled = Capability.all.allSatisfy {
                WorkspaceConfig.shared.allowedCapabilities.contains($0.id)
            }
            if WorkspaceConfig.shared.dangerouslySkipPermissions || allCapsEnabled {
                args.append("--dangerously-skip-permissions")
            } else {
                let enabledTools = Capability.all
                    .filter { WorkspaceConfig.shared.allowedCapabilities.contains($0.id) }
                    .flatMap { $0.claudeTools }
                if !enabledTools.isEmpty {
                    args += ["--allowedTools", enabledTools.joined(separator: ",")]
                }
            }
            // Honor sensitive-path toggles from onboarding. Deny rules live in a
            // temp settings JSON (passed via --settings) rather than --disallowedTools
            // argv flags, so the protected paths never appear in `ps` output.
            var settingsURL: URL? = nil
            if let url = policy.writeClaudeSettings(prefix: "claude") {
                settingsURL = url
                args += ["--settings", url.path]
            }

            // OS-level path protection: if any sensitive paths are still protected,
            // wrap claude in sandbox-exec so the kernel itself blocks reads/writes
            // to those paths — even when Claude Code shells out via Bash. CLI deny
            // rules are best-effort (a model can rename/symlink/encode paths to
            // dodge string matching); the kernel sandbox is the actual guarantee.
            var sandboxProfileURL: URL? = nil
            if let url = policy.writeSandboxProfile(prefix: "claude") {
                sandboxProfileURL = url
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
                process.arguments = ["-f", url.path, execPath] + args
                SecurityLayer.shared.log("ClaudeCode sandboxed via \(url.lastPathComponent)")
            } else {
                process.executableURL = URL(fileURLWithPath: execPath)
                process.arguments = args
            }

            // Augment PATH so node-installed MCP servers resolve
            var env = ProcessInfo.processInfo.environment
            let extraPaths = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/Library/Frameworks/Python.framework/Versions/3.14/bin"
            env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
            if let key = Keychain.load(for: "anthropic_api_key"), !key.isEmpty {
                env["ANTHROPIC_API_KEY"] = key
            }
            process.environment = env

            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let streamState = ClaudeStreamState()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                guard let chunk = String(data: handle.availableData, encoding: .utf8) else { return }
                for progress in streamState.append(chunk) {
                    onProgress(progress)
                }
            }

            let profileURLForCleanup = sandboxProfileURL
            let settingsURLForCleanup = settingsURL
            process.terminationHandler = { [weak self] proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                if let url = profileURLForCleanup {
                    try? FileManager.default.removeItem(at: url)
                }
                if let url = settingsURLForCleanup {
                    try? FileManager.default.removeItem(at: url)
                }
                self?.clearCurrent(if: proc)
                let result = streamState.result
                if let sid = result.sessionId {
                    DispatchQueue.main.async { self?.sessionId = sid }
                }
                SecurityLayer.shared.log("ClaudeCode session=\(result.sessionId ?? "?") exit=\(proc.terminationStatus)")

                if proc.terminationStatus == 0 || !result.text.isEmpty {
                    continuation.resume(returning: result.text)
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
            let prior = swapCurrent(process)
            prior?.interrupt()
            do {
                try process.run()
            } catch {
                clearCurrent(if: process)
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class ClaudeStreamState: @unchecked Sendable {
    private let lock = NSLock()
    private var lineBuffer = ""
    private var accumulatedText = ""
    private var capturedSession: String?

    var result: (text: String, sessionId: String?) {
        lock.lock()
        defer { lock.unlock() }
        return (accumulatedText, capturedSession)
    }

    func append(_ chunk: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        var progressUpdates: [String] = []
        lineBuffer += chunk

        while let nlIdx = lineBuffer.firstIndex(of: "\n") {
            let line = String(lineBuffer[..<nlIdx])
            lineBuffer = String(lineBuffer[lineBuffer.index(after: nlIdx)...])
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let sid = json["session_id"] as? String {
                capturedSession = sid
            }

            guard json["type"] as? String == "assistant",
                  let message = json["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]]
            else { continue }

            for block in content {
                switch block["type"] as? String {
                case "text":
                    if let text = block["text"] as? String {
                        accumulatedText = text
                        progressUpdates.append(text)
                    }
                case "tool_use":
                    let name = block["name"] as? String ?? "tool"
                    let prefix = accumulatedText.isEmpty ? "" : accumulatedText + "\n\n"
                    progressUpdates.append(prefix + "⚙️ Running \(name)…")
                default:
                    break
                }
            }
        }

        return progressUpdates
    }
}
