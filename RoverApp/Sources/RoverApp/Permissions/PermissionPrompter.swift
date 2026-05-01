import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

/// Probes and surfaces the macOS TCC permissions Roger needs for
/// computer-use mode (Accessibility for posting CGEvents, Screen Recording
/// for ScreenCaptureKit). All checks are non-blocking and idempotent.
@MainActor
final class PermissionPrompter {
    static let shared = PermissionPrompter()
    private init() {}

    enum Status {
        case granted, denied, unknown
    }

    var accessibilityStatus: Status {
        AXIsProcessTrusted() ? .granted : .denied
    }

    var screenRecordingStatus: Status {
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    var allGranted: Bool {
        accessibilityStatus == .granted && screenRecordingStatus == .granted
    }

    /// Triggers the Accessibility prompt the first time it's called.
    /// Subsequent calls are silent and just return current state.
    @discardableResult
    func requestAccessibility(promptIfNeeded: Bool = true) -> Status {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts) ? .granted : .denied
    }

    /// Asynchronously requests Screen Recording. macOS shows the system
    /// prompt the first time. Result is read after a short delay.
    func requestScreenRecording() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
    }

    func openAccessibilityPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openScreenRecordingPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
