import Foundation
import SwiftUI
import CoreGraphics
import ImageIO
import ScreenCaptureKit

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var pendingAttachment: String? = nil
    @Published var pendingScreenshot: String? = nil
    @Published var needsScreenPermission = false
    @Published var screenCaptureError: String? = nil

    private var awaitingTaskConfirmation = false
    private var pendingTaskFollowUp = false
    private var taskCheckCallback: (() -> Void)? = nil
    private var caffeinateProcess: Process?

    func scheduleTaskFollowUp(onComplete: @escaping () -> Void) {
        taskCheckCallback = onComplete
        pendingTaskFollowUp = true
    }

    private func startCaffeinate() {
        let forced = BackendManager.shared.forceNextCaffeinate
        BackendManager.shared.forceNextCaffeinate = false
        guard forced || WorkspaceConfig.shared.preventSleepDuringTasks else { return }
        guard caffeinateProcess == nil else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = ["-i"]
        do {
            try p.run()
            caffeinateProcess = p
        } catch {
            // Non-fatal: keep-awake just won't be active for this task.
            NSLog("Anini: caffeinate failed to launch: \(error.localizedDescription)")
        }
    }

    private func stopCaffeinate() {
        caffeinateProcess?.terminate()
        caffeinateProcess = nil
    }

    func send(_ text: String) async {
        // If we just asked "did you complete the task?", intercept a clear "yes"
        if awaitingTaskConfirmation {
            awaitingTaskConfirmation = false
            let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let isYes = ["yes", "yeah", "yep", "yup", "done", "y", "completed", "✓"].contains(lower)
            messages.append(Message(role: .user, content: text))
            if isYes {
                taskCheckCallback?()
                taskCheckCallback = nil
                messages.append(Message(role: .assistant, content: "✓ Marked as done on your to-do list!"))
                return
            }
            // Not a clear yes — fall through so Anini responds naturally
        }

        let screenshotPath = pendingScreenshot
        pendingScreenshot = nil

        messages.append(Message(role: .user, content: text, imagePath: screenshotPath))
        let idx = appendStreaming()
        isLoading = true
        startCaffeinate()

        let backend = BackendManager.shared.currentBackend
        do {
            let result = try await backend.send(text, imagePath: screenshotPath) { [weak self] progress in
                guard !progress.isEmpty else { return }
                Task { @MainActor [weak self] in
                    self?.messages[idx].content = progress
                }
            }
            finalize(idx: idx, content: result.isEmpty ? "(no response)" : result)
            BackendManager.shared.sessionActive = true
        } catch {
            finalize(idx: idx, content: "⚠️ \(error.localizedDescription)")
        }
        // The turn is done; delete the screenshot — it may contain secrets.
        if let shot = screenshotPath {
            try? FileManager.default.removeItem(atPath: shot)
        }
        isLoading = false
        stopCaffeinate()

        // After responding about a task, ask if it's now complete
        if pendingTaskFollowUp {
            pendingTaskFollowUp = false
            try? await Task.sleep(nanoseconds: 500_000_000)
            messages.append(Message(role: .assistant, content: "Were you able to complete the task? Reply **yes** to mark it as done ✓"))
            awaitingTaskConfirmation = true
        }
    }

    func compact() async {
        guard !isLoading else { return }
        isLoading = true
        startCaffeinate()
        let idx = appendStreaming(initial: "Compacting context…")
        let backend = BackendManager.shared.currentBackend
        do {
            let result = try await backend.compact { [weak self] progress in
                guard !progress.isEmpty else { return }
                Task { @MainActor [weak self] in
                    self?.messages[idx].content = progress
                }
            }
            finalize(idx: idx, content: result.isEmpty ? "Context compacted." : result)
        } catch {
            finalize(idx: idx, content: "⚠️ \(error.localizedDescription)")
        }
        isLoading = false
        stopCaffeinate()
    }

    func stopGeneration() {
        BackendManager.shared.currentBackend.interrupt()
        if let last = messages.indices.last, messages[last].isStreaming {
            messages[last].isStreaming = false
        }
        isLoading = false
        stopCaffeinate()
    }

    func clear() {
        messages = []
        awaitingTaskConfirmation = false
        pendingTaskFollowUp = false
        taskCheckCallback = nil
        BackendManager.shared.currentBackend.clearSession()
        BackendManager.shared.sessionActive = false
    }

    func attachFile(_ url: URL) {
        pendingAttachment = url.path
    }

    func captureScreen() {
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                guard let display = content.displays.first else {
                    screenCaptureError = "No display detected."
                    needsScreenPermission = true
                    return
                }
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let streamConfig = SCStreamConfiguration()
                streamConfig.width  = display.width
                streamConfig.height = display.height
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: streamConfig)
                saveAndSet(cgImage: image)
            } catch {
                screenCaptureError = error.localizedDescription
                CGRequestScreenCaptureAccess()
                needsScreenPermission = true
            }
        }
    }

    private func saveAndSet(cgImage: CGImage) {
        // Screenshots can contain passwords, private messages, etc. Write them
        // to an owner-only (0700) app-private dir with an unpredictable name
        // rather than the world-readable shared temp dir, and 0600 the file.
        let url = ChatViewModel.screenshotsDir().appendingPathComponent("\(UUID().uuidString).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        pendingScreenshot = url.path
    }

    /// 0700 app-private directory for screenshots.
    nonisolated static func screenshotsDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("anini_screens", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        return dir
    }

    /// Delete screenshots older than one hour. Called once at launch alongside
    /// the temp-file orphan sweep.
    nonisolated static func cleanupScreenshots(minAgeSeconds: TimeInterval = 3600) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: screenshotsDir(),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-minAgeSeconds)
        for url in items {
            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date.distantPast
            if mtime < cutoff { try? fm.removeItem(at: url) }
        }
    }

    // MARK: - Private

    private func appendStreaming(initial: String = "") -> Int {
        messages.append(Message(role: .assistant, content: initial, isStreaming: true))
        return messages.count - 1
    }

    private func finalize(idx: Int, content: String) {
        messages[idx].content = content
        messages[idx].isStreaming = false
    }
}
