import Foundation
import CoreGraphics

/// Result of executing a single `ComputerUseAction`. The summary is what
/// Roger speaks/animates on; `imageBase64` is the screenshot payload sent
/// back to the Anthropic API as a tool_result.
struct ToolResult {
    let ok: Bool
    let summary: String
    let imageBase64: String?

    static func ok(_ summary: String, imageBase64: String? = nil) -> ToolResult {
        ToolResult(ok: true, summary: summary, imageBase64: imageBase64)
    }
    static func err(_ summary: String) -> ToolResult {
        ToolResult(ok: false, summary: summary, imageBase64: nil)
    }
}

/// Routes a `ComputerUseAction` to the right tool. All side-effects pass
/// through the `SafetyController` (rate limit + dry-run gate + Esc check).
@MainActor
final class ComputerUseDispatcher {
    let safety: SafetyController

    init(safety: SafetyController) {
        self.safety = safety
    }

    func execute(_ action: ComputerUseAction) async -> ToolResult {
        if safety.cancelled {
            return .err("Cancelled by user (Esc)")
        }
        await safety.enforceRateLimit()

        switch action {
        case .screenshot:
            return await runScreenshot()
        case .leftClick(let x, let y, let mods):
            return runMouse("left-click", at: x, y: y) {
                let flags = parseFlags(mods)
                try MouseTool.leftClick(at: CGPoint(x: x, y: y), modifiers: flags)
            }
        case .rightClick(let x, let y):
            return runMouse("right-click", at: x, y: y) {
                try MouseTool.rightClick(at: CGPoint(x: x, y: y))
            }
        case .doubleClick(let x, let y):
            return runMouse("double-click", at: x, y: y) {
                try MouseTool.doubleClick(at: CGPoint(x: x, y: y))
            }
        case .mouseMove(let x, let y):
            return runMouse("move", at: x, y: y) {
                try MouseTool.move(to: CGPoint(x: x, y: y))
            }
        case .scroll(let x, let y, let dir, let amount):
            return runMouse("scroll \(dir.rawValue) \(amount)", at: x, y: y) {
                let dx: Int
                let dy: Int
                switch dir {
                case .up:    (dx, dy) = (0, -amount)
                case .down:  (dx, dy) = (0,  amount)
                case .left:  (dx, dy) = (-amount, 0)
                case .right: (dx, dy) = ( amount, 0)
                }
                try MouseTool.scroll(at: CGPoint(x: x, y: y), dx: dx, dy: dy)
            }
        case .type(let text):
            if safety.dryRun {
                return .ok("DRY-RUN: would type \"\(text.prefix(40))\"")
            }
            do {
                try KeyboardTool.type(text)
                return .ok("typed \(text.count) chars")
            } catch {
                return .err("type failed: \(error)")
            }
        case .key(let chord):
            if safety.dryRun {
                return .ok("DRY-RUN: would press \(chord)")
            }
            do {
                try KeyboardTool.key(chord)
                return .ok("pressed \(chord)")
            } catch {
                return .err("key failed: \(error)")
            }
        case .wait(let ms):
            try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            return .ok("waited \(ms)ms")
        case .getActiveWindow:
            let desc = ActiveWindowTool.current()
            return .ok(desc.summary)
        }
    }

    // MARK: - Helpers

    private func runScreenshot() async -> ToolResult {
        do {
            let png = try await ScreenshotTool.capturePNG()
            let b64 = png.base64EncodedString()
            return .ok("captured screen \(Int(ScreenInfo.primaryLogicalSize.width))×\(Int(ScreenInfo.primaryLogicalSize.height))",
                       imageBase64: b64)
        } catch {
            return .err("screenshot failed: \(error)")
        }
    }

    private func runMouse(_ label: String, at x: Int, y: Int, body: () throws -> Void) -> ToolResult {
        if safety.dryRun {
            return .ok("DRY-RUN: would \(label) at (\(x), \(y))")
        }
        do {
            try body()
            return .ok("\(label) at (\(x), \(y))")
        } catch {
            return .err("\(label) failed: \(error)")
        }
    }

    private func parseFlags(_ modifiers: [String]) -> CGEventFlags {
        var f: CGEventFlags = []
        for m in modifiers {
            switch m.lowercased() {
            case "cmd", "command", "meta": f.insert(.maskCommand)
            case "ctrl", "control":         f.insert(.maskControl)
            case "shift":                   f.insert(.maskShift)
            case "alt", "option", "opt":    f.insert(.maskAlternate)
            default: break
            }
        }
        return f
    }
}
