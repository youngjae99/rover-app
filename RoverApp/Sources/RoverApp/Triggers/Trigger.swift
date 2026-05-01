import Foundation

enum TriggerID: String, Codable, CaseIterable, Sendable {
    case globalHotkey
    case activeAppChange
    case periodicScreen
    case schedule
}

struct TriggerContext: Sendable {
    var triggerId: TriggerID
    var promptHint: String?
    var attachments: [AgentAttachment]
    /// True when the trigger should pop the bubble + prompt the user
    /// rather than auto-dispatch a turn.
    var requiresUserPrompt: Bool

    init(triggerId: TriggerID,
         promptHint: String? = nil,
         attachments: [AgentAttachment] = [],
         requiresUserPrompt: Bool = false) {
        self.triggerId = triggerId
        self.promptHint = promptHint
        self.attachments = attachments
        self.requiresUserPrompt = requiresUserPrompt
    }
}

@MainActor
protocol Trigger: AnyObject {
    var id: TriggerID { get }
    var isEnabled: Bool { get set }
    var onFire: ((TriggerContext) -> Void)? { get set }
    func start()
    func stop()
}
