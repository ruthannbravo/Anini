import Foundation

class ClaudeCodeBackend: Backend {
    let displayName = "Claude Code"
    private(set) var sessionId: String?
    private let processOwner = ProcessOwner()

    var isAvailable: Bool { ClaudeCodeBackend.checkAvailable() }

    static func checkAvailable() -> Bool {
        availability().isAvailable
    }

    /// Full diagnostic resolution — Settings uses the `.unavailable` reason to
    /// explain *why* the backend can't be used instead of a bare "Not installed".
    static func availability() -> ExecutableResolution {
        ExecutableTrust.resolve(name: "claude",
                                candidates: trustedCandidates,
                                ignoredHints: ignoredLocations)
    }

    private static func resolveExecutable() -> String? {
        availability().path
    }

    // Resolve only from trusted absolute locations. We deliberately do NOT fall
    // back to `which`/PATH (an attacker-influenced PATH could point at a planted
    // binary that would run with the user's privileges and the ANTHROPIC_API_KEY
    // in its env), and we drop the npm-writable ~/.npm-global candidate. Each
    // candidate's real (symlink-resolved) target is verified to be owned by root
    // or the user and not group/other-writable.
    private static var trustedCandidates: [String] {
        let home = NSHomeDirectory()
        return [
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.local/bin/claude",
        ]
    }

    /// Where `claude` commonly lives but Anini refuses to run it from. Surfaced
    /// in the unavailable diagnostic so a working CLI that's only in npm-global
    /// produces a clear explanation rather than a silent "not installed".
    private static var ignoredLocations: [String] {
        ["\(NSHomeDirectory())/.npm-global/bin/claude"]
    }

    func send(_ text: String, imagePath: String? = nil, onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        try await run(input: text, imagePath: imagePath, onProgress: onProgress)
    }

    func compact(onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        try await run(input: "/compact", onProgress: onProgress)
    }

    func interrupt() {
        guard let proc = processOwner.snapshot() else { return }
        // The owned process is /usr/bin/sandbox-exec; the real claude (and any
        // Bash subprocesses it spawned) are in the same process group. Signal
        // the whole group so the grandchildren aren't orphaned with the API key
        // still live. Fall back to a plain interrupt if the pid is unavailable.
        ProcessGroup.interrupt(proc)
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
            // The no-questions-asked bypass must come ONLY from the explicit
            // toggle. It must never be inferred from "all capabilities enabled" —
            // capabilities default to all-on, so inferring bypass from them would
            // silently put a user who chose Safe mode into full-auto. When not
            // bypassing, narrow Claude to exactly the tools the enabled
            // capabilities grant (deduped, order preserved).
            if WorkspaceConfig.shared.dangerouslySkipPermissions {
                args.append("--dangerously-skip-permissions")
            } else {
                var seenTools = Set<String>()
                let enabledTools = Capability.all
                    .filter { WorkspaceConfig.shared.allowedCapabilities.contains($0.id) }
                    .flatMap { $0.claudeTools }
                    .filter { seenTools.insert($0).inserted }
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
            let extraPaths = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
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
                self?.processOwner.clear(if: proc)
                let result = streamState.result
                if let sid = result.sessionId {
                    DispatchQueue.main.async { self?.sessionId = sid }
                }
                SecurityLayer.shared.log("ClaudeCode session=\(result.sessionId ?? "?") exit=\(proc.terminationStatus)")

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: result.text)
                } else if !result.text.isEmpty {
                    // Partial output but a non-zero exit: surface the failure as
                    // an appended warning instead of silently reporting success.
                    continuation.resume(returning: result.text
                        + "\n\n⚠️ The assistant exited with an error (code \(proc.terminationStatus)); this answer may be incomplete.")
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
            // the whole tree (sandbox-exec + claude + its Bash subprocesses).
            ProcessGroup.makeLeader(process)
            do {
                try process.run()
            } catch {
                processOwner.clear(if: process)
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
