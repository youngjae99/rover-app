import AppKit
import SwiftUI

final class FloatingWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// NSHostingView that emits a callback whenever SwiftUI's intrinsic content
/// size changes. The window observes this to resize itself upward, keeping
/// the bottom edge anchored, so the speech bubble can grow without being
/// clipped by the parent's previous frame.
final class TrackingHostingView<Root: View>: NSHostingView<Root> {
    var onIntrinsicSizeChange: ((CGSize) -> Void)?
    private var lastReported: CGSize = .zero

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        let size = self.intrinsicContentSize
        guard size.width > 0, size.height > 0 else { return }
        if abs(size.width - lastReported.width) < 0.5,
           abs(size.height - lastReported.height) < 0.5 { return }
        lastReported = size
        let callback = onIntrinsicSizeChange
        DispatchQueue.main.async {
            callback?(size)
        }
    }

    /// Receive mouse-down events even when the window is not key — without
    /// this, clicking sleeping Rover (long-idle, window non-key) is consumed
    /// by AppKit to make the window key and never reaches our gesture.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
