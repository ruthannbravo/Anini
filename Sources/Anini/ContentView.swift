import SwiftUI
import UniformTypeIdentifiers

struct AniniAvatar: View {
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.82, green: 0.68, blue: 0.99),
                        Color(red: 0.50, green: 0.32, blue: 0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("✦")
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.50, green: 0.32, blue: 0.82).opacity(0.35), radius: size * 0.18, y: size * 0.08)
    }
}

struct ContentView: View {
    @ObservedObject var panelState: PanelState
    @StateObject private var vm = ChatViewModel()
    @ObservedObject private var config = WorkspaceConfig.shared
    @ObservedObject private var backendMgr = BackendManager.shared
    @State private var inputText = ""
    @State private var heartBeating = false
    @State private var isDroppingFile = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if panelState.isMinimized {
                minimizedView
            } else if !config.onboardingComplete {
                OnboardingView(panelState: panelState)
            } else {
                mainView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.35)
            )
            .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    isDroppingFile
                        ? config.accentColor.opacity(0.8)
                        : Color.white.opacity(0.35),
                    lineWidth: isDroppingFile ? 2 : 0.8
                )
                .allowsHitTesting(false)
        )
        .onAppear { focused = true }
        .onChange(of: panelState.pendingMessage) { _, msg in
            guard let msg else { return }
            inputText = msg
            panelState.pendingMessage = nil
            focused = true
        }
        .onChange(of: panelState.pendingAutoSend) { _, text in
            guard let text, !text.isEmpty, !vm.isLoading else { return }
            panelState.pendingAutoSend = nil
            panelState.showingSettings = false
            if let taskId = panelState.pendingTaskId {
                let id = taskId
                panelState.pendingTaskId = nil
                panelState.pendingTaskTitle = nil
                vm.scheduleTaskFollowUp { panelState.onTaskCompleted?(id) }
            }
            Task { await vm.send(text) }
        }
        .onChange(of: vm.pendingAttachment) { _, path in
            guard let path else { return }
            let ref = "File: \(path)"
            inputText = inputText.isEmpty ? ref : inputText + "\n\n" + ref
            vm.pendingAttachment = nil
            focused = true
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDroppingFile) { providers in
            providers.first?.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    Task { @MainActor in vm.attachFile(url) }
                }
            }
            return true
        }
        .alert("Let Anini see your screen", isPresented: $vm.needsScreenPermission) {
            Button("Open Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
            Button("Quit & Relaunch") {
                let path = Bundle.main.bundleURL.path
                let task = Process()
                task.launchPath = "/bin/sh"
                task.arguments = ["-c", "sleep 0.75 && open '\(path)'"]
                try? task.run()
                NSApp.terminate(nil)
            }
            Button("Not now", role: .cancel) { }
        } message: {
            if vm.screenCaptureError != nil {
                Text("""
                macOS is blocking the screenshot. To fix it:

                1. Tap "Open Settings"
                2. Turn the Anini switch OFF, then back ON
                3. Come back here and tap "Quit & Relaunch"
                4. Click the camera button again 📸
                """)
            } else {
                Text("""
                To share what you're looking at, Anini needs Screen Recording permission.

                1. Tap "Open Settings"
                2. Turn ON the switch next to Anini
                3. Tap "Quit & Relaunch"
                4. Click the camera button again 📸
                """)
            }
        }
    }

    // MARK: - Minimized

    private var minimizedView: some View {
        Button(action: { panelState.isMinimized = false }) {
            Group {
                if config.iconEmoji.isEmpty {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(config.accentColor)
                } else {
                    Text(config.iconEmoji).font(.system(size: 22))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main

    private var mainView: some View {
        ZStack(alignment: .topTrailing) {
            if panelState.showingSettings {
                settingsPanelView
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    contactHeader
                    messageList
                    Spacer(minLength: 0)
                    inputBar
                }
            }

            HStack(spacing: 6) {
                if !panelState.showingSettings {
                    Text(backendMgr.currentBackend.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
                if panelState.showingSettings {
                    backButton
                } else {
                    menuButton
                }
                minimizeButton
                fullScreenButton
                closeButton
            }
            .padding(16)
        }
        .overlay(alignment: .topLeading) {
            if !panelState.showingSettings {
                HStack(spacing: 6) {
                    appearanceButton
                    compactButton
                }
                .padding(16)
            }
        }
    }

    private var settingsPanelView: some View {
        SettingsView()
            .padding(.top, 44)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.88))
    }

    private var backButton: some View {
        iconButton(systemName: "chevron.left") {
            panelState.showingSettings = false
        }
    }

    // MARK: - Header

    private var contactHeader: some View {
        VStack(spacing: 5) {
            AniniAvatar(size: 54)
            Text("Anini")
                .font(.system(size: 13, weight: .semibold))
            Text("always here")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 52)
        .padding(.bottom, 14)
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    greetingBubbles
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg).id(msg.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .onChange(of: vm.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: vm.messages.last?.content) { _, _ in scrollToBottom(proxy) }
        }
    }

    private var greetingBubbles: some View {
        VStack(alignment: .leading, spacing: 6) {
            greetingBubble("hello, Ann ✦")
            greetingBubble("how can I help you today?")
        }
    }

    private func greetingBubble(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 40)
        }
    }

    // MARK: - Input

    private var screenshotsEnabled: Bool {
        config.allowedCapabilities.contains("screenshots")
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if screenshotsEnabled, let path = vm.pendingScreenshot, let nsImage = NSImage(contentsOfFile: path) {
                HStack(spacing: 8) {
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 120, maxHeight: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(config.accentColor.opacity(0.5), lineWidth: 1)
                            )
                        Button(action: { vm.pendingScreenshot = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white, Color.black.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 5, y: -5)
                        .help("Discard screenshot")
                    }
                    Text("Screenshot ready — send a message to share it")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
            inputRow
        }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            if screenshotsEnabled {
                Button(action: { vm.captureScreen() }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "camera")
                            .font(.system(size: 14))
                            .foregroundStyle(vm.pendingScreenshot != nil ? config.accentColor : .secondary)
                        if vm.pendingScreenshot != nil {
                            Circle()
                                .fill(config.accentColor)
                                .frame(width: 7, height: 7)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(vm.pendingScreenshot != nil ? "Screenshot ready — type a message and send to share it" : "Take a screenshot to share with Anini")
            }

            TextField("Ask anything…", text: $inputText, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($focused)
                .onSubmit { submitIfNotEmpty() }

            Button(action: vm.isLoading ? vm.stopGeneration : submitIfNotEmpty) {
                if vm.isLoading {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.primary)
                } else {
                    Group {
                        if config.iconEmoji.isEmpty {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(
                                    heartBeating ? Color.white
                                    : inputText.isEmpty ? Color.secondary
                                    : config.accentColor
                                )
                        } else {
                            Text(config.iconEmoji).font(.system(size: 26))
                        }
                    }
                    .scaleEffect(heartBeating ? 1.3 : 1.0)
                    .animation(
                        heartBeating
                            ? .easeInOut(duration: 0.35).repeatForever(autoreverses: true)
                            : .easeInOut(duration: 0.2),
                        value: heartBeating
                    )
                    .onHover { heartBeating = $0 }
                }
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty && !vm.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Toolbar buttons

    private var appearanceButton: some View {
        iconButton(systemName: panelState.isDarkMode ? "sun.max.fill" : "moon.fill") {
            panelState.isDarkMode.toggle()
        }
    }

    private var menuButton: some View {
        Menu {
            Button(action: openSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            Divider()
            Button(action: { Task { await vm.compact() } }) {
                Label("/compact — free up context", systemImage: "arrow.trianglehead.counterclockwise")
            }
            .disabled(!backendMgr.sessionActive || vm.isLoading)
            Divider()
            Button(role: .destructive, action: vm.clear) {
                Label("Clear conversation", systemImage: "trash")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 24, height: 24)
                Image(systemName: "ellipsis")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 24, height: 24)
    }

    private func openSettings() {
        panelState.showingSettings = true
    }

    private var compactButton: some View {
        iconButton(systemName: "arrow.trianglehead.counterclockwise") {
            Task { await vm.compact() }
        }
        .help("/compact — summarize context to free space")
        .opacity(backendMgr.sessionActive && !vm.isLoading ? 1 : 0.3)
        .disabled(!backendMgr.sessionActive || vm.isLoading)
    }

    private var minimizeButton: some View {
        iconButton(systemName: panelState.isMinimized ? "chevron.down" : "minus") {
            panelState.isMinimized.toggle()
        }
    }

    private var fullScreenButton: some View {
        iconButton(systemName: panelState.isFullScreen
                   ? "arrow.down.right.and.arrow.up.left"
                   : "arrow.up.left.and.arrow.down.right") {
            panelState.isFullScreen.toggle()
        }
    }

    private var closeButton: some View {
        iconButton(systemName: "xmark") { NSApp.keyWindow?.orderOut(nil) }
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.primary.opacity(0.12)).frame(width: 24, height: 24)
                Image(systemName: systemName).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func submitIfNotEmpty() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !vm.isLoading else { return }
        inputText = ""
        Task { await vm.send(text) }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = vm.messages.last {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }
}
