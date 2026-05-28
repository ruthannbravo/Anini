import SwiftUI
import AppKit

struct OnboardingView: View {
    var panelState: PanelState

    @ObservedObject private var config = WorkspaceConfig.shared

    @State private var step = 0
    @State private var workspaceInput = WorkspaceConfig.shared.workspacePath
    @State private var selectedBackend = WorkspaceConfig.shared.activeBackend
    @State private var expandedPathId: String? = nil
    @State private var unprotectedPaths: Set<String> = WorkspaceConfig.shared.unprotectedPaths

    private let claudeAvailable: Bool = ClaudeCodeBackend.checkAvailable()
    private let codexAvailable: Bool = CodexBackend.checkAvailable()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Step content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: backendStep
                case 2: workspaceStep
                case 3: securityStep
                case 4: permissionsStep
                default: doneStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)

            // Minimize button — always visible during onboarding
            Button(action: { panelState.isMinimized = true }) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 24, height: 24)
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.88))
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(spacing: 4) {
                (Text("Welcome to ") + Text("Anini").foregroundColor(config.accentColor))
                    .font(.system(size: 28, weight: .bold))
                Text("your mini assistant")
                    .font(.system(size: 16, weight: .regular).italic())
                    .foregroundStyle(.secondary)
            }
            Text("Let's take 90 seconds to set up your local AI workspace.\nEverything runs on this machine — no cloud, no relay.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            navBar(nextLabel: "Get started") { step += 1 }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 1: Backend

    private var backendStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepLabel("1 of 4")
            Text("Choose a backend")
                .font(.title3.weight(.semibold))
            Text("Your glass window talks to one of these locally-installed AI agents. Both run entirely on your machine.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                backendRow(
                    kind: .claudeCode,
                    available: claudeAvailable,
                    description: "Anthropic's coding agent. Supports MCP, /compact, file access, and computer control."
                )
                backendRow(
                    kind: .codex,
                    available: codexAvailable,
                    description: "OpenAI's coding agent. Full-auto shell and file access."
                )
            }

            if !claudeAvailable && !codexAvailable {
                Label("Neither backend found. Install Claude Code:\nnpm install -g @anthropic-ai/claude-code", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }

            Spacer()
            navBar(nextLabel: "Continue") { step += 1 }
        }
    }

    private func backendRow(kind: WorkspaceConfig.BackendKind, available: Bool, description: String) -> some View {
        let accent = Color(red: 0.72, green: 0.57, blue: 0.93)
        let selected = selectedBackend == kind
        return Button(action: { selectedBackend = kind }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? accent : .secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(kind.displayName).font(.system(size: 13, weight: .medium))
                        if !available {
                            Text("not installed")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .background(selected ? accent.opacity(0.1) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Workspace

    private var workspaceStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepLabel("2 of 4")
            Text("Set your workspace")
                .font(.title3.weight(.semibold))
            Text("The AI agent runs with this directory as its working directory. It can read and write files here freely.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("~/Projects", text: $workspaceInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.directoryURL = URL(fileURLWithPath: Path.expand(workspaceInput))
                    if panel.runModal() == .OK {
                        workspaceInput = panel.url?.path ?? workspaceInput
                    }
                }
            }

            Text("Outside this directory the agent will operate more cautiously, depending on your permission mode.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()
            navBar(nextLabel: "Continue") { step += 1 }
        }
    }

    // MARK: - Step 3: Security

    private var securityStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel("3 of 4")
            Text("What the AI won't touch")
                .font(.title3.weight(.semibold))
            Text("Each item below is protected by default. Toggle one off to allow the AI to access it — but read the risk first.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(SecurityLayer.shared.sensitivePaths) { entry in
                        SensitivePathCard(
                            entry: entry,
                            isExpanded: expandedPathId == entry.id,
                            isProtected: !unprotectedPaths.contains(entry.id),
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    expandedPathId = expandedPathId == entry.id ? nil : entry.id
                                }
                            },
                            onToggleProtect: { protect in
                                if protect { unprotectedPaths.remove(entry.id) }
                                else { unprotectedPaths.insert(entry.id) }
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            if !unprotectedPaths.isEmpty {
                Label(
                    "\(unprotectedPaths.count) path\(unprotectedPaths.count == 1 ? "" : "s") left unprotected.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            }

            Text("All commands are logged to ~/.anini/audit.log.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            navBar(nextLabel: "I understand, continue") {
                config.unprotectedPaths = unprotectedPaths
                step += 1
            }
        }
    }

    // MARK: - Step 4: Permission Mode

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepLabel("4 of 4")
            Text("Permission mode")
                .font(.title3.weight(.semibold))

            VStack(spacing: 8) {
                permissionOption(
                    title: "Safe (recommended)",
                    subtitle: "Claude Code will ask before running shell commands or accessing files outside your workspace.",
                    selected: !config.dangerouslySkipPermissions,
                    action: { config.dangerouslySkipPermissions = false }
                )
                permissionOption(
                    title: "⚠️  dangerously-skip-permissions",
                    subtitle: "All tools run without prompts. Full shell access, no confirmation. That's on you.",
                    selected: config.dangerouslySkipPermissions,
                    action: { config.dangerouslySkipPermissions = true }
                )
            }

            if config.dangerouslySkipPermissions {
                Text("Full-auto mode enabled. The agent can run any shell command, read any file, and modify anything it can reach. You can change this in Settings anytime.")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
            navBar(nextLabel: "Continue") { step += 1 }
        }
    }

    private func permissionOption(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        let accent = Color(red: 0.72, green: 0.57, blue: 0.93)
        return Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? accent : .secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .background(selected ? accent.opacity(0.1) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Done

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("You're all set.")
                .font(.system(size: 28, weight: .bold).italic())
            Text("Press ⌥Space anytime to open this window.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
            navBar(nextLabel: "Open Anini") { finishOnboarding() }
        }
    }

    // MARK: - Shared nav bar

    private func navBar(nextLabel: String, nextAction: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button(action: { step -= 1 }) {
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.08))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Button(action: nextAction) {
                Text(nextLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.72, green: 0.57, blue: 0.93))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private func stepLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private func finishOnboarding() {
        config.workspacePath = Path.expand(workspaceInput)
        config.activeBackend = selectedBackend
        BackendManager.shared.switchBackend(to: selectedBackend)
        panelState.showingSettings = false
        config.onboardingComplete = true
    }
}

// MARK: - Sensitive Path Card

struct SensitivePathCard: View {
    let entry: SensitivePath
    let isExpanded: Bool
    let isProtected: Bool
    let onToggleExpand: () -> Void
    let onToggleProtect: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: onToggleExpand) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(entry.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isProtected ? .primary : .secondary)
                            riskBadge
                        }
                        Text(entry.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isProtected },
                        set: { onToggleProtect($0) }
                    ))
                    .toggleStyle(.switch)
                    .scaleEffect(0.75)
                    .frame(width: 44)
                    .tint(Color(red: 0.72, green: 0.57, blue: 0.93))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().padding(.horizontal, 12)
                    VStack(alignment: .leading, spacing: 6) {
                        detailSection(icon: "folder.fill", label: "What's here",
                                      text: entry.whatIsHere, color: .secondary)
                        detailSection(icon: "exclamationmark.shield.fill", label: "If the AI can read this",
                                      text: entry.ifExposed, color: entry.riskLevel.color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Unprotected inline warning
            if !isProtected {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                    Text("Unprotected — the AI can access this path.")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isProtected ? Color.primary.opacity(0.04) : Color.orange.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    isProtected ? Color.primary.opacity(0.08) : Color.orange.opacity(0.4),
                    lineWidth: 0.7
                )
        )
    }

    private var riskBadge: some View {
        Text(entry.riskLevel.label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(entry.riskLevel.color)
            .padding(.horizontal, 5).padding(.vertical, 1.5)
            .background(entry.riskLevel.color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func detailSection(icon: String, label: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
                .padding(.top, 2).frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).lineSpacing(1.5)
            }
        }
    }
}
