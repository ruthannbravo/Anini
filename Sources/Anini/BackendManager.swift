import Foundation

@MainActor
class BackendManager: ObservableObject {
    static let shared = BackendManager()

    @Published private(set) var currentBackend: Backend
    @Published var sessionActive = false
    var forceNextCaffeinate = false

    private let claudeCodeBackend: ClaudeCodeBackend
    private let codexBackend: CodexBackend

    private init() {
        let cc = ClaudeCodeBackend()
        let cx = CodexBackend()
        claudeCodeBackend = cc
        codexBackend = cx

        switch WorkspaceConfig.shared.activeBackend {
        case .claudeCode: currentBackend = cc
        case .codex:      currentBackend = cx
        }
    }

    func switchBackend(to kind: WorkspaceConfig.BackendKind) {
        currentBackend.interrupt()
        currentBackend.clearSession()
        WorkspaceConfig.shared.activeBackend = kind
        switch kind {
        case .claudeCode: currentBackend = claudeCodeBackend
        case .codex:      currentBackend = codexBackend
        }
        sessionActive = false
    }

    /// Per-backend resolution (availability + reason when unavailable). Settings
    /// renders the reason so the user knows *why* a backend can't be used.
    var availableBackends: [(WorkspaceConfig.BackendKind, ExecutableResolution)] {
        [
            (.claudeCode, ClaudeCodeBackend.availability()),
            (.codex, CodexBackend.availability()),
        ]
    }
}
