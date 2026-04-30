import SwiftUI

/// Windows XP "Luna" / Search Companion palette.
enum XP {
    // Light bluish-gray bubble interior, the same wash XP used on the
    // task panes and the search pane behind Rover.
    static let bubbleFill = Color(red: 0.89, green: 0.93, blue: 0.98)
    static let bubbleBorder = Color(red: 0.55, green: 0.66, blue: 0.84)
    static let bubbleShadow = Color.black.opacity(0.22)

    static let textBody = Color.black
    static let textHeader = Color.black
    static let textSecondary = Color(red: 0.27, green: 0.27, blue: 0.27)
    static let textLinkHover = Color(red: 0.0, green: 0.30, blue: 0.62)

    static let divider = Color.white.opacity(0.85)

    static let arrowGreenStart = Color(red: 0.42, green: 0.74, blue: 0.30)
    static let arrowGreenEnd = Color(red: 0.30, green: 0.55, blue: 0.16)
    static let helpBlueStart = Color(red: 0.45, green: 0.70, blue: 0.92)
    static let helpBlueEnd = Color(red: 0.20, green: 0.45, blue: 0.78)

    static let promptFieldFill = Color.white
    static let promptFieldBorder = Color(red: 0.62, green: 0.72, blue: 0.86)

    static let accent = Color(red: 0.20, green: 0.32, blue: 0.66)

    /// Tahoma if available (it ships with macOS), system fallback otherwise.
    static func font(size: CGFloat, bold: Bool = false) -> Font {
        let base = Font.custom("Tahoma", size: size)
        return bold ? base.weight(.bold) : base
    }

    static let nsTahoma = NSFont(name: "Tahoma", size: 13) ?? NSFont.systemFont(ofSize: 13)
}

// MARK: - Cursor helper

/// Adds an AppKit cursor rect covering the modified view, so the system flips
/// the pointer to `cursor` whenever the mouse is over this view. Uses
/// `NSTrackingArea`/`resetCursorRects` instead of `.onHover` so the cursor
/// flips reliably even when the mouse moves quickly.
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        background(CursorRectView(cursor: cursor))
    }
}

private struct CursorRectView: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> NSView {
        let view = CursorRectNSView()
        view.cursor = cursor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? CursorRectNSView else { return }
        view.cursor = cursor
        view.window?.invalidateCursorRects(for: view)
    }
}

private final class CursorRectNSView: NSView {
    var cursor: NSCursor = .arrow

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: cursor)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Pass through clicks — we only care about the cursor rect.
        return nil
    }
}
