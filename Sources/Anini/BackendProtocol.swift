import Foundation

enum BackendError: LocalizedError {
    case notFound(String)
    case processError(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let bin):
            return "\(bin) not found. Make sure it's installed and in your PATH."
        case .processError(let msg):
            return msg.isEmpty ? "Process exited with an error." : msg
        }
    }
}

/// Outcome of resolving a backend's CLI executable. Carries a human-readable
/// reason when unavailable so Settings can explain *why* — e.g. "installed in
/// npm-global, which Anini ignores for security" — instead of a bare
/// "Not installed" that leaves the user stuck.
enum ExecutableResolution {
    case found(path: String)        // absolute path, safe to launch
    case unavailable(reason: String)

    var isAvailable: Bool { if case .found = self { return true } else { return false } }
    var path: String? { if case .found(let p) = self { return p } else { return nil } }
    var reason: String? { if case .unavailable(let r) = self { return r } else { return nil } }
}

protocol Backend: AnyObject {
    var displayName: String { get }
    var sessionId: String? { get }
    var isAvailable: Bool { get }

    func send(_ text: String, imagePath: String?, onProgress: @escaping @Sendable (String) -> Void) async throws -> String
    func compact(onProgress: @escaping @Sendable (String) -> Void) async throws -> String
    func interrupt()
    func clearSession()
}
