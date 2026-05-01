import Foundation
import AppKit
import ApplicationServices

/// Snapshot of the frontmost window: app name, bundle id, and the focused
/// window's title + bounding box if accessible.
struct WindowDescriptor: Sendable {
    var bundleID: String?
    var appName: String?
    var pid: pid_t
    var windowTitle: String?
    var frame: CGRect?

    var summary: String {
        var parts: [String] = []
        if let appName { parts.append(appName) }
        if let title = windowTitle, !title.isEmpty { parts.append("\"\(title)\"") }
        if let frame {
            parts.append("(\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)))")
        }
        return parts.isEmpty ? "(unknown frontmost app)" : parts.joined(separator: " ")
    }
}

@MainActor
struct ActiveWindowTool {
    static func current() -> WindowDescriptor {
        let app = NSWorkspace.shared.frontmostApplication
        var desc = WindowDescriptor(
            bundleID: app?.bundleIdentifier,
            appName: app?.localizedName,
            pid: app?.processIdentifier ?? 0,
            windowTitle: nil,
            frame: nil
        )
        guard let pid = app?.processIdentifier else { return desc }
        let appElem = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            appElem, kAXFocusedWindowAttribute as CFString, &focused
        )
        guard err == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return desc
        }
        // swiftlint:disable:next force_cast
        let win = focused as! AXUIElement

        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef) == .success {
            desc.windowTitle = titleRef as? String
        }
        desc.frame = readFrame(win)
        return desc
    }

    private static func readFrame(_ win: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable:next force_cast
        let posVal = posRef as! AXValue
        // swiftlint:disable:next force_cast
        let sizeVal = sizeRef as! AXValue
        guard AXValueGetValue(posVal, .cgPoint, &origin),
              AXValueGetValue(sizeVal, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }
}
