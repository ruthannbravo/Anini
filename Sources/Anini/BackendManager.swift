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

    var availableBackends: [(WorkspaceConfig.BackendKind, Bool)] {
        [
            (.claudeCode, claudeCodeBackend.isAvailable),
            (.codex, codexBackend.isAvailable),
        ]
    }
}
