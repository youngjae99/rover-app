import Foundation
import AppKit
import Carbon.HIToolbox

/// Global hotkey trigger built directly on Carbon's `RegisterEventHotKey`.
/// No third-party dep. Default binding is ⌘⇧Space; Settings can rebind.
///
/// Carbon's event handler is C-only, so we route through a small shared
/// registry keyed by hotkey id and dispatch back to Swift on main.
@MainActor
final class HotkeyTrigger: Trigger {
    let id: TriggerID = .globalHotkey
    var isEnabled: Bool {
        didSet {
            if oldValue == isEnabled { return }
            isEnabled ? start() : stop()
        }
    }
    var onFire: ((TriggerContext) -> Void)?

    /// macOS virtual key code (e.g. 0x31 for Space).
    var keyCode: UInt32 = UInt32(kVK_Space)
    /// Carbon modifier flags (cmdKey | shiftKey by default).
    var modifierFlags: UInt32 = UInt32(cmdKey) | UInt32(shiftKey)

    private var hotKeyRef: EventHotKeyRef?
    private var hotkeyId: UInt32 = 0

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    func start() {
        guard hotKeyRef == nil, isEnabled else { return }
        HotkeyRegistry.shared.installHandlerIfNeeded()
        let assigned = HotkeyRegistry.shared.register { [weak self] in
            guard let self else { return }
            self.onFire?(TriggerContext(
                triggerId: self.id,
                promptHint: "Hotkey",
                attachments: [],
                requiresUserPrompt: true
            ))
        }
        hotkeyId = assigned

        var hkID = EventHotKeyID(signature: OSType(0x52524B59),  // 'RRKY'
                                 id: hotkeyId)
        let status = RegisterEventHotKey(
            keyCode, modifierFlags, hkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            HotkeyRegistry.shared.unregister(hotkeyId)
            hotkeyId = 0
            hotKeyRef = nil
        }
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        hotKeyRef = nil
        if hotkeyId != 0 {
            HotkeyRegistry.shared.unregister(hotkeyId)
            hotkeyId = 0
        }
    }
}

/// C-bridgeable registry of active hotkey handlers. The Carbon handler
/// only knows the integer id; this map turns it back into a Swift closure.
@MainActor
final class HotkeyRegistry {
    static let shared = HotkeyRegistry()

    private var handlers: [UInt32: () -> Void] = [:]
    private var nextId: UInt32 = 1
    private var installed = false

    func register(_ handler: @escaping () -> Void) -> UInt32 {
        let id = nextId
        nextId += 1
        handlers[id] = handler
        return id
    }

    func unregister(_ id: UInt32) {
        handlers.removeValue(forKey: id)
    }

    func fire(_ id: UInt32) {
        handlers[id]?()
    }

    func installHandlerIfNeeded() {
        if installed { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        var ref: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            _roverHotkeyHandlerProc,
            1, &spec, nil, &ref
        )
    }
}

private func _roverHotkeyHandlerProc(_ next: EventHandlerCallRef?,
                                     _ event: EventRef?,
                                     _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hkID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hkID
    )
    if status == noErr {
        let id = hkID.id
        DispatchQueue.main.async {
            HotkeyRegistry.shared.fire(id)
        }
    }
    return noErr
}
