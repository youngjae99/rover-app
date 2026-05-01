import Foundation
import Combine

/// Owns the agent backends, exposes a single dispatch surface
/// (`sendUserPrompt`) and forwards `AgentEvent`s to a single subscriber
/// (the view model). The coordinator is UI-state-free.
///
/// `activeBackendId` is read live from `settings` so backend switches
/// in the Settings UI take effect on the next prompt with no rewiring.
@MainActor
final class AgentCoordinator: ObservableObject {
    /// Subscribe to receive every event from the currently-running backend.
    var onEvent: ((AgentEvent) -> Void)?

    private(set) var backends: [BackendID: AgentBackend] = [:]
    let settings: RoverSettings

    init(settings: RoverSettings) {
        self.settings = settings
    }

    func register(_ backend: AgentBackend) {
        backend.onEvent = { [weak self] event in self?.onEvent?(event) }
        backends[backend.id] = backend
    }

    var activeBackendId: BackendID { settings.activeBackendId }
    var activeBackend: AgentBackend? { backends[activeBackendId] }
    var isRunning: Bool { activeBackend?.isRunning ?? false }

    // MARK: - Dispatch

    func sendUserPrompt(_ prompt: String) {
        let turn = AgentTurn(
            prompt: prompt,
            attachments: [],
            systemPromptOverride: settings.systemPrompt,
            triggerContext: nil,
            cwd: settings.workingDirectory,
            model: settings.model,
            allowDangerously: settings.allowDangerously
        )
        guard let backend = activeBackend else {
            onEvent?(.error("No backend registered for \(activeBackendId.rawValue)"))
            return
        }
        backend.send(turn: turn)
    }

    func cancel() {
        activeBackend?.cancel()
    }

    // MARK: - Triggers

    /// Called by registered `Trigger`s when they fire. Three behaviours:
    /// - `requiresUserPrompt`: open the input bubble; the user types the
    ///   prompt and `sendUserPrompt` runs as usual.
    /// - Otherwise, with a `promptHint`: emit a synthetic
    ///   `.statusChanged` event so Roger animates and shows a hint
    ///   bubble — but does NOT call the agent (zero cost).
    /// - With attachments (e.g. periodic screenshot) and no user prompt:
    ///   dispatch a turn whose prompt is the hint and attachments are
    ///   forwarded so the agent has context.
    var onTriggerFired: ((TriggerContext) -> Void)?

    func handleTriggerFired(_ ctx: TriggerContext) {
        onTriggerFired?(ctx)
        if ctx.requiresUserPrompt { return }
        if !ctx.attachments.isEmpty {
            let turn = AgentTurn(
                prompt: ctx.promptHint ?? "(triggered)",
                attachments: ctx.attachments,
                systemPromptOverride: settings.systemPrompt,
                triggerContext: TriggerContextLite(
                    triggerId: ctx.triggerId.rawValue,
                    promptHint: ctx.promptHint
                ),
                cwd: settings.workingDirectory,
                model: settings.model,
                allowDangerously: settings.allowDangerously
            )
            // Triggered, attachment-bearing turns always go to Computer Use.
            backends[.anthropicComputerUse]?.send(turn: turn)
        }
    }
}
