import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Captures a single screenshot of the primary display via
/// `ScreenCaptureKit`, returns PNG bytes. Requires Screen Recording
/// permission. Uses the modern one-shot `SCScreenshotManager` API
/// (macOS 14+, matching the app's deployment target).
@MainActor
struct ScreenshotTool {
    enum ScreenshotError: Error {
        case noDisplay
        case captureFailed(String)
        case encodingFailed
    }

    /// Captures the primary display at logical size (i.e. point-size, not
    /// physical pixels — keeps coordinate math simple for the agent).
    static func capturePNG() async throws -> Data {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw ScreenshotError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        // Capture at logical size so model pixel coords map 1:1 to screen.
        config.width = Int(ScreenInfo.primaryLogicalSize.width)
        config.height = Int(ScreenInfo.primaryLogicalSize.height)
        config.showsCursor = true
        config.scalesToFit = true

        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            throw ScreenshotError.captureFailed(error.localizedDescription)
        }

        // Encode to PNG.
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encodingFailed
        }
        return pngData
    }
}
