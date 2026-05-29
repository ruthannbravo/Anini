import Foundation
import SwiftUI

struct Capability: Identifiable {
    let id: String
    let displayName: String
    let detail: String
    let claudeTools: [String]

    static let all: [Capability] = [
        Capability(
            id: "shell",
            displayName: "Shell & apps",
            detail: "Run commands, open URLs in browser, launch apps",
            claudeTools: ["Bash"]
        ),
        Capability(
            id: "read_files",
            displayName: "Read files",
            detail: "Browse and read files on disk",
            claudeTools: ["Read", "LS", "Glob", "Grep"]
        ),
        Capability(
            id: "write_files",
            displayName: "Write & edit files",
            detail: "Create, modify, and delete files",
            claudeTools: ["Write", "Edit", "MultiEdit", "NotebookEdit"]
        ),
        Capability(
            id: "web_fetch",
            displayName: "Fetch web pages",
            detail: "Download and read content from URLs",
            claudeTools: ["WebFetch"]
        ),
        Capability(
            id: "web_search",
            displayName: "Search the web",
            detail: "Search the internet for information",
            claudeTools: ["WebSearch"]
        ),
        Capability(
            id: "screenshots",
            displayName: "Screenshots",
            detail: "Show the camera button to capture your screen and share it",
            claudeTools: []
        ),
        Capability(
            id: "imessage",
            displayName: "Send iMessages",
            detail: "Let Anini send text messages to your contacts via Messages.app",
            claudeTools: []
        ),
        Capability(
            id: "facetime",
            displayName: "FaceTime calls",
            detail: "Let Anini start FaceTime calls to your contacts and end the current call",
            claudeTools: []
        ),
    ]
}

class WorkspaceConfig: ObservableObject {
    static let shared = WorkspaceConfig()

    // Backing storage so the setter can normalize before the @Published
    // value (and willSet/objectWillChange) ever sees a literal "~/...".
    // Without this, observers briefly see the unexpanded value and pass it
    // to URL(fileURLWithPath:), which does not expand tildes.
    private var _workspacePath: String = ""
    var workspacePath: String {
        get { _workspacePath }
        set {
            let expanded = Path.expand(newValue)
            guard expanded != _workspacePath else { return }
            objectWillChange.send()
            _workspacePath = expanded
            UserDefaults.standard.set(expanded, forKey: "workspace_path")
        }
    }

    /// Test-friendly variant of the workspacePath setter: expands and persists
    /// to an arbitrary UserDefaults suite. Exposed so tests don't pollute the
    /// real defaults database.
    static let workspacePathDefaultsKey = "workspace_path"
    static func writeWorkspacePath(_ raw: String, to defaults: UserDefaults) -> String {
        let expanded = Path.expand(raw)
        defaults.set(expanded, forKey: workspacePathDefaultsKey)
        return expanded
    }
    @Published var activeBackend: BackendKind {
        didSet { UserDefaults.standard.set(activeBackend.rawValue, forKey: "active_backend") }
    }
    @Published var dangerouslySkipPermissions: Bool {
        didSet { UserDefaults.standard.set(dangerouslySkipPermissions, forKey: "dangerous_skip_permissions") }
    }
    @Published var onboardingComplete: Bool {
        didSet { UserDefaults.standard.set(onboardingComplete, forKey: "onboarding_complete") }
    }

