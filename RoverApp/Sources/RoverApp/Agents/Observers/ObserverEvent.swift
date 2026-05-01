import Foundation

/// One-way notification that arrives from an external agent's hook
/// script (Cursor, Gemini, Copilot, opencode, …) via the `/observe`
/// endpoint of `PermissionServer`. Drives Rover's animation and a
/// short status hint in the bubble — does not gate the agent.
///
/// Kept deliberately narrow: tool calls, file reads, completion, and
/// error. Each external hook integration is expected to map its own
/// event vocabulary onto these four kinds before POSTing.
struct ObserverEvent {
    enum Kind: String {
        case toolCall
        case readFile
        case completed
        case error
    }

    let agent: String         // "cursor", "gemini", "copilot", "opencode", …
    let kind: Kind
    let tool: String?         // e.g. "shell", "edit", "read"
    let summary: String?      // one-line human-readable description
    let receivedAt: Date = Date()
}
