import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?
    var statusItem: NSStatusItem?
    var notchWidget: NotchWidget?
    let hotkeyManager = HotkeyManager()
    let panelState = PanelState()
    let nowPlayingService = NowPlayingService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPanel()
        setupNotch()
        hotkeyManager.onToggle = { [weak self] in self?.togglePanel() }
        hotkeyManager.register()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Claude")
            button.action = #selector(togglePanel)
            button.target = self
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide (⌥Space)", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    func setupPanel() {
        panel = FloatingPanel(contentView: AnyView(ContentView(panelState: panelState)), panelState: panelState)
    }

    func setupNotch() {
        notchWidget = NotchWidget(
            nowPlaying: nowPlayingService,
            onOpenChat: { [weak self] text, task in
                guard let self else { return }
                if text.isEmpty {
                    self.panelState.pendingMessage = nil
                } else {
                    self.panelState.showingSettings = false
                    self.panelState.pendingAutoSend = text
                    if let task {
                        self.panelState.pendingTaskId    = task.id
                        self.panelState.pendingTaskTitle = task.title
                    }
                }
                self.togglePanel()
            },
            onOpenSettings: { [weak self] in
                self?.showSettings()
            }
        )
        panelState.onTaskCompleted = { [weak self] id in
            self?.notchWidget?.notchState.completeTask(id)
        }
        // Defer until the run loop settles so NSScreen.screens is fully populated.
        DispatchQueue.main.async {
            self.notchWidget?.positionAndShow()
        }

        // Reposition whenever the user enters/exits full screen (Space change)
        // or a display is connected/disconnected.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notchWidget?.positionAndShow()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notchWidget?.positionAndShow()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notchWidget?.enforcePosition()
        }
    }

    @objc func togglePanel() {
        guard let panel = panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            if let screen = NSScreen.main {
                let x = screen.visibleFrame.midX - panel.frame.width / 2
                let y = screen.visibleFrame.midY - panel.frame.height / 2 + 60
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func openSettings() {
        showSettings()
    }

    func showSettings() {
        panelState.showingSettings = true
        if panel?.isVisible == false {
            togglePanel()
        } else {
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
