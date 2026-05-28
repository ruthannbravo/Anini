import AppKit
import Combine
import SwiftUI

// RoundedVisualEffectView uses a CAShapeLayer mask that updates on every
// layout pass, guaranteeing pixel-perfect rounded clipping with no exposed
// rectangular edge — unlike layer.cornerRadius + masksToBounds, which can
// leave hairline artifacts when the layer bounds change.
private class RoundedVisualEffectView: NSVisualEffectView {
    var cornerRadius: CGFloat = 28 {
        didSet { updateMask() }
    }

    // Resting: airy and transparent. Hover: opaque frost so the background
    // blurs out and the chat becomes the clear focus.
    private let restingAlpha: CGFloat = 0.78
    private let hoverAlpha: CGFloat = 0.92

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        alphaValue = CGFloat(WorkspaceConfig.shared.panelOpacity)
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .inVisibleRect, .activeAlways],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        let base = CGFloat(WorkspaceConfig.shared.panelOpacity)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = min(1.0, base + 0.14)
        }
    }

    override func mouseExited(with event: NSEvent) {
        let base = CGFloat(WorkspaceConfig.shared.panelOpacity)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.38
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = base
        }
    }

    override func layout() {
        super.layout()
        updateMask()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateMask()
    }

    private func updateMask() {
        wantsLayer = true
        let mask: CAShapeLayer
        if let existing = layer?.mask as? CAShapeLayer {
            mask = existing
        } else {
            mask = CAShapeLayer()
            layer?.mask = mask
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.path = CGPath(
            roundedRect: bounds,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        CATransaction.commit()

        layer?.backgroundColor = CGColor.clear
        layer?.borderWidth = 0
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.2).cgColor
        layer?.shadowOpacity = 1.0
        layer?.shadowRadius = 28
        layer?.shadowOffset = CGSize(width: 0, height: -6)
    }
}

/// Hosting view that accepts the first mouse click even when its window isn't
/// key. The panel is a non-activating floating panel, so without this the first
/// click on a control (nav button, API-key text field, etc.) is consumed just
/// to bring the window forward — making controls feel unclickable until a
/// second click. Returning true here delivers that first click to the control.
private final class FirstMouseHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: AnyView) {
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FloatingPanel: NSPanel {
    private var cancellables = Set<AnyCancellable>()
    private var savedFrame: NSRect?
    private weak var visualEffectView: RoundedVisualEffectView?

    init(contentView: AnyView, panelState: PanelState) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let visualEffect = RoundedVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow
        visualEffect.cornerRadius = 28
        visualEffect.autoresizingMask = [.width, .height]
        self.visualEffectView = visualEffect

        let hosting = FirstMouseHostingView(rootView: contentView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.sizingOptions = []
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = CGColor.clear
        hosting.layer?.isOpaque = false
        hosting.layer?.borderWidth = 0

        visualEffect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        self.contentView = visualEffect
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.backgroundColor = CGColor.clear
        self.contentView?.layer?.borderWidth = 0
        self.minSize = NSSize(width: 56, height: 56)

        panelState.$isMinimized
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.animateToTargetHeight(panelState)
            }
            .store(in: &cancellables)

        panelState.$isFullScreen
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.toggleFullScreen(panelState)
            }
            .store(in: &cancellables)

        panelState.$isDarkMode
            .receive(on: RunLoop.main)
            .sink { [weak self] isDark in
                self?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
            }
            .store(in: &cancellables)

        WorkspaceConfig.shared.$panelOpacity
            .receive(on: RunLoop.main)
            .sink { [weak self] opacity in
                self?.visualEffectView?.alphaValue = CGFloat(opacity)
            }
            .store(in: &cancellables)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return super.performKeyEquivalent(with: event) }
        switch event.charactersIgnoringModifiers {
        case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
        case "z": return NSApp.sendAction(#selector(UndoManager.undo), to: nil, from: self)
        default:  return super.performKeyEquivalent(with: event)
        }
    }

    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        if event.type == .leftMouseUp {
            snapToEdgeIfNeeded()
        }
    }

    private func animateToTargetHeight(_ state: PanelState) {
        var newFrame = frame
        if state.isMinimized {
            newFrame.size.width  = state.collapsedSize
            newFrame.size.height = state.collapsedSize
            newFrame.origin.x    = frame.maxX - state.collapsedSize
            newFrame.origin.y    = frame.maxY - state.collapsedSize
            visualEffectView?.cornerRadius = state.collapsedSize / 2
        } else {
            newFrame.size.width  = state.expandedWidth
            newFrame.size.height = state.expandedHeight
            newFrame.origin.x    = frame.maxX - state.expandedWidth
            newFrame.origin.y    = frame.maxY - state.expandedHeight
            visualEffectView?.cornerRadius = 28
        }
        if let screen = screen ?? NSScreen.main {
            newFrame.origin.y = max(screen.visibleFrame.minY, newFrame.origin.y)
            newFrame.origin.x = max(screen.visibleFrame.minX, newFrame.origin.x)
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
    }

    private func toggleFullScreen(_ state: PanelState) {
        guard let screen = screen ?? NSScreen.main else { return }
        let targetFrame: NSRect
        if state.isFullScreen {
            savedFrame = frame
            targetFrame = screen.visibleFrame
        } else {
            // Always restore to original dimensions; keep the pre-fullscreen origin
            let origin = savedFrame.map { $0.origin } ?? NSPoint(
                x: screen.visibleFrame.midX - state.expandedWidth / 2,
                y: screen.visibleFrame.midY - state.expandedHeight / 2
            )
            targetFrame = NSRect(origin: origin, size: NSSize(width: state.expandedWidth, height: state.expandedHeight))
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(targetFrame, display: true)
        }
    }

    private func snapToEdgeIfNeeded() {
        guard let screen = screen ?? NSScreen.main else { return }
        let threshold: CGFloat = 40
        let visible = screen.visibleFrame
        var newFrame = frame

        let nearLeft   = abs(frame.minX - visible.minX) < threshold
        let nearRight  = abs(frame.maxX - visible.maxX) < threshold
        let nearTop    = abs(frame.maxY - visible.maxY) < threshold
        let nearBottom = abs(frame.minY - visible.minY) < threshold

        if nearLeft {
            // Snap left and expand to full available height
            newFrame.origin.x  = visible.minX
            newFrame.origin.y  = visible.minY
            newFrame.size.height = visible.height
        } else if nearRight {
            // Snap right and expand to full available height
            newFrame.origin.y  = visible.minY
            newFrame.size.height = visible.height
            newFrame.origin.x  = visible.maxX - newFrame.width
        } else {
            if nearTop    { newFrame.origin.y = visible.maxY - newFrame.height }
            if nearBottom { newFrame.origin.y = visible.minY }
        }

        guard newFrame != frame else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(newFrame, display: true)
        }
    }
}
