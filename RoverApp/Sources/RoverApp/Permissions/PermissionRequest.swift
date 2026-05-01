import Foundation

/// A single permission ask flowing in from a Claude Code (or compatible)
/// PreToolUse hook. Identified by `id` so the UI can resolve the matching
/// pending request when the user clicks Allow / Deny.
struct PermissionRequest: Identifiable, Equatable {
    enum Decision: String {
        case allow
        case deny
        /// Defer to whatever permission flow the agent would have used
        /// without Rover (Claude Code's built-in prompt). The hook returns
        /// "ask" so the agent falls back.
        case ask
    }

    let id: UUID
    /// E.g. "Bash", "Edit", "Read".
    let toolName: String
    /// Best-effort one-line summary extracted from `tool_input`. Optional —
    /// some tools don't have one obvious headline field.
    let summary: String?
    /// Full `tool_input` rendered as pretty JSON, shown when the user
    /// expands the request card. nil if the input was empty / missing.
    let inputDetail: String?
    let receivedAt: Date

    init(id: UUID = UUID(),
         toolName: String,
         summary: String? = nil,
         inputDetail: String? = nil,
         receivedAt: Date = Date()) {
        self.id = id
        self.toolName = toolName
        self.summary = summary
        self.inputDetail = inputDetail
        self.receivedAt = receivedAt
    }

    static func == (a: PermissionRequest, b: PermissionRequest) -> Bool { a.id == b.id }
}
