import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var config = WorkspaceConfig.shared
    @ObservedObject private var googleCal = GoogleCalendarManager.shared
    @State private var workspaceInput = WorkspaceConfig.shared.workspacePath
    @State private var showResetConfirmation = false
    @State private var anthropicKey = ""
    @State private var openaiKey = ""
    @State private var showAnthropicKey = false
    @State private var showOpenaiKey = false
    @State private var emojiInput = ""
    @State private var googleClientId = ""
    @State private var selectedSection: Section = .backend
    @FocusState private var emojiFieldFocused: Bool

    enum Section: String, CaseIterable, Identifiable {
        case backend     = "Backend"
        case workspace   = "Workspace"
        case appearance  = "Appearance"
        case calendar    = "Calendar"
        case capabilities = "Capabilities"
        case permissions = "Permissions"
        case notch       = "Notch"
        case advanced    = "Advanced"
        case usage       = "Usage"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .backend:      return "cpu"
            case .workspace:    return "folder"
            case .appearance:   return "paintbrush"
            case .calendar:     return "calendar"
            case .capabilities: return "checklist"
            case .permissions:  return "lock.shield"
            case .notch:        return "rectangle.topthird.inset.filled"
            case .advanced:     return "wrench.and.screwdriver"
            case .usage:        return "questionmark.circle"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Form {
                Group {
                    switch selectedSection {
                    case .backend:      backendSection
                    case .workspace:    workspaceSection
                    case .appearance:   appearanceSection
                    case .calendar:     calendarSection
                    case .capabilities: capabilitiesSection
                    case .permissions:  permissionsSection
                    case .notch:        notchSection
                    case .advanced:     advancedSection
                    case .usage:        usageSection
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            anthropicKey   = Keychain.load(for: "anthropic_api_key") ?? ""
            openaiKey      = Keychain.load(for: "openai_api_key") ?? ""
            emojiInput     = config.iconEmoji
            googleClientId = Keychain.load(for: "google_client_id") ?? ""
            googleCal.checkConnectionStatus()
        }
        .alert("Reset everything?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) { resetEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears your workspace, backend, security settings, and permission choices, then restarts the setup wizard. This cannot be undone.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Section.allCases) { section in
                sidebarItem(section)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(width: 172, alignment: .topLeading)
        .background(Color.primary.opacity(0.04))
    }

    private func sidebarItem(_ section: Section) -> some View {
        let isSelected = selectedSection == section
        return Button(action: { selectedSection = section }) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(section.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? config.accentColor : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? config.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sections

    @ViewBuilder private var backendSection: some View {
        SwiftUI.Section {
            Picker("Backend", selection: $config.activeBackend) {
                ForEach(WorkspaceConfig.BackendKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .onChange(of: config.activeBackend) { _, kind in
                BackendManager.shared.switchBackend(to: kind)
            }

            ForEach(BackendManager.shared.availableBackends, id: \.0) { kind, available in
                if kind == config.activeBackend {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(available ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(available ? "Found in PATH" : "Not installed")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if !available {
                        installStepsView(for: kind)
                    }
                }
            }

            if config.activeBackend == .claudeCode {
                modelPicker(
                    label: "Model",
                    models: WorkspaceConfig.claudeModels,
                    selection: $config.claudeModel
                )
                apiKeyRow(
                    label: "Anthropic API Key",
                    placeholder: "sk-ant-...",
                    text: $anthropicKey,
                    show: $showAnthropicKey,
                    keychainKey: "anthropic_api_key"
                )
            } else {
                modelPicker(
                    label: "Model",
                    models: WorkspaceConfig.codexModels,
                    selection: $config.codexModel
                )
                apiKeyRow(
                    label: "OpenAI API Key",
                    placeholder: "sk-...",
                    text: $openaiKey,
                    show: $showOpenaiKey,
                    keychainKey: "openai_api_key"
                )
            }
        } header: {
            Text("AI Backend")
        }
    }

    @ViewBuilder private var workspaceSection: some View {
        SwiftUI.Section {
            HStack {
                TextField("~/Projects", text: $workspaceInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    if panel.runModal() == .OK {
                        workspaceInput = panel.url?.path ?? workspaceInput
                        config.workspacePath = workspaceInput
                        workspaceInput = config.workspacePath
                    }
                }
            }
            if workspaceInput != config.workspacePath {
                Button("Apply") {
                    config.workspacePath = workspaceInput
                    // Reflect the expanded value back to the field so the user
                    // sees the absolute path that was actually persisted.
                    workspaceInput = config.workspacePath
                }
            }
        } header: {
            Text("Workspace Directory")
        } footer: {
            Text("The backend runs with this as its working directory.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var appearanceSection: some View {
        SwiftUI.Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Accent color")
                    .font(.system(size: 13))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 6) {
                    ForEach(WorkspaceConfig.accentPresets.indices, id: \.self) { i in
                        let preset = WorkspaceConfig.accentPresets[i]
                        let color = Color(red: preset[0], green: preset[1], blue: preset[2])
                        let selected = config.accentColorRGB == preset
                        Button(action: { config.accentColorRGB = preset }) {
                            Circle()
                                .fill(color)
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(.white.opacity(selected ? 0.9 : 0), lineWidth: 2))
                                .overlay(Circle().strokeBorder(color.opacity(selected ? 0 : 0.35), lineWidth: 1))
                                .shadow(color: color.opacity(selected ? 0.55 : 0), radius: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Background opacity")
                        .font(.system(size: 13))
                    Spacer()
                    Text("\(Int(config.panelOpacity * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $config.panelOpacity, in: 0.3...1.0)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Icon")
                        .font(.system(size: 13))
                    Spacer()
                    Text("Current:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    ZStack {
                        Circle()
                            .fill(config.accentColor.opacity(0.18))
                            .frame(width: 32, height: 32)
                        if config.iconEmoji.isEmpty {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(config.accentColor)
                        } else {
                            Text(config.iconEmoji).font(.system(size: 18))
                        }
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 6) {
                    ForEach(WorkspaceConfig.iconOptions, id: \.self) { option in
                        Button(action: {
                            config.iconEmoji = option
                            emojiInput = option
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(config.iconEmoji == option
                                          ? config.accentColor.opacity(0.25)
                                          : Color.primary.opacity(0.05))
                                    .frame(width: 30, height: 30)
                                if option.isEmpty {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(config.accentColor)
                                } else {
                                    Text(option).font(.system(size: 15))
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(
                                        config.iconEmoji == option ? config.accentColor : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("", text: $emojiInput)
                    .focused($emojiFieldFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .onChange(of: emojiInput) { _, val in
                        guard let first = val.first else { return }
                        config.iconEmoji = String(first)
                        emojiInput = String(first)
                    }
                Button("Choose more emoji…") {
                    emojiFieldFocused = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        NSApp.orderFrontCharacterPalette(nil)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(config.accentColor)
            }
        } header: {
            Text("Appearance")
        }
    }

    @ViewBuilder private var calendarSection: some View {
        SwiftUI.Section {
            if googleCal.isConnected {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected")
                            .font(.system(size: 13, weight: .medium))
                        if let email = googleCal.connectedEmail {
                            Text(email)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Disconnect") { googleCal.disconnect() }
                        .foregroundStyle(.red)
                        .font(.system(size: 12))
                }
            } else {
                TextField("Client ID", text: $googleClientId, prompt: Text("paste your Client ID here"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit {
                        if !googleClientId.isEmpty { googleCal.connect(clientID: googleClientId) }
                    }
                    .onChange(of: googleClientId) { _, val in
                        if val.isEmpty { Keychain.delete(for: "google_client_id") }
                        else { Keychain.save(val, for: "google_client_id") }
                    }
                HStack {
                    Spacer()
                    Button(action: { googleCal.connect(clientID: googleClientId) }) {
                        if googleCal.isAuthenticating {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label("Connect with Google", systemImage: "calendar")
                        }
                    }
                    .disabled(googleCal.isAuthenticating || googleClientId.isEmpty)
                }
                if let err = googleCal.errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Google Calendar")
        } footer: {
            if !googleCal.isConnected {
                VStack(alignment: .leading, spacing: 3) {
                    Text("How to get your Client ID:")
                        .fontWeight(.medium)
                    Text("1. Open console.cloud.google.com in your browser")
                    Text("2. Enable the Google Calendar API")
                    Text("3. Go to APIs & Services → Credentials → Create credentials → OAuth client ID → choose Desktop app")
                    Text("4. Copy the Client ID shown, paste it in the field above, then tap Connect — a sign-in window will open")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var capabilitiesSection: some View {
        SwiftUI.Section {
            ForEach(Capability.all) { cap in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cap.displayName).font(.system(size: 13))
                        Text(cap.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { config.allowedCapabilities.contains(cap.id) },
                        set: { enabled in
                            if enabled {
                                config.allowedCapabilities.insert(cap.id)
                            } else {
                                config.allowedCapabilities.remove(cap.id)
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(config.dangerouslySkipPermissions)
                }
            }
        } header: {
            Text("Capabilities")
        } footer: {
            Text(config.dangerouslySkipPermissions
                 ? "Overridden — all capabilities run without restriction."
                 : "Only enabled capabilities are pre-approved. Anini won't use disabled ones.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var permissionsSection: some View {
        SwiftUI.Section {
            Toggle("dangerously-skip-permissions", isOn: $config.dangerouslySkipPermissions)
            if config.dangerouslySkipPermissions {
                Label("All tools run without confirmation prompts. Full shell access.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Permission Mode")
        }
    }

    @ViewBuilder private var notchSection: some View {
        SwiftUI.Section {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Language")
                        .font(.system(size: 13))
                    Text("Choose a language to learn in your notch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Language", selection: $config.learningLanguage) {
                    ForEach(WorkspaceConfig.LearningLanguage.allCases, id: \.rawValue) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if config.learningLanguage != .none {
                Toggle(isOn: $config.showLangWord) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Word of the week")
                        Text("Weekly rotating vocabulary with pronunciation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $config.showLangVerb) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verb of the week")
                        Text("Essential verbs with present tense conjugation and daily exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My gender")
                            .font(.system(size: 13))
                        Text("Personalizes practice phrases like \"Je suis contente\" / \"Sono contento\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        ForEach(WorkspaceConfig.UserGender.allCases, id: \.rawValue) { g in
                            Button(action: { config.userGender = g }) {
                                Text(g.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(config.userGender == g
                                                ? config.accentColor.opacity(0.25)
                                                : Color.primary.opacity(0.07))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(
                                        config.userGender == g ? config.accentColor : Color.clear,
                                        lineWidth: 1
                                    ))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } header: {
            Text("Notch")
        }
    }

    @ViewBuilder private var advancedSection: some View {
        SwiftUI.Section {
            Toggle("Prevent sleep while AI is working", isOn: $config.preventSleepDuringTasks)
            if config.preventSleepDuringTasks {
                Text("Anini will run caffeinate -i during any AI response to keep your Mac awake.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Audit log")
                Spacer()
                Button("Show in Finder") {
                    NSWorkspace.shared.open(
                        FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent(".anini")
                    )
                }
                .font(.system(size: 12))
            }
            Button("Run onboarding again") {
                config.onboardingComplete = false
            }
            .foregroundStyle(.orange)

            Button("Reset everything…") {
                showResetConfirmation = true
            }
            .foregroundStyle(.red)
        } header: {
            Text("Advanced")
        } footer: {
            Text("Reset everything clears all settings and restarts the setup wizard from scratch.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var usageSection: some View {
        SwiftUI.Section {
            Text("Hotkey: ⌥Space (Option + Space)")
            Text("Click the ✦ menu bar icon to open")
            Text("Drop files onto the window to attach them")
            Text("Use the ↺ button to /compact when context gets long")
        } header: {
            Text("Usage")
        }
    }

    // MARK: - Helpers

    private func resetEverything() {
        let keys = [
            "workspace_path", "active_backend", "dangerous_skip_permissions",
            "onboarding_complete", "unprotected_paths", "allowed_capabilities",
            "ui_accent_color", "ui_panel_opacity", "ui_icon_emoji"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        config.workspacePath = FileManager.default.homeDirectoryForCurrentUser.path
        config.activeBackend = .claudeCode
        config.dangerouslySkipPermissions = false
        config.unprotectedPaths = []
        config.allowedCapabilities = Set(Capability.all.map { $0.id })
        Keychain.delete(for: "anthropic_api_key")
        Keychain.delete(for: "openai_api_key")
        anthropicKey = ""
        openaiKey = ""
        config.accentColorRGB = [0.72, 0.57, 0.93]
        config.panelOpacity   = 0.78
        config.iconEmoji      = ""

        BackendManager.shared.currentBackend.clearSession()
        BackendManager.shared.sessionActive = false

        config.onboardingComplete = false
    }

    @ViewBuilder
    private func apiKeyRow(label: String, placeholder: String, text: Binding<String>, show: Binding<Bool>, keychainKey: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(minWidth: 120, alignment: .leading)
            Group {
                if show.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: .monospaced))
            .onChange(of: text.wrappedValue) { _, val in
                if val.isEmpty { Keychain.delete(for: keychainKey) }
                else { Keychain.save(val, for: keychainKey) }
            }

            Button(action: { show.wrappedValue.toggle() }) {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)

            Image(systemName: text.wrappedValue.isEmpty ? "key" : "checkmark.circle.fill")
                .foregroundStyle(text.wrappedValue.isEmpty ? Color.secondary : Color.green)
                .font(.system(size: 12))
        }
    }

    private func modelPicker(label: String, models: [WorkspaceConfig.Model], selection: Binding<String>) -> some View {
        Picker(label, selection: selection) {
            ForEach(models) { model in
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.name).font(.system(size: 13))
                    Text(model.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .tag(model.id)
            }
        }
    }

    @ViewBuilder
    private func installStepsView(for kind: WorkspaceConfig.BackendKind) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("How to set up \(kind.displayName):")
                .font(.system(size: 12, weight: .medium))

            Text("1. Make sure Node.js is installed — nodejs.org")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("2. Open Terminal and run:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(installCommand(kind))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(installCommand(kind), forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy command")
            }

            Group {
                switch kind {
                case .claudeCode:
                    Text("3. Get your API key at console.anthropic.com → API Keys — paste it in the field above")
                case .codex:
                    Text("3. Get your API key at platform.openai.com → API Keys — paste it in the field above")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            Text("4. Quit and relaunch Anini — the status will turn green")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func installCommand(_ kind: WorkspaceConfig.BackendKind) -> String {
        switch kind {
        case .claudeCode: return "npm install -g @anthropic-ai/claude-code"
        case .codex:      return "npm install -g @openai/codex"
        }
    }
}
