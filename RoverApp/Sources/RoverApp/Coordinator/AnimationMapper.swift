import Foundation

/// Pure mapping from `AgentEvent` to a `RoverState` change. Returns `nil`
/// for events that should not change Rover's animation. Reuses all 13
/// existing states — no new sprite folders.
enum AnimationMapper {
    static func mapEventToState(_ event: AgentEvent) -> RoverState? {
        switch event {
        case .sessionStarted:
            return .startSpeak
        case .statusChanged(let s) where s.lowercased() == "requesting":
            return .speak
        case .statusChanged:
            return nil
        case .textDelta:
            return .speak
        case .reasoning:
            return .idleFidget
        case .observabilityToolCall(let name, _):
            return mapToolName(name)
        case .observabilityToolError:
            return .ashamed
        case .computerUseRequest(let action, _):
            return mapComputerAction(action)
        case .computerUseResult(_, let ok, _):
            return ok ? nil : .ashamed
        case .turnCompleted:
            return .endSpeak
        case .error:
            return .ashamed
        }
    }

    private static func mapToolName(_ name: String) -> RoverState {
        switch name.lowercased() {
        // Claude Code CLI tools
        case "read", "glob", "grep", "ls":
            return .reading
        case "bash", "shell", "edit", "write", "notebookedit":
            return .eat
        case "webfetch", "websearch":
            return .lick
        // Codex CLI item types
        case "command_execution", "file_change":
            return .eat
        case "web_search":
            return .lick
        case "mcp_tool_call":
            return .eat
        default:
            return .eat
        }
    }

    private static func mapComputerAction(_ action: ComputerUseAction) -> RoverState {
        switch action {
        case .screenshot, .getActiveWindow:
            return .reading
        case .leftClick, .rightClick, .doubleClick, .key:
            return .haf
        case .mouseMove:
            return .getAttention
        case .type:
            return .eat
        case .scroll:
            return .lick
        case .wait:
            return .idleFidget
        }
    }
}
