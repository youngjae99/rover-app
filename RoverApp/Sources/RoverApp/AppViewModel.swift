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

    private let runner: ClaudeRunner
    private var sleepTimer: Timer?
    private var bubbleHideTimer: Timer?

    init(settings: RoverSettings) {
        self.settings = settings
        self.runner = ClaudeRunner()
        self.runner.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }
        scheduleSleepCheck()
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
        runner.send(prompt: prompt, options: ClaudeRunner.LaunchOptions(
            cwd: settings.workingDirectory,
            model: settings.model,
            systemPrompt: settings.systemPrompt,
            allowDangerously: settings.allowDangerously
        ))
    }

    func cancelStream() {
        runner.cancel()
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

    private func handleEvent(_ event: ClaudeEvent) {
        switch event {
        case .sessionStarted:
            break
        case .status(let status):
            statusText = status
            if status == "requesting" {
                roverState = .speak
            }
        case .textDelta(let text):
            responseText += text
            if bubbleMode != .streaming { bubbleMode = .streaming }
            roverState = .speak
        case .toolUse(let name, _):
            statusText = name.lowercased()
            roverState = animationFor(tool: name)
            SoundPlayer.shared.play("Tap.wav", volume: 0.25)
        case .toolResult(_, let isError):
            if isError {
                roverState = .ashamed
            }
        case .complete(let result, _, _):
            if responseText.isEmpty { responseText = result }
            statusText = ""
            bubbleMode = responseText.isEmpty ? .hidden : .showing
            roverState = .endSpeak
            scheduleSleepCheck()
        case .error(let text):
            statusText = ""
            bubbleMode = .error(text)
            roverState = .ashamed
        }
    }

    private func animationFor(tool: String) -> RoverState {
        switch tool.lowercased() {
        case "read", "glob", "grep": return .reading
        case "bash", "shell", "edit", "write", "notebookedit": return .eat
        case "webfetch", "websearch": return .lick
        default: return .eat
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
