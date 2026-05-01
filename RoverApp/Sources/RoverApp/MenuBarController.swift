import AppKit
import Combine

@MainActor
final class MenuBarController {
    private let settings: RoverSettings
    private weak var viewModel: AppViewModel?
    private weak var settingsController: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    init(settings: RoverSettings,
         viewModel: AppViewModel,
         settingsController: SettingsWindowController) {
        self.settings = settings
        self.viewModel = viewModel
        self.settingsController = settingsController

        settings.$showMenuBarIcon
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                self?.apply(visible: visible)
            }
            .store(in: &cancellables)

        // Refresh the icon glyph + tooltip when DND flips so the menu
        // bar reflects the live state without waiting for a click.
        settings.$dndEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshIcon()
            }
            .store(in: &cancellables)
    }

    private func apply(visible: Bool) {
        if visible, statusItem == nil {
            install()
        } else if !visible, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(buttonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        refreshIcon()
    }

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let glyph = settings.dndEnabled ? "moon.fill" : "pawprint.fill"
        button.image = NSImage(systemSymbolName: glyph, accessibilityDescription: "Rover")
        button.image?.isTemplate = true
        button.toolTip = settings.dndEnabled ? "Rover · \(settings.s.dndStatusActive)" : "Rover"
    }

    @objc private func buttonClicked(_ sender: Any?) {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        if isRightClick {
            showMenu()
        } else {
            // Left click: open Rover input directly
            viewModel?.openInput()
            // Bring the floating window forward
            if let window = NSApp.windows.first(where: { $0 is FloatingWindow }) {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func showMenu() {
        guard let item = statusItem else { return }
        let s = settings.s
        let menu = NSMenu()
        menu.addItem(menuItem(title: s.menuAsk, selector: #selector(ask)))
        menu.addItem(menuItem(title: s.menuShowRover, selector: #selector(showWindow)))
        menu.addItem(.separator())
        let dndItem = menuItem(title: s.menuDND, selector: #selector(toggleDND))
        dndItem.state = settings.dndEnabled ? .on : .off
        menu.addItem(dndItem)
        menu.addItem(menuItem(title: s.menuSettings, selector: #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: s.menuQuit, selector: #selector(quit)))
        item.menu = menu
        item.button?.performClick(nil)
        // Detach the menu so left-click reverts to opening input.
        DispatchQueue.main.async { item.menu = nil }
    }

    private func menuItem(title: String, selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func ask() {
        viewModel?.openInput()
        if let window = NSApp.windows.first(where: { $0 is FloatingWindow }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func showWindow() {
        if let window = NSApp.windows.first(where: { $0 is FloatingWindow }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func openSettings() {
        settingsController?.show()
    }

    @objc private func toggleDND() {
        settings.dndEnabled.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
