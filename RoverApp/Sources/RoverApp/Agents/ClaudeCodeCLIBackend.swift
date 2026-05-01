import Foundation

/// `AgentBackend` adapter around the existing `ClaudeRunner` subprocess +
/// NDJSON parser. Translates `ClaudeEvent` values into the unified
/// `AgentEvent` model. Behaviour-preserving wrapper — no new logic.
@MainActor
final class ClaudeCodeCLIBackend: AgentBackend {
    let id: BackendID = .claudeCodeCLI
    let capabilities: BackendCapabilities = [.conversational, .codingTools, .cancellable]
    var onEvent: ((AgentEvent) -> Void)?

    private let runner: ClaudeRunner

    init() {
        self.runner = ClaudeRunner()
        runner.onEvent = { [weak self] event in self?.translate(event) }
    }

    var isRunning: Bool { runner.isRunning }

    func send(turn: AgentTurn) {
        let opts = ClaudeRunner.LaunchOptions(
            cwd: turn.cwd,
            model: turn.model,
            systemPrompt: turn.systemPromptOverride,
            allowDangerously: turn.allowDangerously
        )
        runner.send(prompt: turn.prompt, options: opts)
    }

    func cancel() {
        runner.cancel()
    }

    func resetSession() {
        runner.resetSession()
    }

    private func translate(_ event: ClaudeEvent) {
        switch event {
        case .sessionStarted(let id):
            onEvent?(.sessionStarted(id: id, backend: .claudeCodeCLI))
        case .status(let s):
            onEvent?(.statusChanged(s))
        case .textDelta(let t):
            onEvent?(.textDelta(t))
        case .toolUse(let name, let summary):
            onEvent?(.observabilityToolCall(name: name, summary: summary))
        case .toolResult(_, let isError):
            if isError {
                onEvent?(.observabilityToolError(name: ""))
            }
        case .complete(let result, let cost, let dur):
            onEvent?(.turnCompleted(text: result, costUSD: cost, durationMs: dur))
        case .error(let text):
            onEvent?(.error(text))
        }
    }
}
