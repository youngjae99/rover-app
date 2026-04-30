import SwiftUI
import AppKit

struct RoverPetView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var settings: RoverSettings
    @State private var dragOffset: CGPoint?

    private let spriteSize: CGFloat = 200

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if viewModel.bubbleMode != .hidden {
                SpeechBubbleView(tailOffsetFromTrailing: spriteSize / 2)
                    .fixedSize(horizontal: true, vertical: true)
            }

            RoverSpriteView()
                .frame(width: spriteSize, height: spriteSize)
                .gesture(dragGesture)
                .onTapGesture(count: 1) { /* swallowed by drag gesture */ }
                .contextMenu { contextMenu }
                .overlay(rightClickCatcher)
                .cursor(.openHand)
        }
        .frame(alignment: .bottomTrailing)
        .fixedSize(horizontal: true, vertical: true)
    }

    /// AppKit-side right-click handler that shows the same NSMenu the
    /// `.contextMenu` modifier defines. Needed because borderless windows
    /// occasionally drop SwiftUI's contextMenu in some configurations.
    private var rightClickCatcher: some View {
        RightClickCatcher {
            showRightClickMenu()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard let window = NSApp.windows.first(where: { $0 is FloatingWindow }) else { return }
                let mouse = NSEvent.mouseLocation
                if dragOffset == nil {
                    let origin = window.frame.origin
                    dragOffset = CGPoint(
                        x: mouse.x - origin.x,
                        y: mouse.y - origin.y
                    )
                }
                guard let off = dragOffset else { return }
                window.setFrameOrigin(NSPoint(
                    x: mouse.x - off.x,
                    y: mouse.y - off.y
                ))
                // Refresh the bubble cap on every drag step so the bubble
                // shrinks/grows in lock-step with available headroom.
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.windowWasMoved()
                }
            }
            .onEnded { value in
                let moved = abs(value.translation.width) + abs(value.translation.height)
                dragOffset = nil
                if moved < 4 {
                    handleClick()
                }
            }
    }

    private func handleClick() {
        switch viewModel.bubbleMode {
        case .hidden:
            viewModel.openInput()
        case .input, .showing, .error, .streaming:
            viewModel.poke()
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        let s = settings.s
        Button(s.menuAsk) { viewModel.openInput() }
            .keyboardShortcut("k", modifiers: [.command])
        Divider()
        Toggle(s.menuSound, isOn: $settings.soundEnabled)
        Toggle(s.menuShowMenuBar, isOn: $settings.showMenuBarIcon)
        Divider()
        Menu(s.menuModelLabel) {
            ForEach(RoverSettings.availableModels) { option in
                Button {
                    settings.model = option.id
                } label: {
                    if settings.model == option.id {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        }
        Button(s.menuSettings) { showSettings() }
            .keyboardShortcut(",", modifiers: [.command])
        Divider()
        Button(s.menuQuit) { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: [.command])
    }

    private func showSettings() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.showSettings()
        }
    }

    private func showRightClickMenu() {
        let s = settings.s
        let menu = NSMenu()
        addItem(to: menu, title: s.menuAsk) { viewModel.openInput() }
        menu.addItem(.separator())
        let soundItem = NSMenuItem(title: s.menuSound, action: nil, keyEquivalent: "")
        soundItem.state = settings.soundEnabled ? .on : .off
        bindToggle(soundItem) { settings.soundEnabled.toggle() }
        menu.addItem(soundItem)

        let mbItem = NSMenuItem(title: s.menuShowMenuBar, action: nil, keyEquivalent: "")
        mbItem.state = settings.showMenuBarIcon ? .on : .off
        bindToggle(mbItem) { settings.showMenuBarIcon.toggle() }
        menu.addItem(mbItem)

        menu.addItem(.separator())

        let modelMenu = NSMenu(title: s.menuModelLabel)
        for option in RoverSettings.availableModels {
            let item = NSMenuItem(title: option.label, action: nil, keyEquivalent: "")
            item.state = settings.model == option.id ? .on : .off
            bindToggle(item) { settings.model = option.id }
            modelMenu.addItem(item)
        }
        let modelParent = NSMenuItem(title: "\(s.menuModelLabel) — \(settings.currentModelLabel)",
                                     action: nil, keyEquivalent: "")
        modelParent.submenu = modelMenu
        menu.addItem(modelParent)

        addItem(to: menu, title: s.menuSettings, keyEquivalent: ",", modifiers: [.command]) {
            showSettings()
        }
        menu.addItem(.separator())
        addItem(to: menu, title: s.menuQuit, keyEquivalent: "q", modifiers: [.command]) {
            NSApp.terminate(nil)
        }

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }

    private func addItem(to menu: NSMenu, title: String, keyEquivalent: String = "",
                         modifiers: NSEvent.ModifierFlags = [], action: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifiers
        bindToggle(item, action: action)
        menu.addItem(item)
    }

    private func bindToggle(_ item: NSMenuItem, action: @escaping () -> Void) {
        let target = MenuActionTarget(action: action)
        item.target = target
        item.action = #selector(MenuActionTarget.fire)
        objc_setAssociatedObject(item, "RoverMenuTarget", target, .OBJC_ASSOCIATION_RETAIN)
    }
}

private final class MenuActionTarget: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func fire() { action() }
}

private struct RightClickCatcher: NSViewRepresentable {
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = RightClickView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? RightClickView)?.onRightClick = onRightClick
    }

    final class RightClickView: NSView {
        var onRightClick: (() -> Void)?

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        /// Pass through left-clicks so the underlying SwiftUI drag/tap gesture
        /// fires. Only intercept the click if the current event is a right-
        /// click; otherwise return nil (transparent to hit testing).
        override func hitTest(_ point: NSPoint) -> NSView? {
            if let event = NSApp.currentEvent {
                switch event.type {
                case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
                    return super.hitTest(point)
                default:
                    return nil
                }
            }
            return nil
        }
    }
}
