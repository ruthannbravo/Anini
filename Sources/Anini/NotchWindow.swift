import AppKit
import Combine
import SwiftUI

enum NotchTab { case chat, todo }

struct TodoTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var isDone: Bool
    var scheduledDate: Date? = nil
    var keepAwake: Bool = false

    init(title: String) {
        self.id    = UUID()
        self.title = title
        self.isDone = false
    }
}

final class NotchState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var activeTab: NotchTab = .chat
    @Published var tasks: [TodoTask] = {
        guard let data = UserDefaults.standard.data(forKey: "notch_tasks"),
              let decoded = try? JSONDecoder().decode([TodoTask].self, from: data)
        else { return [] }
        return decoded
    }()

    func saveTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: "notch_tasks")
        }
    }

    func completeTask(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isDone = true
        saveTasks()
    }
}

// Subclass that returns zero safe-area insets so SwiftUI fills the full
// window frame — including the notch region — with no transparent gap at the top.
private final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets { .init() }
}

class NotchWidget: NSPanel {
    private var cancellables = Set<AnyCancellable>()
    let notchState = NotchState()

    private let collapsedW: CGFloat = 110
    private var collapsedH: CGFloat = 37
    private let expandedHChat: CGFloat = 120
    private let expandedHTodo: CGFloat = 260
    private var isAnimating = false
    private var enforceTimer: Timer?

    init(nowPlaying: NowPlayingService, onOpenChat: @escaping (String, TodoTask?) -> Void, onOpenSettings: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 110, height: 37),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )

        // Stay above the menu bar (level 24) without private CGSSpace APIs.
        // screenSaver level (~1000) is the highest public level that reliably
        // renders above the menu bar compositor on modern macOS.
        self.level                       = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.isOpaque                    = false
        self.backgroundColor             = .clear
        self.hasShadow                   = true
        self.isFloatingPanel             = true
        self.isReleasedWhenClosed        = false
        self.collectionBehavior          = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isMovable                   = false
        self.isMovableByWindowBackground = false
        self.appearance                  = NSAppearance(named: .darkAqua)

        // Use NSHostingView directly — no custom NSView layer mixing.
        let rootView = NotchWidgetView(
            notchState: notchState,
            nowPlaying: nowPlaying,
            onOpenChat: onOpenChat,
            onOpenSettings: onOpenSettings
        )
        let hosting = NotchHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        self.contentView = hosting

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowMoved),
            name: NSWindow.didMoveNotification,
            object: self
        )

        notchState.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in self?.animateToState(expanded) }
            .store(in: &cancellables)

        notchState.$activeTab
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.notchState.isExpanded == true else { return }
                self?.animateToState(true)
            }
            .store(in: &cancellables)

        WorkspaceConfig.shared.$showNowPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.notchState.isExpanded == true else { return }
                self?.animateToState(true)
            }
            .store(in: &cancellables)

        WorkspaceConfig.shared.$learningLanguage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.notchState.isExpanded == true else { return }
                self?.animateToState(true)
            }
            .store(in: &cancellables)

        WorkspaceConfig.shared.$showLangWord
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.notchState.isExpanded == true else { return }
                self?.animateToState(true)
            }
            .store(in: &cancellables)

        WorkspaceConfig.shared.$showLangVerb
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.notchState.isExpanded == true else { return }
                self?.animateToState(true)
            }
            .store(in: &cancellables)

        // Enforce center position periodically. enforceCurrentPosition() is
        // a no-op when the frame is already correct, so CPU cost is minimal.
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            guard let self, !self.isAnimating else { return }
            self.enforceCurrentPosition()
        }
        RunLoop.main.add(t, forMode: .default)
        enforceTimer = t
    }

    deinit {
        enforceTimer?.invalidate()
    }

    private var expandedWidth: CGFloat {
        let cfg = WorkspaceConfig.shared
        let hasMusic = cfg.showNowPlaying
        let hasLang  = cfg.learningLanguage != .none && (cfg.showLangWord || cfg.showLangVerb)
        switch (hasMusic, hasLang) {
        case (true,  true):  return 560
        case (true,  false): return 480
        case (false, true):  return 360
        case (false, false): return 260
        }
    }

    private func notchHeight(for screen: NSScreen) -> CGFloat {
        let h = screen.safeAreaInsets.top
        return h > 0 ? ceil(h) : 37
    }

    func enforcePosition() {
        enforceCurrentPosition()
    }

    private func enforceCurrentPosition() {
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        guard let screen else { return }
        let expandedH = notchState.activeTab == .todo ? expandedHTodo : expandedHChat
        let w = notchState.isExpanded ? expandedWidth : collapsedW
        let h = notchState.isExpanded ? expandedH : collapsedH
        let x = screen.frame.midX - w / 2
        let y = screen.frame.maxY - h
        let correct = NSRect(x: x, y: y, width: w, height: h)
        guard frame != correct else { return }
        setFrame(correct, display: false)
    }

    func positionAndShow() {
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        guard let screen = screen else { return }
        collapsedH = notchHeight(for: screen)
        let x = screen.frame.midX - collapsedW / 2
        let y = screen.frame.maxY - collapsedH
        setFrame(NSRect(x: x, y: y, width: collapsedW, height: collapsedH), display: true)
        alphaValue = 1.0
        orderFrontRegardless()
    }

    @objc private func windowMoved() {
        guard !isAnimating else { return }
        enforceCurrentPosition()
    }

    private func animateToState(_ expanded: Bool) {
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        guard let screen = screen else { return }
        collapsedH = notchHeight(for: screen)
        let expandedW = expandedWidth
        let expandedH = notchState.activeTab == .todo ? expandedHTodo : expandedHChat
        let w = expanded ? expandedW : collapsedW
        let h = expanded ? expandedH : collapsedH
        let x = screen.frame.midX - w / 2
        let y = screen.frame.maxY - h
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration       = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
            animator().setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.enforceCurrentPosition()
        })
        if expanded {
            NSApp.activate(ignoringOtherApps: true)
            makeKey()
        } else {
            resignKey()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
