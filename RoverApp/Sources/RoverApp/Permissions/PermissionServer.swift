import Foundation
import Network

/// Loopback HTTP server that pairs with the auto-installed Claude Code
/// `PreToolUse` hook script. The script POSTs the tool-call JSON to
/// `/pretooluse`, this server suspends the response until the user
/// clicks Allow / Deny in Rover's bubble, and the resulting JSON is
/// echoed back as the hook's stdout — which Claude Code interprets as
/// a permission decision.
///
/// Threading: starts on the main queue (so UI callbacks land on the
/// main actor without bouncing). One short-lived NWConnection per
/// request, request bodies are tiny (a few KB at most).
@MainActor
final class PermissionServer: ObservableObject {
    @Published private(set) var port: UInt16 = 0
    @Published private(set) var isRunning: Bool = false

    /// Called when a new request lands. The view model uses this to
    /// surface the request in the bubble.
    var onRequest: ((PermissionRequest) -> Void)?

    private var listener: NWListener?
    private var continuations: [UUID: CheckedContinuation<PermissionRequest.Decision, Never>] = [:]

    func start() throws {
        guard listener == nil else { return }
        let params = NWParameters.tcp
        params.acceptLocalOnly = true        // 127.0.0.1 / ::1 only
        params.allowLocalEndpointReuse = true
        let l = try NWListener(using: params)
        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor in self?.accept(conn) }
        }
        l.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    if let p = l.port?.rawValue {
                        self?.port = p
                        self?.isRunning = true
                    }
                case .failed(let err):
                    NSLog("PermissionServer failed: \(err)")
                    self?.isRunning = false
                case .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }
        }
        l.start(queue: .main)
        listener = l
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = 0
        isRunning = false
        // Resume any pending so we don't leak. Deny is the safer default
        // when Rover is going away.
        for c in continuations.values { c.resume(returning: .deny) }
        continuations.removeAll()
    }

    /// Called from the UI when the user clicks Allow / Deny.
    func respond(id: UUID, decision: PermissionRequest.Decision) {
        if let c = continuations.removeValue(forKey: id) {
            c.resume(returning: decision)
        }
    }

    // MARK: - Connection handling

    private func accept(_ conn: NWConnection) {
        conn.start(queue: .main)
        Task { await handle(conn) }
    }

    private func handle(_ conn: NWConnection) async {
        defer { conn.cancel() }
        guard let request = await readRequest(conn) else {
            await sendString(conn, "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            return
        }
        // Single endpoint. Anything else 404s.
        guard request.head.contains("/pretooluse") else {
            await sendString(conn, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            return
        }
        let json = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any] ?? [:]
        let toolName = (json["tool_name"] as? String) ?? "tool"
        let toolInput = json["tool_input"] as? [String: Any]
        let summary = toolInput.flatMap { Self.summarize($0) }
        let detail = toolInput.flatMap(Self.prettyDetail)

        let req = PermissionRequest(toolName: toolName,
                                    summary: summary,
                                    inputDetail: detail)

        let decision: PermissionRequest.Decision = await withCheckedContinuation { c in
            continuations[req.id] = c
            onRequest?(req)
        }

        let respJSON: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": decision.rawValue,
                "permissionDecisionReason": "Resolved by Rover (\(decision.rawValue))"
            ]
        ]
        let body = (try? JSONSerialization.data(withJSONObject: respJSON, options: [])) ?? Data()
        let header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        await sendString(conn, header)
        await sendData(conn, body)
    }

    // MARK: - Tool-input rendering

    private static let interestingKeys = ["command", "file_path", "path", "pattern", "url", "query", "description"]

    static func summarize(_ input: [String: Any]) -> String? {
        for key in interestingKeys {
            if let v = input[key] as? String, !v.isEmpty {
                return "\(key): \(v.prefix(160))"
            }
        }
        return nil
    }

    static func prettyDetail(_ input: [String: Any]) -> String? {
        guard !input.isEmpty,
              let data = try? JSONSerialization.data(
                withJSONObject: input,
                options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    // MARK: - HTTP read / write helpers

    private struct ParsedRequest {
        let head: String
        let body: Data
    }

    /// Read until the headers terminator, then read Content-Length more
    /// bytes for the body. Bounded at 1 MB so a runaway client can't
    /// blow up our memory.
    private func readRequest(_ conn: NWConnection) async -> ParsedRequest? {
        var buf = Data()
        let headerTerm = Data([0x0d, 0x0a, 0x0d, 0x0a])
        while buf.range(of: headerTerm) == nil {
            guard let chunk = await receive(conn, max: 8192), !chunk.isEmpty else { return nil }
            buf.append(chunk)
            if buf.count > 1_048_576 { return nil }
        }
        guard let r = buf.range(of: headerTerm) else { return nil }
        let head = String(data: buf.subdata(in: 0..<r.lowerBound), encoding: .utf8) ?? ""
        var body = buf.subdata(in: r.upperBound..<buf.count)
        let cl = Self.contentLength(in: head) ?? 0
        while body.count < cl {
            guard let chunk = await receive(conn, max: 8192), !chunk.isEmpty else { break }
            body.append(chunk)
            if body.count > 1_048_576 { return nil }
        }
        if body.count > cl, cl > 0 {
            body = body.prefix(cl)
        }
        return ParsedRequest(head: head, body: body)
    }

    private static func contentLength(in head: String) -> Int? {
        for line in head.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length",
               let n = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                return n
            }
        }
        return nil
    }

    private func receive(_ conn: NWConnection, max: Int) async -> Data? {
        await withCheckedContinuation { (c: CheckedContinuation<Data?, Never>) in
            conn.receive(minimumIncompleteLength: 1, maximumLength: max) { data, _, _, error in
                if error != nil { c.resume(returning: nil); return }
                c.resume(returning: data)
            }
        }
    }

    private func sendString(_ conn: NWConnection, _ s: String) async {
        await sendData(conn, Data(s.utf8))
    }

    private func sendData(_ conn: NWConnection, _ data: Data) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            conn.send(content: data, completion: .contentProcessed { _ in c.resume() })
        }
    }
}
