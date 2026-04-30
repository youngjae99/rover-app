import SwiftUI
import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = RoverSettings()
    lazy var viewModel = AppViewModel(settings: settings)
    lazy var settingsController = SettingsWindowController(settings: settings)
    lazy var menuBar = MenuBarController(
        settings: settings,
        viewModel: viewModel,
        settingsController: settingsController
    )

    var window: FloatingWindow!
    var host: TrackingHostingView<AnyView>!
    private var cancellables: Set<AnyCancellable> = []

    private let edgeMargin: CGFloat = 8
    private let topSafeMargin: CGFloat = 8
    private let spriteHeight: CGFloat = 200
    private let bubbleSpacing: CGFloat = 4
    /// Approximate non-scrollable bubble chrome (prompt field + paddings + tail).
    private let bubbleChromeOverhead: CGFloat = 70

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        let initialSize = NSSize(width: 220, height: 220)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        let origin = NSPoint(
            x: screenFrame.maxX - initialSize.width - edgeMargin,
            y: screenFrame.minY + edgeMargin
        )
        let frame = NSRect(origin: origin, size: initialSize)

        let rootView = AnyView(
            RoverPetView()
                .environmentObject(viewModel)
                .environmentObject(settings)
        )
        let host = TrackingHostingView(rootView: rootView)
        if #available(macOS 13.0, *) {
            host.sizingOptions = [.intrinsicContentSize]
        }
        host.onIntrinsicSizeChange = { [weak self] size in
            self?.applyContentSize(size)
        }
        self.host = host

        let window = FloatingWindow(contentRect: frame)
        window.contentView = host
        window.title = "Rover"
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)

        _ = menuBar
        recomputeBubbleCap()

        // Rebuild the main menu and refresh caps when language/screen change.
        settings.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.installMainMenu() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: window)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recomputeBubbleCap() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification, object: window)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recomputeBubbleCap() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recomputeBubbleCap() }
            .store(in: &cancellables)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Esc
                Task { @MainActor in self.viewModel.dismissBubble() }
                return nil
            }
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
                self.settingsController.show()
                return nil
            }
            return event
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func showSettings() { settingsController.show() }

    /// Called by RoverPetView's drag handler (via `windowWasMoved`) so that
    /// caps update during the drag, not just after the move-ended notification.
    func windowWasMoved() {
        recomputeBubbleCap()
        // Re-cap window height for the new position.
        let intrinsic = host?.intrinsicContentSize ?? .zero
        if intrinsic.width > 0, intrinsic.height > 0 {
            applyContentSize(intrinsic)
        }
    }

    /// Resize the window so its content area matches `size`, keeping the
    /// bottom-right corner anchored. Caps to fit the visible screen so the
    /// top edge never crosses `screen.maxY - topSafeMargin`.
    private func applyContentSize(_ size: CGSize) {
        guard let window = self.window else { return }
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let current = window.frame
        let bottomY = current.origin.y
        let availableTotalH = max(180, screenFrame.maxY - bottomY - topSafeMargin)
        let targetW = max(200, min(size.width, screenFrame.width - 16))
        let targetH = max(180, min(size.height, availableTotalH))
        let rightX = current.maxX
        let newOrigin = NSPoint(x: rightX - targetW, y: bottomY)
        let newFrame = NSRect(origin: newOrigin, size: NSSize(width: targetW, height: targetH))
        if abs(newFrame.height - current.height) < 0.5,
           abs(newFrame.width - current.width) < 0.5 { return }
        window.setFrame(newFrame, display: true, animate: false)
        // After resize, also push an updated bubble cap.
        recomputeBubbleCap()
    }

    /// Compute the maximum height the bubble's scrollable region can use,
    /// based on Rover's current Y position on screen, and publish it to the
    /// view model.
    private func recomputeBubbleCap() {
        guard let window = self.window,
              let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let bottomY = window.frame.origin.y
        let availableForBubble = screenFrame.maxY - bottomY - spriteHeight - bubbleSpacing - topSafeMargin
        let scrollMax = max(120, availableForBubble - bubbleChromeOverhead)
        if abs(viewModel.maxBubbleScrollHeight - scrollMax) > 0.5 {
            viewModel.maxBubbleScrollHeight = scrollMax
        }
    }

    private func installMainMenu() {
        let s = settings.s
        let main = NSMenu()
        let appMenuItem = NSMenuItem()
        main.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(
            title: s.menuSettings,
            action: #selector(openSettingsMenu(_:)),
            keyEquivalent: ","
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: s.menuQuit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        for item in appMenu.items where item.action == #selector(openSettingsMenu(_:)) {
            item.target = self
        }
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        main.addItem(editMenuItem)

        NSApp.mainMenu = main
    }

    @objc private func openSettingsMenu(_ sender: Any?) {
        settingsController.show()
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    objc_setAssociatedObject(app, "RoverAppDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    app.run()
}
