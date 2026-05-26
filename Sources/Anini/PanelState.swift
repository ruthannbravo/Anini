import Foundation
import Combine

final class PanelState: ObservableObject {
    @Published var isMinimized:    Bool = false
    @Published var isFullScreen:   Bool = false
    @Published var isDarkMode:     Bool = false
    @Published var pendingMessage:  String? = nil
    @Published var pendingAutoSend: String? = nil
    @Published var showingSettings: Bool   = false
    @Published var pendingTaskId:    UUID?   = nil
    @Published var pendingTaskTitle: String? = nil
    var onTaskCompleted: ((UUID) -> Void)? = nil
    let expandedWidth:  CGFloat = 460
    let expandedHeight: CGFloat = 460
    let collapsedSize:  CGFloat = 56
}
