import Foundation

/// `AgentBackend` for OpenAI Codex CLI (`codex exec --json`). Spawns the
/// CLI as a subprocess, line-buffers JSONL events, and translates them
/// into the unified `AgentEvent` model. Roger does NOT supply API keys —
/// Codex CLI authenticates itself via `~/.codex/auth.json`
/// (ChatGPT login or `OPENAI_API_KEY`).
@MainActor
final class CodexCLIBackend: AgentBackend {
    let id: BackendID = .codexCLI
    let capabilities: BackendCapabilities = [.conversational, .codingTools, .cancellable]
    var onEvent: ((AgentEvent) -> Void)?

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stdinPipe: Pipe?
    private var stderrPipe: Pipe?
    private var lineBuffer = Data()
    private var currentAgentMessage = ""
    private var didEmitFinalText = false

    var executablePath: String

    init(executablePath: String? = nil) {
        self.executablePath = executablePath ?? Self.detectCodexPath()
    }

    static func detectCodexPath() -> String {
        // User override (Settings → Advanced → CLI binaries) wins.
        let override = (UserDefaults.standard.string(forKey: "rover.codexCLIPath") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty, FileManager.default.fileExists(atPath: override) {
            return override
        }
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.cargo/bin/codex"
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return "codex"
    }

    var isRunning: Bool { process?.isRunning ?? false }

    func send(turn: AgentTurn) {
        cancel()
        lineBuffer.removeAll()
        currentAgentMessage = ""
        didEmitFinalText = false
        // Re-resolve in case the user changed the override in Settings since
        // this backend was created.
        executablePath = Self.detectCodexPath()

        let proc = Process()
        let stdout = Pipe()
        let stdin = Pipe()
        let stderr = Pipe()

        proc.executableURL = URL(fileURLWithPath: executablePath)
        var args = ["exec", "--json", "--skip-git-repo-check"]
        if let model = turn.model, !model.isEmpty {
            args.append(contentsOf: ["--model", model])
        }
        if let cwd = turn.cwd, !cwd.isEmpty {
            args.append(contentsOf: ["-C", cwd])
        }
        if turn.allowDangerously {
            args.append("--dangerously-bypass-approvals-and-sandbox")
        } else {
            args.append(contentsOf: ["--sandbox", "read-only"])
        }
        // Prompt comes last as a positional argument.
        args.append(buildPrompt(turn))
        proc.arguments = args
        proc.standardOutput = stdout
        proc.standardInput = stdin
        proc.standardError = stderr
        if let cwd = turn.cwd {
            proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty { return }
            Task { @MainActor in self?.consume(chunk) }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty,
                  let text = String(data: chunk, encoding: .utf8) else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            Task { @MainActor in self?.onEvent?(.error(trimmed)) }
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.cleanup() }
        }

        do {
            try proc.run()
        } catch {
            onEvent?(.error("Failed to launch codex: \(error.localizedDescription)"))
            return
        }

        self.process = proc
        self.stdoutPipe = stdout
        self.stdinPipe = stdin
        self.stderrPipe = stderr
        try? stdin.fileHandleForWriting.close()
    }

    func cancel() {
        process?.terminate()
        cleanup()
    }

    private func cleanup() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        stdoutPipe = nil
        stdinPipe = nil
        stderrPipe = nil
    }

    private func buildPrompt(_ turn: AgentTurn) -> String {
        if let sys = turn.systemPromptOverride,
           !sys.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(sys)\n\n---\n\n\(turn.prompt)"
        }
        return turn.prompt
    }

    // MARK: - JSONL parsing

    private func consume(_ chunk: Data) {
        lineBuffer.append(chunk)
        let newline = UInt8(ascii: "\n")
        while let nl = lineBuffer.firstIndex(of: newline) {
            let lineData = lineBuffer.subdata(in: 0..<nl)
            lineBuffer.removeSubrange(0...nl)
            handleLine(lineData)
        }
    }

    private func handleLine(_ data: Data) {
        guard !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        switch type {
        case "thread.started":
            if let id = json["thread_id"] as? String {
                onEvent?(.sessionStarted(id: id, backend: .codexCLI))
            }
        case "turn.started":
            onEvent?(.statusChanged("thinking"))
        case "item.started":
            handleItem(json["item"] as? [String: Any], started: true)
        case "item.delta":
            handleItemDelta(json["item"] as? [String: Any])
        case "item.completed":
            handleItem(json["item"] as? [String: Any], started: false)
        case "turn.completed":
            // Flush any agent_message text we accumulated and signal done.
            if !didEmitFinalText, !currentAgentMessage.isEmpty {
                streamSynthesized(currentAgentMessage)
            }
            onEvent?(.turnCompleted(text: currentAgentMessage,
                                    costUSD: nil,
                                    durationMs: nil))
        case "turn.failed":
            let msg = (json["error"] as? [String: Any])?["message"] as? String
                ?? "Codex turn failed."
            onEvent?(.error(msg))
        case "error":
            let msg = (json["message"] as? String) ?? "Codex emitted an error."
            onEvent?(.error(msg))
        default:
            break
        }
    }

    private func handleItem(_ item: [String: Any]?, started: Bool) {
        guard let item, let itemType = item["type"] as? String else { return }
        switch itemType {
        case "command_execution":
            if started {
                let cmd = (item["command"] as? String) ?? "command"
                onEvent?(.observabilityToolCall(name: "command_execution",
                                                summary: String(cmd.prefix(80))))
            }
        case "file_change":
            if started {
                let path = (item["path"] as? String) ?? ""
                onEvent?(.observabilityToolCall(name: "file_change",
                                                summary: path.isEmpty ? nil : path))
            }
        case "web_search":
            if started {
                let q = (item["query"] as? String) ?? ""
                onEvent?(.observabilityToolCall(name: "web_search",
                                                summary: q.isEmpty ? nil : q))
            }
        case "mcp_tool_call":
            if started {
                let toolName = (item["tool"] as? String) ?? "mcp"
                onEvent?(.observabilityToolCall(name: "mcp_tool_call",
                                                summary: toolName))
            }
        case "reasoning":
            if !started, let text = item["text"] as? String {
                onEvent?(.reasoning(text))
            }
        case "agent_message":
            // Codex emits the full message either as a single completed item
            // (older versions) or chunked via item.delta (newer). We synthesize
            // text deltas at completion if no deltas arrived.
            if !started, let text = item["text"] as? String, !didEmitFinalText {
                streamSynthesized(text)
            }
        default:
            break
        }
    }

    private func handleItemDelta(_ item: [String: Any]?) {
        guard let item,
              (item["type"] as? String) == "agent_message",
              let delta = item["text"] as? String else { return }
        currentAgentMessage += delta
        didEmitFinalText = true
        onEvent?(.textDelta(delta))
    }

    /// Chunk a final agent_message into ~80-char text-deltas so the speak
    /// animation feels alive rather than firing once at the end.
    private func streamSynthesized(_ text: String) {
        currentAgentMessage = text
        didEmitFinalText = true
        let chunkSize = 80
        var idx = text.startIndex
        while idx < text.endIndex {
            let end = text.index(idx, offsetBy: chunkSize, limitedBy: text.endIndex)
                ?? text.endIndex
            onEvent?(.textDelta(String(text[idx..<end])))
            idx = end
        }
    }
}
