import Foundation

class ClaudeCodeBackend: Backend {
    let displayName = "Claude Code"
    private(set) var sessionId: String?
    private var currentProcess: Process?

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
        currentProcess?.interrupt()
    }

    func clearSession() {
        sessionId = nil
    }

    private func run(input: String, imagePath: String? = nil, onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        guard let execPath = ClaudeCodeBackend.resolveExecutable() else {
            throw BackendError.notFound("claude")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: execPath)
            process.currentDirectoryURL = URL(fileURLWithPath: WorkspaceConfig.shared.workspacePath)

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
            process.arguments = args

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

            process.terminationHandler = { [weak self] proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
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

            do {
                try process.run()
                currentProcess = process
            } catch {
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
