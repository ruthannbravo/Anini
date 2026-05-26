import SwiftUI

@main
struct AniniApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup { EmptyView() }
            .defaultSize(width: 0, height: 0)
            .commandsRemoved()

    }
}
