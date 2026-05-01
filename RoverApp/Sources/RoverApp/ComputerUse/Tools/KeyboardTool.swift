import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// Keyboard synthesis via `CGEvent`. Two paths:
/// - `type(_:)` types arbitrary Unicode text via `keyboardSetUnicodeString`,
///   bypassing keyboard layout (so "안녕" works on a US layout).
/// - `key(_:)` posts a single chord ("cmd+s", "Return", "alt+Tab") using
///   virtual keycodes + modifier flags.
/// Requires Accessibility permission.
@MainActor
struct KeyboardTool {
    enum KeyboardError: Error {
        case eventCreationFailed
        case unknownKey(String)
    }

    static func type(_ text: String) throws {
        for scalar in text.unicodeScalars {
            try typeOne(scalar)
        }
    }

    private static func typeOne(_ scalar: Unicode.Scalar) throws {
        var u = UInt16(scalar.value & 0xFFFF)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            throw KeyboardError.eventCreationFailed
        }
        down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &u)
        up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &u)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    static func key(_ chord: String) throws {
        let parts = chord.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyName = parts.last else { throw KeyboardError.unknownKey(chord) }
        let modifiers = parts.dropLast()

        var flags: CGEventFlags = []
        for m in modifiers {
            switch m.lowercased() {
            case "cmd", "command", "meta": flags.insert(.maskCommand)
            case "ctrl", "control":         flags.insert(.maskControl)
            case "shift":                   flags.insert(.maskShift)
            case "alt", "option", "opt":    flags.insert(.maskAlternate)
            case "fn":                      flags.insert(.maskSecondaryFn)
            default: break
            }
        }

        guard let keycode = virtualKeyCode(for: keyName) else {
            throw KeyboardError.unknownKey(keyName)
        }

        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: false) else {
            throw KeyboardError.eventCreationFailed
        }
        if !flags.isEmpty {
            down.flags = flags
            up.flags = flags
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - keycode table

    private static func virtualKeyCode(for raw: String) -> CGKeyCode? {
        let k = raw.lowercased()
        // Named keys
        switch k {
        case "return", "enter":     return CGKeyCode(kVK_Return)
        case "tab":                 return CGKeyCode(kVK_Tab)
        case "space", " ":          return CGKeyCode(kVK_Space)
        case "backspace", "delete": return CGKeyCode(kVK_Delete)
        case "escape", "esc":       return CGKeyCode(kVK_Escape)
        case "up":                  return CGKeyCode(kVK_UpArrow)
        case "down":                return CGKeyCode(kVK_DownArrow)
        case "left":                return CGKeyCode(kVK_LeftArrow)
        case "right":               return CGKeyCode(kVK_RightArrow)
        case "home":                return CGKeyCode(kVK_Home)
        case "end":                 return CGKeyCode(kVK_End)
        case "pageup":              return CGKeyCode(kVK_PageUp)
        case "pagedown":            return CGKeyCode(kVK_PageDown)
        case "f1":  return CGKeyCode(kVK_F1)
        case "f2":  return CGKeyCode(kVK_F2)
        case "f3":  return CGKeyCode(kVK_F3)
        case "f4":  return CGKeyCode(kVK_F4)
        case "f5":  return CGKeyCode(kVK_F5)
        case "f6":  return CGKeyCode(kVK_F6)
        case "f7":  return CGKeyCode(kVK_F7)
        case "f8":  return CGKeyCode(kVK_F8)
        case "f9":  return CGKeyCode(kVK_F9)
        case "f10": return CGKeyCode(kVK_F10)
        case "f11": return CGKeyCode(kVK_F11)
        case "f12": return CGKeyCode(kVK_F12)
        default: break
        }
        // Single character ANSI mapping (US layout).
        guard k.count == 1, let c = k.first else { return nil }
        switch c {
        case "a": return CGKeyCode(kVK_ANSI_A)
        case "b": return CGKeyCode(kVK_ANSI_B)
        case "c": return CGKeyCode(kVK_ANSI_C)
        case "d": return CGKeyCode(kVK_ANSI_D)
        case "e": return CGKeyCode(kVK_ANSI_E)
        case "f": return CGKeyCode(kVK_ANSI_F)
        case "g": return CGKeyCode(kVK_ANSI_G)
        case "h": return CGKeyCode(kVK_ANSI_H)
        case "i": return CGKeyCode(kVK_ANSI_I)
        case "j": return CGKeyCode(kVK_ANSI_J)
        case "k": return CGKeyCode(kVK_ANSI_K)
        case "l": return CGKeyCode(kVK_ANSI_L)
        case "m": return CGKeyCode(kVK_ANSI_M)
        case "n": return CGKeyCode(kVK_ANSI_N)
        case "o": return CGKeyCode(kVK_ANSI_O)
        case "p": return CGKeyCode(kVK_ANSI_P)
        case "q": return CGKeyCode(kVK_ANSI_Q)
        case "r": return CGKeyCode(kVK_ANSI_R)
        case "s": return CGKeyCode(kVK_ANSI_S)
        case "t": return CGKeyCode(kVK_ANSI_T)
        case "u": return CGKeyCode(kVK_ANSI_U)
        case "v": return CGKeyCode(kVK_ANSI_V)
        case "w": return CGKeyCode(kVK_ANSI_W)
        case "x": return CGKeyCode(kVK_ANSI_X)
        case "y": return CGKeyCode(kVK_ANSI_Y)
        case "z": return CGKeyCode(kVK_ANSI_Z)
        case "0": return CGKeyCode(kVK_ANSI_0)
        case "1": return CGKeyCode(kVK_ANSI_1)
        case "2": return CGKeyCode(kVK_ANSI_2)
        case "3": return CGKeyCode(kVK_ANSI_3)
        case "4": return CGKeyCode(kVK_ANSI_4)
        case "5": return CGKeyCode(kVK_ANSI_5)
        case "6": return CGKeyCode(kVK_ANSI_6)
        case "7": return CGKeyCode(kVK_ANSI_7)
        case "8": return CGKeyCode(kVK_ANSI_8)
        case "9": return CGKeyCode(kVK_ANSI_9)
        default: return nil
        }
    }
}
