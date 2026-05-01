import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let settings: RoverSettings
    private let keychain: KeychainStore
    private let safety: SafetyController
    private var window: NSWindow?

    init(settings: RoverSettings,
         keychain: KeychainStore,
         safety: SafetyController) {
        self.settings = settings
        self.keychain = keychain
        self.safety = safety
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.center()
            return
        }

        let host = NSHostingController(
            rootView: SettingsView(
                settings: settings,
                keychain: keychain,
                safety: safety
            )
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Rover Settings"
        window.contentViewController = host
        window.center()
        window.isReleasedWhenClosed = false
        let closeDelegate = WindowCloseDelegate { [weak self] in
            self?.window = nil
        }
        window.delegate = closeDelegate
        // Window holds a weak reference to its delegate, so retain manually.
        objc_setAssociatedObject(window, "RoverSettingsDelegate", closeDelegate, .OBJC_ASSOCIATION_RETAIN)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
