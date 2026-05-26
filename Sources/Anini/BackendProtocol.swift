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

protocol Backend: AnyObject {
    var displayName: String { get }
    var sessionId: String? { get }
    var isAvailable: Bool { get }

    func send(_ text: String, imagePath: String?, onProgress: @escaping @Sendable (String) -> Void) async throws -> String
    func compact(onProgress: @escaping @Sendable (String) -> Void) async throws -> String
    func interrupt()
    func clearSession()
}
