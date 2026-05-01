import Foundation
import SwiftUI

enum BubbleMode: Equatable {
    case hidden
    case input
    case streaming
    case showing
    case error(String)
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var bubbleMode: BubbleMode = .hidden
    @Published var inputText: String = ""
    @Published var responseText: String = ""
    @Published var statusText: String = ""
    @Published var roverState: RoverState = .idle

    /// Maximum height the speech bubble's scrollable region can occupy.
    /// AppDelegate updates this whenever the window moves or the screen
    /// changes, so the bubble never extends past the top of the visible area.
    @Published var maxBubbleScrollHeight: CGFloat = 420
    let settings: RoverSettings

    private let coordinator: AgentCoordinator
    private var sleepTimer: Timer?
    private var bubbleHideTimer: Timer?

    init(settings: RoverSettings, coordinator: AgentCoordinator) {
        self.settings = settings
        self.coordinator = coordinator
        coordinator.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }
        coordinator.onTriggerFired = { [weak self] ctx in
            self?.handleTriggerFired(ctx)
        }
        scheduleSleepCheck()
    }

    private func handleTriggerFired(_ ctx: TriggerContext) {
        cancelBubbleHide()
        if ctx.requiresUserPrompt {
            roverState = .getAttention
            bubbleMode = .input
            return
        }
        // Animation-only / hint-only trigger.
        roverState = .getAttention
        if let hint = ctx.promptHint, !hint.isEmpty {
            responseText = hint
            bubbleMode = .showing
            bubbleHideTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if case .showing = self.bubbleMode {
                        self.bubbleMode = .hidden
                        self.responseText = ""
                    }
                }
            }
        }
    }

    var isStreaming: Bool {
        if case .streaming = bubbleMode { return true }
        return false
    }

    func toggleBubble() {
        cancelBubbleHide()
        switch bubbleMode {
        case .hidden:
            bubbleMode = .input
            inputText = ""
            roverState = .getAttention
        case .input:
            bubbleMode = .hidden
            inputText = ""
        case .showing, .error:
            bubbleMode = .input
            responseText = ""
        case .streaming:
            cancelStream()
        }
    }

    func openInput() {
        cancelBubbleHide()
        if !isStreaming {
            bubbleMode = .input
            roverState = .getAttention
        }
    }

    func dismissBubble() {
        cancelBubbleHide()
        if isStreaming { return }
        bubbleMode = .hidden
        inputText = ""
        responseText = ""
    }

    /// Drop the conversation history so the next prompt starts a fresh
    /// Claude Code session (no `--resume`). Visible bubble state is also
    /// cleared so the input mode shows starters again.
    func newConversation() {
        if isStreaming { coordinator.cancel() }
        coordinator.newConversation()
        responseText = ""
        statusText = ""
        bubbleMode = .input
        roverState = .getAttention
    }

    func runStarter(_ starter: LocalizedStarter) {
        inputText = starter.prompt
        send()
    }

    func send() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isStreaming else { return }
        inputText = ""
        responseText = ""
        statusText = settings.s.statusThinking
        bubbleMode = .streaming
        roverState = .startSpeak
        SoundPlayer.shared.play("Haf.wav", volume: 0.4)
        coordinator.sendUserPrompt(prompt)
    }

    func cancelStream() {
        coordinator.cancel()
        bubbleMode = responseText.isEmpty ? .hidden : .showing
        statusText = settings.s.statusCancelled
        roverState = .endSpeak
    }

    func poke() {
        if isStreaming {
            roverState = .haf
            SoundPlayer.shared.play("Haf.wav", volume: 0.5)
            return
        }
        let pokes: [(RoverState, String)] = [
            (.haf, "Haf.wav"),
            (.lick, "Lick.wav"),
            (.getAttention, "Tap.wav"),
            (.ashamed, "Whine.wav")
        ]
        let pick = pokes.randomElement() ?? (.haf, "Haf.wav")
        roverState = pick.0
        SoundPlayer.shared.play(pick.1, volume: 0.4)
    }

    private func handleEvent(_ event: AgentEvent) {
        if let state = AnimationMapper.mapEventToState(event) {
            roverState = state
        }
        switch event {
        case .sessionStarted:
            break
        case .statusChanged(let s):
            statusText = s
        case .textDelta(let text):
            responseText += text
            if bubbleMode != .streaming { bubbleMode = .streaming }
        case .reasoning:
            break
        case .observabilityToolCall(let name, _):
            statusText = name.lowercased()
            SoundPlayer.shared.play("Tap.wav", volume: 0.25)
        case .observabilityToolError:
            break
        case .computerUseRequest(let action, _):
            statusText = action.shortLabel
            SoundPlayer.shared.play("Tap.wav", volume: 0.25)
        case .computerUseResult:
            break
        case .turnCompleted(let result, _, _):
            if responseText.isEmpty { responseText = result }
            statusText = ""
            bubbleMode = responseText.isEmpty ? .hidden : .showing
            scheduleSleepCheck()
        case .error(let text):
            statusText = ""
            bubbleMode = .error(text)
        }
    }

    private func scheduleSleepCheck() {
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      !self.isStreaming,
                      self.bubbleMode == .hidden,
                      self.roverState == .idle else { return }
                self.roverState = .sleep
            }
        }
    }

    private func cancelBubbleHide() {
        bubbleHideTimer?.invalidate()
        bubbleHideTimer = nil
    }
}