    // Path IDs the user has explicitly allowed the AI to access (opted out of protection).
    // Default: empty — all sensitive paths are protected.
    @Published var unprotectedPaths: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(unprotectedPaths), forKey: "unprotected_paths")
        }
    }

    // Capability IDs that are pre-approved (maps to --allowedTools for claude).
    // Default: all capabilities enabled.
    @Published var allowedCapabilities: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(allowedCapabilities), forKey: "allowed_capabilities")
        }
    }

    @Published var claudeModel: String {
        didSet { UserDefaults.standard.set(claudeModel, forKey: "claude_model") }
    }
    @Published var codexModel: String {
        didSet { UserDefaults.standard.set(codexModel, forKey: "codex_model") }
    }

    @Published var accentColorRGB: [Double] {
        didSet {
            UserDefaults.standard.set(accentColorRGB, forKey: "ui_accent_color")
            accentColor = Color(red: accentColorRGB[0], green: accentColorRGB[1], blue: accentColorRGB[2])
        }
    }
    @Published var accentColor: Color
    @Published var panelOpacity: Double {
        didSet { UserDefaults.standard.set(panelOpacity, forKey: "ui_panel_opacity") }
    }
    @Published var iconEmoji: String {
        didSet { UserDefaults.standard.set(iconEmoji, forKey: "ui_icon_emoji") }
    }
    @Published var preventSleepDuringTasks: Bool {
        didSet { UserDefaults.standard.set(preventSleepDuringTasks, forKey: "prevent_sleep_during_tasks") }
    }
    @Published var showNowPlaying: Bool {
        didSet { UserDefaults.standard.set(showNowPlaying, forKey: "notch_show_now_playing") }
    }
    @Published var learningLanguage: LearningLanguage {
        didSet { UserDefaults.standard.set(learningLanguage.rawValue, forKey: "notch_learning_language") }
    }
    @Published var showLangWord: Bool {
        didSet { UserDefaults.standard.set(showLangWord, forKey: "notch_show_lang_word") }
    }
    @Published var showLangVerb: Bool {
        didSet { UserDefaults.standard.set(showLangVerb, forKey: "notch_show_lang_verb") }
    }
    @Published var userGender: UserGender {
        didSet { UserDefaults.standard.set(userGender.rawValue, forKey: "user_gender") }
    }

    enum LearningLanguage: String, CaseIterable {
        case none    = "none"
        case french  = "french"
        case italian = "italian"

        var displayName: String {
            switch self {
            case .none:    return "None"
            case .french:  return "French"
            case .italian: return "Italian"
            }
        }
    }

    enum UserGender: String, CaseIterable {
        case unspecified = "unspecified"
        case masculine   = "masculine"
        case feminine    = "feminine"

        var label: String {
            switch self {
            case .unspecified: return "—"
            case .masculine:   return "masc."
            case .feminine:    return "fem."
            }
        }
    }

    static let accentPresets: [[Double]] = [
        [0.72, 0.57, 0.93], // lavender (default)
        [0.58, 0.33, 0.93], // purple
        [0.38, 0.42, 0.97], // indigo
        [0.25, 0.57, 0.97], // blue
        [0.15, 0.75, 0.90], // cyan
        [0.20, 0.80, 0.65], // teal
        [0.25, 0.75, 0.30], // green
        [0.90, 0.75, 0.22], // yellow
        [0.97, 0.58, 0.22], // orange
        [0.95, 0.32, 0.32], // red
        [0.95, 0.42, 0.65], // pink
        [0.88, 0.25, 0.78], // magenta
        [0.97, 0.62, 0.50], // salmon
        [0.88, 0.75, 0.38], // gold
        [0.78, 0.78, 0.88], // silver
        [0.95, 0.95, 0.95], // white
    ]

    static let iconOptions: [String] = [
        "",
        "💜", "🤍", "❤️", "🧡", "💛", "💚", "💙",
        "🩷", "🩵", "🩶", "🖤",
        "✨", "⭐", "🌟", "💫", "✦",
        "🌸", "🌺", "🌻", "🦋", "🌙", "☁️", "🌈",
        "💎", "🎀", "🔮", "🪄", "🫧", "🎵",
    ]

    struct Model: Identifiable, Equatable {
        let id: String
        let name: String
        let detail: String
    }

    static let claudeModels: [Model] = [
        Model(id: "claude-sonnet-4-6",  name: "Sonnet 4.6",  detail: "Default — fast and smart"),
        Model(id: "claude-opus-4-7",    name: "Opus 4.7",    detail: "Most capable, slower"),
        Model(id: "claude-haiku-4-5",   name: "Haiku 4.5",   detail: "Fastest, lightweight"),
    ]

    static let codexModels: [Model] = [
        Model(id: "default", name: "Default",  detail: "Let Codex choose — works with ChatGPT accounts"),
        Model(id: "gpt-5.5", name: "GPT-5.5",  detail: "ChatGPT account — latest"),
        Model(id: "o4-mini", name: "o4-mini",  detail: "OpenAI API key required — fast reasoning"),
        Model(id: "o3",      name: "o3",       detail: "OpenAI API key required — most capable"),
    ]

    enum BackendKind: String, CaseIterable {
        case claudeCode = "claude"
        case codex = "codex"

        var displayName: String {
            switch self {
            case .claudeCode: return "Claude Code"
            case .codex: return "Codex"
            }
        }
    }

    private init() {
        _workspacePath = Path.expand(UserDefaults.standard.string(forKey: "workspace_path")
            ?? FileManager.default.homeDirectoryForCurrentUser.path)
        activeBackend = BackendKind(rawValue: UserDefaults.standard.string(forKey: "active_backend") ?? "")
            ?? .claudeCode
        dangerouslySkipPermissions = UserDefaults.standard.bool(forKey: "dangerous_skip_permissions")
        onboardingComplete = UserDefaults.standard.bool(forKey: "onboarding_complete")
        let savedArr = UserDefaults.standard.stringArray(forKey: "unprotected_paths") ?? []
        unprotectedPaths = Set(savedArr)

        if let saved = UserDefaults.standard.stringArray(forKey: "allowed_capabilities") {
            allowedCapabilities = Set(saved)
        } else {
            allowedCapabilities = Set(Capability.all.map { $0.id })
        }

        let savedClaude = UserDefaults.standard.string(forKey: "claude_model") ?? ""
        claudeModel = WorkspaceConfig.claudeModels.map(\.id).contains(savedClaude)
            ? savedClaude : WorkspaceConfig.claudeModels[0].id
        let savedCodex = UserDefaults.standard.string(forKey: "codex_model") ?? ""
        codexModel = WorkspaceConfig.codexModels.map(\.id).contains(savedCodex)
            ? savedCodex : WorkspaceConfig.codexModels[0].id
        let defaultRGB: [Double] = [0.72, 0.57, 0.93]
        let storedRGB = UserDefaults.standard.array(forKey: "ui_accent_color") as? [Double]
        // Guard against corrupted/legacy defaults: a malformed array would
        // otherwise trap on subscript and crash before any UI is shown.
        let rgb = (storedRGB?.count == 3) ? storedRGB! : defaultRGB
        accentColorRGB = rgb
        accentColor = Color(red: rgb[0], green: rgb[1], blue: rgb[2])
        panelOpacity = UserDefaults.standard.object(forKey: "ui_panel_opacity") as? Double ?? 0.78
        iconEmoji = UserDefaults.standard.string(forKey: "ui_icon_emoji") ?? ""
        preventSleepDuringTasks = UserDefaults.standard.bool(forKey: "prevent_sleep_during_tasks")
        showNowPlaying = UserDefaults.standard.object(forKey: "notch_show_now_playing") as? Bool ?? true
        learningLanguage = LearningLanguage(rawValue: UserDefaults.standard.string(forKey: "notch_learning_language") ?? "") ?? .none
        showLangWord = UserDefaults.standard.object(forKey: "notch_show_lang_word") as? Bool ?? true
        showLangVerb = UserDefaults.standard.object(forKey: "notch_show_lang_verb") as? Bool ?? true
        userGender = UserGender(rawValue: UserDefaults.standard.string(forKey: "user_gender") ?? "") ?? .unspecified
    }
}
