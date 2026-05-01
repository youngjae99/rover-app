import Foundation
import AppKit

/// Owns the Anthropic Computer Use agent loop in-process. Unlike the CLI
/// backends, this one is the actual *driver* — it asks the model what to
/// do, hands tool calls to the local `ComputerUseDispatcher`, feeds
/// results back, and iterates until the model stops requesting tools.
@MainActor
final class AnthropicComputerUseBackend: AgentBackend {
    let id: BackendID = .anthropicComputerUse
    let capabilities: BackendCapabilities = [
        .conversational, .computerUse, .multimodal, .cancellable
    ]
    var onEvent: ((AgentEvent) -> Void)?

    private let keychain: KeychainStore
    private let dispatcher: ComputerUseDispatcher
    private let safety: SafetyController
    private var task: Task<Void, Never>?

    init(keychain: KeychainStore,
         dispatcher: ComputerUseDispatcher,
         safety: SafetyController) {
        self.keychain = keychain
        self.dispatcher = dispatcher
        self.safety = safety
    }

    var isRunning: Bool { task != nil && !(task?.isCancelled ?? true) }

    func send(turn: AgentTurn) {
        cancel()
        safety.resetCancellation()

        guard let apiKey = keychain.anthropicAPIKey, !apiKey.isEmpty else {
            onEvent?(.error("Anthropic API key not set. Open Settings → Backend."))
            return
        }
        let client = AnthropicAPIClient(apiKey: apiKey)
        let model = turn.model?.isEmpty == false ? turn.model! : "claude-opus-4-7"
        let displaySize = ScreenInfo.primaryLogicalSize
        let displayWidth = Int(displaySize.width)
        let displayHeight = Int(displaySize.height)

        let tools: [[String: Any]] = [
            [
                "type": "computer_20251124",
                "name": "computer",
                "display_width_px": displayWidth,
                "display_height_px": displayHeight
            ],
            [
                "name": "get_active_window",
                "description": "Returns the bundle id, app name, focused window title, and bounding rect of the user's frontmost window. Use this when you need context that screenshots can't give (e.g. exact app identity).",
                "input_schema": [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ] as [String: Any]
            ]
        ]

        var messages: [[String: Any]] = [
            buildInitialUserMessage(turn)
        ]
        let systemPrompt = buildSystemPrompt(turn)
        let backendOnEvent = onEvent

        backendOnEvent?(.sessionStarted(id: UUID().uuidString, backend: .anthropicComputerUse))
        backendOnEvent?(.statusChanged("thinking"))

        let dispatcher = self.dispatcher
        let safety = self.safety
        let maxIterations = turn.maxIterations
        let captureSize = displaySize

        task = Task { @MainActor [weak self] in
            defer { self?.task = nil }
            for iteration in 0..<maxIterations {
                if Task.isCancelled || safety.cancelled {
                    backendOnEvent?(.error("Cancelled"))
                    return
                }

                let body: [String: Any] = [
                    "model": model,
                    "max_tokens": 4096,
                    "tools": tools,
                    "system": systemPrompt,
                    "messages": messages
                ]

                let response: [String: Any]
                do {
                    response = try await client.sendMessage(requestJSON: body)
                } catch {
                    backendOnEvent?(.error("API error: \(error)"))
                    return
                }

                guard let content = response["content"] as? [[String: Any]] else {
                    backendOnEvent?(.error("Malformed response (no content)"))
                    return
                }

                // Stream out text + collect tool_use blocks for execution.
                var toolUses: [(id: String, action: ComputerUseAction)] = []
                var assistantText = ""
                for block in content {
                    let type = block["type"] as? String
                    if type == "text", let text = block["text"] as? String {
                        assistantText += text
                        emitChunkedText(text, via: backendOnEvent)
                    } else if type == "tool_use",
                              let id = block["id"] as? String,
                              let name = block["name"] as? String,
                              let input = block["input"] as? [String: Any] {
                        if let action = parseAction(name: name,
                                                    input: input,
                                                    capture: captureSize) {
                            toolUses.append((id, action))
                        } else {
                            backendOnEvent?(.error("Unrecognized tool input for \(name): \(input)"))
                        }
                    }
                }

                // Append the assistant turn to the transcript verbatim so
                // tool_use ids stay consistent.
                messages.append([
                    "role": "assistant",
                    "content": content
                ])

                if toolUses.isEmpty {
                    let cost = response["usage"] as? [String: Any]
                    let turnText = assistantText.isEmpty
                        ? "(no text response)"
                        : assistantText
                    backendOnEvent?(.turnCompleted(
                        text: turnText,
                        costUSD: nil,
                        durationMs: nil
                    ))
                    _ = cost
                    _ = iteration
                    return
                }

                // Execute each tool_use, build the tool_result blocks.
                var toolResults: [[String: Any]] = []
                for (id, action) in toolUses {
                    backendOnEvent?(.computerUseRequest(action: action, id: id))
                    let result = await dispatcher.execute(action)
                    backendOnEvent?(.computerUseResult(id: id,
                                                      ok: result.ok,
                                                      summary: result.summary))
                    toolResults.append(buildToolResultBlock(id: id, result: result))
                    if safety.cancelled {
                        backendOnEvent?(.error("Cancelled mid-tool-call"))
                        return
                    }
                }

                messages.append([
                    "role": "user",
                    "content": toolResults
                ])
            }
            backendOnEvent?(.error("Max iterations (\(maxIterations)) reached without completion"))
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        safety.raiseCancellation()
    }

    // MARK: - Prompt building

    private func buildSystemPrompt(_ turn: AgentTurn) -> String {
        let base = turn.systemPromptOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let computerHint = """
        You are Roger, a helpful desktop companion. The user has authorized you \
        to control their Mac via the `computer` tool. Always start a fresh task \
        by taking a screenshot to understand the current state. Take small, \
        verifiable steps. If you are not sure, ask before continuing. Coordinates \
        are in logical points on the primary display \
        (\(Int(ScreenInfo.primaryLogicalSize.width))×\(Int(ScreenInfo.primaryLogicalSize.height))). \
        Do not act outside that display.
        """
        if base.isEmpty { return computerHint }
        return "\(base)\n\n\(computerHint)"
    }

    private func buildInitialUserMessage(_ turn: AgentTurn) -> [String: Any] {
        var blocks: [[String: Any]] = []
        for att in turn.attachments {
            switch att {
            case .screenshot(let png):
                blocks.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/png",
                        "data": png.base64EncodedString()
                    ] as [String: Any]
                ])
            case .userText(let text):
                blocks.append(["type": "text", "text": text])
            }
        }
        blocks.append(["type": "text", "text": turn.prompt])
        return ["role": "user", "content": blocks]
    }

    // MARK: - Tool-use parsing

    private func parseAction(name: String,
                             input: [String: Any],
                             capture size: CGSize) -> ComputerUseAction? {
        if name == "get_active_window" {
            return .getActiveWindow
        }
        guard name == "computer", let action = input["action"] as? String else {
            return nil
        }
        let coord = input["coordinate"] as? [Int] ?? []
        let x = coord.count >= 2 ? coord[0] : 0
        let y = coord.count >= 2 ? coord[1] : 0
        switch action {
        case "screenshot":
            return .screenshot
        case "left_click":
            let mods = (input["text"] as? String).map { parseModString($0) } ?? []
            return .leftClick(x: x, y: y, modifiers: mods)
        case "right_click":
            return .rightClick(x: x, y: y)
        case "double_click", "triple_click":
            return .doubleClick(x: x, y: y)
        case "mouse_move":
            return .mouseMove(x: x, y: y)
        case "type":
            guard let text = input["text"] as? String else { return nil }
            return .type(text)
        case "key":
            guard let text = input["text"] as? String else { return nil }
            return .key(text)
        case "scroll":
            let amount = (input["scroll_amount"] as? Int) ?? 3
            let dirString = (input["scroll_direction"] as? String) ?? "down"
            let dir = ScrollDirection(rawValue: dirString) ?? .down
            return .scroll(x: x, y: y, direction: dir, amount: amount * 40)
        case "wait":
            let secs = (input["duration"] as? Double) ?? 1.0
            return .wait(ms: Int(secs * 1000))
        case "cursor_position":
            return .getActiveWindow      // closest local proxy
        default:
            return nil
        }
    }

    private func parseModString(_ s: String) -> [String] {
        s.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func buildToolResultBlock(id: String, result: ToolResult) -> [String: Any] {
        if let b64 = result.imageBase64 {
            return [
                "type": "tool_result",
                "tool_use_id": id,
                "is_error": !result.ok,
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/png",
                            "data": b64
                        ] as [String: Any]
                    ] as [String: Any],
                    ["type": "text", "text": result.summary] as [String: Any]
                ]
            ]
        }
        return [
            "type": "tool_result",
            "tool_use_id": id,
            "is_error": !result.ok,
            "content": result.summary
        ]
    }

    // MARK: - Text chunking (pseudo-streaming)

    private func emitChunkedText(_ text: String,
                                 via emit: ((AgentEvent) -> Void)?) {
        let chunkSize = 60
        var idx = text.startIndex
        while idx < text.endIndex {
            let end = text.index(idx, offsetBy: chunkSize, limitedBy: text.endIndex)
                ?? text.endIndex
            emit?(.textDelta(String(text[idx..<end])))
            idx = end
        }
    }
}
