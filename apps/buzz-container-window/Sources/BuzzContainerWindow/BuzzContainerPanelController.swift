import AppKit
import SwiftUI

/// Intercepts only the standard yellow traffic-light action. Other native
/// title-bar behaviour remains owned by AppKit.
@MainActor
final class BubbleMiniaturizingPanel: NSPanel {
    var onMiniaturize: (() -> Void)?

    override func miniaturize(_ sender: Any?) {
        if let onMiniaturize {
            onMiniaturize()
        } else {
            super.miniaturize(sender)
        }
    }
}

@MainActor
final class BuzzContainerPanelController: NSObject, NSWindowDelegate {
    private let state = ContainerPresentationState()
    private let frameSession = VisualFrameSession()
    private let overlay: BubbleMiniaturizingPanel
    private let bubble: NSPanel
    private var bubbleDragOrigin: NSPoint?
    private var hasPlacedBubble = false

    override init() {
        overlay = BubbleMiniaturizingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        bubble = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 62, height: 62),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        configureOverlay()
        configureBubble()
        frameSession.startIfConfigured(state: state)
    }

    func showOverlay() {
        bubble.orderOut(nil)
        positionOverlay()
        overlay.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func minimizeToBubble() {
        overlay.orderOut(nil)
        showBubble()
    }

    /// Keep the standard yellow traffic-light affordance, but keep this utility
    /// window in its own lightweight bubble rather than sending it to the Dock.
    private func animateMiniaturizeToBubble() {
        ensureInitialBubblePosition()
        let destination = bubble.frame

        bubble.alphaValue = 0
        bubble.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            overlay.animator().setFrame(destination, display: true)
            overlay.animator().alphaValue = 0
            bubble.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.overlay.orderOut(nil)
                self.overlay.alphaValue = 1
                self.positionOverlay()
            }
        }
    }

    private func showBubble() {
        ensureInitialBubblePosition()
        bubble.alphaValue = 1
        bubble.orderFrontRegardless()
    }

    private func configureOverlay() {
        overlay.title = "Buzz Container"
        overlay.delegate = self
        overlay.isFloatingPanel = true
        overlay.level = .floating
        overlay.collectionBehavior = [.moveToActiveSpace]
        overlay.isMovableByWindowBackground = true
        overlay.hidesOnDeactivate = false
        overlay.onMiniaturize = { [weak self] in
            self?.animateMiniaturizeToBubble()
        }
        overlay.contentView = NSHostingView(
            rootView: BuzzContainerOverlay(
            )
            .environment(state)
        )
    }

    private func configureBubble() {
        bubble.isFloatingPanel = true
        bubble.level = .floating
        bubble.collectionBehavior = [.moveToActiveSpace]
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = true
        bubble.contentView = NSHostingView(
            rootView: ContainerBubble(
                open: { [weak self] in self?.showOverlay() },
                drag: { [weak self] translation, finished in self?.moveBubble(translation, finished: finished) }
            )
                .environment(state)
        )
    }

    private func moveBubble(_ translation: CGSize, finished: Bool) {
        if bubbleDragOrigin == nil {
            ensureInitialBubblePosition()
            bubbleDragOrigin = bubble.frame.origin
        }
        guard let origin = bubbleDragOrigin, let screen = bubble.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = min(max(origin.x + translation.width, visible.minX), visible.maxX - bubble.frame.width)
        let y = min(max(origin.y - translation.height, visible.minY), visible.maxY - bubble.frame.height)
        bubble.setFrameOrigin(NSPoint(x: x, y: y))
        if finished { bubbleDragOrigin = nil }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === overlay {
            minimizeToBubble()
            return false
        }
        return true
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        // The overlay remains a normal floating utility panel after the native
        // full-screen session ends; no task or viewer state changes here.
        overlay.level = .floating
    }

    private func ensureInitialBubblePosition() {
        guard !hasPlacedBubble else { return }
        positionBubble()
        hasPlacedBubble = true
    }

    private func positionBubble() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        bubble.setFrameOrigin(
            NSPoint(
                x: frame.midX - (bubble.frame.width / 2),
                y: frame.maxY - bubble.frame.height - 24
            )
        )
    }

    private func positionOverlay() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        overlay.setFrameOrigin(NSPoint(x: frame.maxX - 592, y: frame.minY + 24))
    }
}
