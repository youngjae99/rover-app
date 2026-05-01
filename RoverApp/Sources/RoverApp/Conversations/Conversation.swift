import Foundation

/// A single archived conversation — first user prompt as title, transcript
/// as it stood when archived, plus the backend's resume token (currently
/// only Claude Code populates this) so we can pick up exactly where the
/// user left off.
struct Conversation: Identifiable, Equatable, Codable {
    var id: UUID
    var title: String
    var transcript: [TranscriptItem]
    /// Claude Code session id. Lets `--resume` continue the on-disk
    /// conversation log + memory state. nil for backends that don't
    /// expose a resume token.
    var claudeSessionId: String?
    var backendId: String
    var model: String?
    var createdAt: Date
    var updatedAt: Date
}
