import Foundation
import CoreGraphics

/// Mouse synthesis via `CGEvent`. Coordinates are CG points
/// (top-left origin, matches the screenshot we send to the model).
/// Requires Accessibility permission.
@MainActor
struct MouseTool {
    enum MouseError: Error {
        case outOfBounds(CGPoint)
        case eventCreationFailed
    }

    static func leftClick(at p: CGPoint, modifiers: CGEventFlags = []) throws {
        try guardBounds(p)
        try post(.leftMouseDown, at: p, button: .left, flags: modifiers)
        try post(.leftMouseUp,   at: p, button: .left, flags: modifiers)
    }

    static func rightClick(at p: CGPoint) throws {
        try guardBounds(p)
        try post(.rightMouseDown, at: p, button: .right, flags: [])
        try post(.rightMouseUp,   at: p, button: .right, flags: [])
    }

    static func doubleClick(at p: CGPoint) throws {
        try guardBounds(p)
        let down = CGEvent(mouseEventSource: nil,
                           mouseType: .leftMouseDown,
                           mouseCursorPosition: p,
                           mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil,
                         mouseType: .leftMouseUp,
                         mouseCursorPosition: p,
                         mouseButton: .left)
        guard let down, let up else { throw MouseError.eventCreationFailed }
        down.setIntegerValueField(.mouseEventClickState, value: 2)
        up.setIntegerValueField(.mouseEventClickState, value: 2)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        // second click of the double
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    static func move(to p: CGPoint) throws {
        try guardBounds(p)
        try post(.mouseMoved, at: p, button: .left, flags: [])
    }

    /// Scroll a fixed amount in pixels. `dy > 0` scrolls down (matches
    /// Anthropic docs' convention).
    static func scroll(at p: CGPoint, dx: Int, dy: Int) throws {
        try guardBounds(p)
        try move(to: p)
        guard let evt = CGEvent(scrollWheelEvent2Source: nil,
                                units: .pixel,
                                wheelCount: 2,
                                wheel1: Int32(-dy),
                                wheel2: Int32(dx),
                                wheel3: 0) else {
            throw MouseError.eventCreationFailed
        }
        evt.post(tap: .cghidEventTap)
    }

    // MARK: - Helpers

    private static func post(_ type: CGEventType,
                             at p: CGPoint,
                             button: CGMouseButton,
                             flags: CGEventFlags) throws {
        guard let evt = CGEvent(mouseEventSource: nil,
                                mouseType: type,
                                mouseCursorPosition: p,
                                mouseButton: button) else {
            throw MouseError.eventCreationFailed
        }
        if !flags.isEmpty { evt.flags = flags }
        evt.post(tap: .cghidEventTap)
    }

    private static func guardBounds(_ p: CGPoint) throws {
        let size = ScreenInfo.primaryLogicalSize
        if p.x < 0 || p.y < 0 || p.x > size.width || p.y > size.height {
            throw MouseError.outOfBounds(p)
        }
    }
}
