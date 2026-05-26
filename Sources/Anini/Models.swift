import Foundation

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var isStreaming: Bool = false
    var imagePath: String? = nil

    enum Role {
        case user, assistant
    }
}
