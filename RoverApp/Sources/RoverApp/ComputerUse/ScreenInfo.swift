import Foundation
import AppKit

/// Primary-display logical/pixel size and conversions. Multi-display is
/// out of scope for v0.2 — Roger drives the primary screen only.
@MainActor
struct ScreenInfo {
    static var primaryLogicalSize: CGSize {
        guard let s = NSScreen.main else { return CGSize(width: 1440, height: 900) }
        return s.frame.size
    }

    /// Pixel size = logical * backingScale. Used to size ScreenCaptureKit
    /// captures so they match the actual pixels the user sees.
    static var primaryPixelSize: CGSize {
        guard let s = NSScreen.main else { return primaryLogicalSize }
        let scale = s.backingScaleFactor
        return CGSize(width: s.frame.width * scale,
                      height: s.frame.height * scale)
    }

    static var primaryBackingScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2.0
    }
}
