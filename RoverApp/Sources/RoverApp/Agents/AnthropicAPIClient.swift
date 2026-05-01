import Foundation

/// Minimal `URLSession`-based client for `POST /v1/messages` on the
/// Anthropic API. Non-streaming — `AnthropicComputerUseBackend` chunks
/// the final text into pseudo-deltas for the speak animation.
struct AnthropicAPIClient {
    enum APIError: Error, CustomStringConvertible {
        case http(status: Int, body: String)
        case decoding(String)
        case transport(String)

        var description: String {
            switch self {
            case .http(let s, let b):     return "HTTP \(s): \(b.prefix(400))"
            case .decoding(let s):         return "decode: \(s)"
            case .transport(let s):        return "transport: \(s)"
            }
        }
    }

    let apiKey: String
    let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    let beta = "computer-use-2025-11-24"

    /// `requestJSON` is the raw body we serialize and POST. The caller
    /// owns building it (model, tools, messages, etc.) so the client stays
    /// thin and stateless.
    func sendMessage(requestJSON: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue(beta, forHTTPHeaderField: "anthropic-beta")
        req.httpBody = try JSONSerialization.data(withJSONObject: requestJSON, options: [])

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = resp as? HTTPURLResponse else {
            throw APIError.transport("non-HTTP response")
        }
        if http.statusCode < 200 || http.statusCode >= 300 {
            throw APIError.http(status: http.statusCode,
                                body: String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decoding("not a JSON object")
        }
        return json
    }
}
