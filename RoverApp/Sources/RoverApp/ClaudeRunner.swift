import Foundation

enum ClaudeEvent {
    case status(String)
    case textDelta(String)
    case thinkingDelta(String)
    case toolUse(name: String, input: String?)
    case toolResult(text: String, isError: Bool)
    case complete(result: String, costUSD: Double?, durationMS: Int?)
    case error(String)
    case sessionStarted(id: String)
}

@MainActor
final class ClaudeRunner {
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stdinPipe: Pipe?
    private var stderrPipe: Pipe?
    private var lineBuffer = Data()
    private var sessionId: String?

    var onEvent: ((ClaudeEvent) -> Void)?
    var executablePath: String

    init(executablePath: String? = nil) {
        self.executablePath = executablePath ?? Self.detectClaudePath()
    }

    static func detectClaudePath() -> String {
        let candidates = [
            "/Applications/cmux.app/Contents/Resources/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            ProcessInfo.processInfo.environment["HOME"].map { "\($0)/.claude/local/claude" } ?? ""
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return "claude"
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    /// Session id captured from the previous turn's `system/init` event. The
    /// next call to `send` will pass `--resume <id>` so Claude Code keeps the
    /// conversation history, hooks, and MEMORY.md state across prompts.
    /// `resetSession()` clears it (used for explicit "new conversation" and
    /// when switching working directory, since Claude sessions are
    /// per-cwd).
    private(set) var lastSessionId: String?

    func resetSession() {
        lastSessionId = nil
    }

    struct LaunchOptions {
        var cwd: String?
        var model: String?
        var systemPrompt: String?
        var allowDangerously: Bool = false
    }

    func send(prompt: String, options: LaunchOptions = LaunchOptions()) {
        cancel()
        lineBuffer.removeAll()

        let proc = Process()
        let stdout = Pipe()
        let stdin = Pipe()
        let stderr = Pipe()

        proc.executableURL = URL(fileURLWithPath: executablePath)
        var args = [
            "-p",
            "--output-format", "stream-json",
            "--include-partial-messages",
            "--verbose",
            "--input-format", "text"
        ]
        if let sid = lastSessionId, !sid.isEmpty {
            args.append(contentsOf: ["--resume", sid])
        }
        if let model = options.model, !model.isEmpty {
            args.append(contentsOf: ["--model", model])
        }
        if let prompt = options.systemPrompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args.append(contentsOf: ["--append-system-prompt", prompt])
        }
        if options.allowDangerously {
            args.append("--dangerously-skip-permissions")
        }
        proc.arguments = args
        proc.standardOutput = stdout
        proc.standardInput = stdin
        proc.standardError = stderr
        if let cwd = options.cwd {
            proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        var env = ProcessInfo.processInfo.environment
        env["CLAUDE_CODE_NO_INTERACTIVE"] = "1"
        proc.environment = env

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty { return }
            Task { @MainActor in self?.consume(chunk) }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty,
                  let text = String(data: chunk, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.onEvent?(.error(text.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.cleanup() }
        }

        do {
            try proc.run()
        } catch {
            onEvent?(.error("Failed to launch claude: \(error.localizedDescription)"))
            return
        }

        self.process = proc
        self.stdoutPipe = stdout
        self.stdinPipe = stdin
        self.stderrPipe = stderr

        if let data = (prompt + "\n").data(using: .utf8) {
            stdin.fileHandleForWriting.write(data)
        }
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

    private func consume(_ chunk: Data) {
        lineBuffer.append(chunk)
        let newline = UInt8(ascii: "\n")
        while let nlIndex = lineBuffer.firstIndex(of: newline) {
            let lineData = lineBuffer.subdata(in: 0..<nlIndex)
            lineBuffer.removeSubrange(0...nlIndex)
            handleLine(lineData)
        }
    }

    private func handleLine(_ data: Data) {
        guard !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard let type = json["type"] as? String else { return }

        switch type {
        case "system":
            handleSystem(json)
        case "stream_event":
            handleStreamEvent(json)
        case "assistant":
            handleAssistant(json)
        case "user":
            handleUserToolResult(json)
        case "result":
            handleResult(json)
        default:
            break
        }
    }

    private func handleSystem(_ json: [String: Any]) {
        let subtype = json["subtype"] as? String
        if subtype == "init", let sid = json["session_id"] as? String {
            sessionId = sid
            lastSessionId = sid
            onEvent?(.sessionStarted(id: sid))
        } else if subtype == "status", let status = json["status"] as? String {
            onEvent?(.status(status))
        }
    }

    private func handleStreamEvent(_ json: [String: Any]) {
        guard let event = json["event"] as? [String: Any],
              let eventType = event["type"] as? String else { return }
        switch eventType {
        case "content_block_delta":
            guard let delta = event["delta"] as? [String: Any],
                  let deltaType = delta["type"] as? String else { return }
            switch deltaType {
            case "text_delta":
                if let text = delta["text"] as? String {
                    onEvent?(.textDelta(text))
                }
            case "thinking_delta":
                if let text = delta["thinking"] as? String {
                    onEvent?(.thinkingDelta(text))
                }
            default:
                break
            }
        default:
            break
        }
    }

    private func handleAssistant(_ json: [String: Any]) {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return }
        for block in content {
            guard let type = block["type"] as? String else { continue }
            if type == "tool_use",
               let name = block["name"] as? String {
                let inputSummary: String?
                if let input = block["input"] as? [String: Any] {
                    inputSummary = summarizeInput(input)
                } else {
                    inputSummary = nil
                }
                onEvent?(.toolUse(name: name, input: inputSummary))
            }
        }
    }

    private func handleUserToolResult(_ json: [String: Any]) {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return }
        for block in content where (block["type"] as? String) == "tool_result" {
            let isError = (block["is_error"] as? Bool) ?? false
            let text: String
            if let str = block["content"] as? String {
                text = str
            } else if let arr = block["content"] as? [[String: Any]] {
                text = arr.compactMap { $0["text"] as? String }.joined()
            } else {
                text = ""
            }
            onEvent?(.toolResult(text: text, isError: isError))
        }
    }

    private func handleResult(_ json: [String: Any]) {
        let result = (json["result"] as? String) ?? ""
        let cost = json["total_cost_usd"] as? Double
        let duration = json["duration_ms"] as? Int
        onEvent?(.complete(result: result, costUSD: cost, durationMS: duration))
    }

    private func summarizeInput(_ input: [String: Any]) -> String {
        let interesting = ["command", "file_path", "pattern", "url", "path", "query", "description"]
        for key in interesting {
            if let value = input[key] as? String, !value.isEmpty {
                return "\(key): \(value.prefix(80))"
            }
        }
        return ""
    }
}
