import Foundation
import SwiftUI

enum BubbleMode: Equatable {
    case hidden
    case input
    case streaming
    case showing
    case error(String)
}

enum TranscriptKind: Equatable {
    case user
    case assistant
    case reasoning
    case toolCall
    case toolError
    case status
    case error
}

struct TranscriptItem: Identifiable, Equatable {
    let id = UUID()
    var kind: TranscriptKind
    var text: String
    var meta: String? = nil
    /// True while text is still being filled in by streaming events.
    /// Flipped to false when the next item of a different kind arrives,
    /// or when the turn completes.
    var streaming: Bool = false
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var bubbleMode: BubbleMode = .hidden
    @Published var inputText: String = ""
    @Published var statusText: String = ""
    @Published var roverState: RoverState = .idle

    /// Chronological log of every event the active backend produced this
    /// conversation. Cleared on `newConversation()`. Each user turn appends
    /// a `.user` item, then the backend's events stream in as
    /// `.reasoning`, `.toolCall`, `.assistant`, etc.
    @Published var transcript: [TranscriptItem] = []

    /// Maximum height the speech bubble's scrollable region can occupy.
    /// AppDelegate updates this whenever the window moves or the screen
    /// changes, so the bubble never extends past the top of the visible area.
    @Published var maxBubbleScrollHeight: CGFloat = 420

    /// Pending Claude Code permission ask, surfaced by the local hook
    /// server. When non-nil the bubble shows an Allow / Deny card above
    /// the transcript. Resolved via `respondToPermission(_:)`.
    @Published var pendingPermission: PermissionRequest?

    let settings: RoverSettings

    private let coordinator: AgentCoordinator
    /// Wired by AppDelegate when the permission server starts. nil when
    /// the feature is off — UI stays inert.
    var permissionServer: PermissionServer?
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

    // MARK: - Permission bubble

    /// Called by `PermissionServer.onRequest`. Pops the bubble open, plays
    /// the attention sound, and parks the request waiting for a click.
    func handlePermissionRequest(_ req: PermissionRequest) {
        cancelBubbleHide()
        pendingPermission = req
        if case .hidden = bubbleMode { bubbleMode = .input }
        roverState = .getAttention
        SoundPlayer.shared.play("Tap.wav", volume: 0.45)
    }

    func respondToPermission(_ decision: PermissionRequest.Decision) {
        guard let req = pendingPermission else { return }
        permissionServer?.respond(id: req.id, decision: decision)
        pendingPermission = nil
        // If the request landed on a hidden / idle bubble, drop back to
        // hidden once resolved unless there's still a transcript to show.
        if !isStreaming, transcript.isEmpty {
            bubbleMode = .hidden
        }
    }

    // MARK: - External agent observers

