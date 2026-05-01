import Foundation

enum BackendID: String, Codable, CaseIterable, Sendable {
    case claudeCodeCLI
    case codexCLI
    case anthropicComputerUse

    var displayName: String {
        switch self {
        case .claudeCodeCLI:        return "Claude Code"
        case .codexCLI:              return "Codex"
        case .anthropicComputerUse:  return "Computer Use (Anthropic)"
        }
    }
}

enum ScrollDirection: String, Codable, Sendable {
    case up, down, left, right
}

/// A single discrete action the Anthropic computer-use loop has asked Roger
/// to perform on the user's machine. CLI backends never emit these.
enum ComputerUseAction: Sendable {
    case screenshot
    case leftClick(x: Int, y: Int, modifiers: [String])
    case rightClick(x: Int, y: Int)
    case doubleClick(x: Int, y: Int)
    case mouseMove(x: Int, y: Int)
    case type(String)
    case key(String)                                     // e.g. "cmd+s", "Return"
    case scroll(x: Int, y: Int, direction: ScrollDirection, amount: Int)
    case wait(ms: Int)
    case getActiveWindow

    var shortLabel: String {
        switch self {
        case .screenshot:        return "screenshot"
        case .leftClick:         return "click"
        case .rightClick:        return "right-click"
        case .doubleClick:       return "double-click"
        case .mouseMove:         return "move"
        case .type:              return "type"
        case .key:               return "key"
        case .scroll:            return "scroll"
        case .wait:              return "wait"
        case .getActiveWindow:   return "active-window"
        }
    }
}

/// Unified event stream produced by all `AgentBackend` implementations.
/// The two distinct lanes are observability tool calls (CLI agents,
/// animation-only) and computer-use requests (Anthropic loop, actually
/// executed by Roger).
enum AgentEvent: Sendable {
    case sessionStarted(id: String, backend: BackendID)
    case statusChanged(String)
    case textDelta(String)
    case reasoning(String)
    case observabilityToolCall(name: String, summary: String?)
    case observabilityToolError(name: String)
    case computerUseRequest(action: ComputerUseAction, id: String)
    case computerUseResult(id: String, ok: Bool, summary: String)
    case turnCompleted(text: String, costUSD: Double?, durationMs: Int?)
    case error(String)
}
