import Foundation

struct BackendCapabilities: OptionSet, Sendable {
    let rawValue: Int
    static let conversational = BackendCapabilities(rawValue: 1 << 0)
    static let codingTools    = BackendCapabilities(rawValue: 1 << 1)
    static let computerUse    = BackendCapabilities(rawValue: 1 << 2)
    static let multimodal     = BackendCapabilities(rawValue: 1 << 3)
    static let cancellable    = BackendCapabilities(rawValue: 1 << 4)
}

enum AgentAttachment {
    case screenshot(Data)
    case userText(String)
}

struct TriggerContextLite: Sendable {
    let triggerId: String
    let promptHint: String?
}

struct AgentTurn {
    var prompt: String
    var attachments: [AgentAttachment] = []
    var systemPromptOverride: String? = nil
    var triggerContext: TriggerContextLite? = nil
    var maxIterations: Int = 10

    // CLI-backend-specific pass-through (ignored by API backends).
    var cwd: String? = nil
    var model: String? = nil
    var allowDangerously: Bool = false
}

/// A swappable agent driver. Implementations push `AgentEvent`s through
/// `onEvent` as they make progress; they do NOT manage UI state themselves.
@MainActor
protocol AgentBackend: AnyObject {
    var id: BackendID { get }
    var capabilities: BackendCapabilities { get }
    var onEvent: ((AgentEvent) -> Void)? { get set }
    var isRunning: Bool { get }
    func send(turn: AgentTurn)
    func cancel()
    /// Drop any per-conversation state (session id, in-flight messages,
    /// cached tool history). Called when the user starts a new
    /// conversation, switches backends, or changes the working directory
    /// for backends where that invalidates the resume token.
    func resetSession()
}

extension AgentBackend {
    func resetSession() {}
}