    /// Called by `PermissionServer.onObserve` whenever a Cursor / Gemini /
    /// Copilot / opencode hook fires. Plays the matching animation and
    /// drops a transient hint into the bubble. Suppressed while Rover's
    /// own bubble is busy (a streaming primary backend or a pending
    /// permission ask shouldn't get preempted by background activity).
    func handleObserverEvent(_ event: ObserverEvent) {
        if isStreaming || pendingPermission != nil { return }

        switch event.kind {
        case .toolCall:
            roverState = .eat
        case .readFile:
            roverState = .reading
        case .completed:
            roverState = .haf
        case .error:
            roverState = .ashamed
        }

        let label = observerLabel(for: event)
        if !label.isEmpty {
            cancelBubbleHide()
            push(TranscriptItem(kind: .status, text: label))
            bubbleMode = .showing
            bubbleHideTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if case .showing = self.bubbleMode, !self.hasTranscriptItemsBeyondStatus() {
                        self.bubbleMode = .hidden
                        self.transcript.removeAll { $0.kind == .status }
                    }
                }
            }
        }
    }

    // MARK: - Session HUD (chip beside Rover)

    /// Number of tool calls in the current conversation. Drives the chip's
    /// "N tools" counter.
    var sessionToolCount: Int {
        transcript.reduce(into: 0) { count, item in
            if item.kind == .toolCall { count += 1 }
        }
    }

    /// Friendly short name of the active primary backend (the one that
    /// would handle the user's next prompt). External observer hooks
    /// don't show up here — they get a transient bubble hint instead.
    var sessionBackendLabel: String {
        switch settings.activeBackendId {
        case .claudeCodeCLI:        return "Claude"
        case .codexCLI:             return "Codex"
        case .anthropicComputerUse: return "Computer Use"
        }
    }

    /// True iff the chip should be visible: bubble hidden AND something
    /// actually happened in the current session. We don't show an empty
    /// "Claude · 0 tools" chip — only after the first tool call lands.
    var shouldShowSessionChip: Bool {
        guard bubbleMode == .hidden else { return false }
        if isStreaming { return true }
        return sessionToolCount > 0
    }

    private func observerLabel(for event: ObserverEvent) -> String {
        let agent = event.agent.isEmpty ? "agent" : event.agent
        let action: String
        switch event.kind {
        case .toolCall:  action = event.tool ?? "tool"
        case .readFile:  action = "read"
        case .completed: action = "done"
        case .error:     action = "error"
        }
        if let summary = event.summary, !summary.isEmpty {
            return "\(agent) · \(action) · \(summary)"
        }
        return "\(agent) · \(action)"
    }

    /// True if any non-status transcript item exists, i.e. there's
    /// "real" conversation we shouldn't auto-clear.
    private func hasTranscriptItemsBeyondStatus() -> Bool {
        transcript.contains { $0.kind != .status }
    }

    private func handleTriggerFired(_ ctx: TriggerContext) {
        cancelBubbleHide()
        if ctx.requiresUserPrompt {
            roverState = .getAttention
            bubbleMode = .input
            return
        }
        roverState = .getAttention
        if let hint = ctx.promptHint, !hint.isEmpty {
            push(TranscriptItem(kind: .status, text: hint))
            bubbleMode = .showing
            bubbleHideTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if case .showing = self.bubbleMode {
                        self.bubbleMode = .hidden
                    }
                }
            }
        }
    }

    var isStreaming: Bool {
        if case .streaming = bubbleMode { return true }
        return false
    }

    var hasTranscript: Bool { !transcript.isEmpty }

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
    }

    /// Drop the conversation history so the next prompt starts a fresh
    /// Claude Code session (no `--resume`). The bubble returns to the
    /// "starters + input" state.
    func newConversation() {
        if isStreaming { coordinator.cancel() }
        coordinator.newConversation()
        transcript = []
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
        push(TranscriptItem(kind: .user, text: prompt))
        statusText = settings.s.statusThinking
        bubbleMode = .streaming
        roverState = .startSpeak
        SoundPlayer.shared.play("Haf.wav", volume: 0.4)
        coordinator.sendUserPrompt(prompt)
    }

    func cancelStream() {
        coordinator.cancel()
        finalizeAllStreaming()
        bubbleMode = transcript.isEmpty ? .hidden : .showing
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
            appendDelta(.assistant, text)
            if bubbleMode != .streaming { bubbleMode = .streaming }
        case .reasoning(let text):
            appendDelta(.reasoning, text)
        case .observabilityToolCall(let name, let summary):
            statusText = name.lowercased()
            push(TranscriptItem(kind: .toolCall, text: name, meta: summary))
            SoundPlayer.shared.play("Tap.wav", volume: 0.25)
        case .observabilityToolError(let name):
            push(TranscriptItem(kind: .toolError, text: name.isEmpty ? "tool error" : name))
        case .computerUseRequest(let action, _):
            statusText = action.shortLabel
            push(TranscriptItem(kind: .toolCall, text: action.shortLabel))
            SoundPlayer.shared.play("Tap.wav", volume: 0.25)
        case .computerUseResult:
            break
        case .turnCompleted(let result, _, _):
            finalizeAllStreaming()
            if !result.isEmpty,
               transcript.last?.kind != .assistant {
                push(TranscriptItem(kind: .assistant, text: result))
            }
            statusText = ""
            bubbleMode = transcript.isEmpty ? .hidden : .showing
            scheduleSleepCheck()
        case .error(let text):
            finalizeAllStreaming()
            push(TranscriptItem(kind: .error, text: text))
            statusText = ""
            bubbleMode = .error(text)
        }
    }

    // MARK: - Transcript helpers

    private func push(_ item: TranscriptItem) {
        // Finalize the previous streaming item if it is a different kind,
        // so streaming flag accurately reflects only the most recent
        // continuous segment.
        if let last = transcript.last,
           last.streaming,
           last.kind != item.kind {
            var prev = last
            prev.streaming = false
            transcript[transcript.count - 1] = prev
        }
        transcript.append(item)
    }

    /// Append a streaming chunk to the most recent item of the same kind,
    /// or start a new streaming item if the previous segment was a
    /// different kind / not streaming.
    private func appendDelta(_ kind: TranscriptKind, _ text: String) {
        if let last = transcript.last, last.kind == kind, last.streaming {
            var item = last
            item.text += text
            transcript[transcript.count - 1] = item
            return
        }
        push(TranscriptItem(kind: kind, text: text, streaming: true))
    }

    private func finalizeAllStreaming() {
        for i in transcript.indices where transcript[i].streaming {
            transcript[i].streaming = false
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
