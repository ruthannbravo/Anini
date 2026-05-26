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
        try? p.run()
        caffeinateProcess = p
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
        Task {
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
        let path = NSTemporaryDirectory() + "anini_screen_\(Int(Date().timeIntervalSince1970)).png"
        let cfURL = URL(fileURLWithPath: path) as CFURL
        guard let dest = CGImageDestinationCreateWithURL(cfURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return }
        pendingScreenshot = path
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
