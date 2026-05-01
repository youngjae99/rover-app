import Foundation
import Security

/// Thin Keychain wrapper for storing third-party API keys. Keys live as
/// `kSecClassGenericPassword` items keyed by service name. The Codex
/// backend authenticates via `~/.codex` and is intentionally absent here.
@MainActor
final class KeychainStore: ObservableObject {
    static let shared = KeychainStore()

    private let service = "rover.app.keys"

    @Published private(set) var hasAnthropicKey: Bool = false

    init() {
        hasAnthropicKey = (read("anthropic.apiKey") != nil)
    }

    var anthropicAPIKey: String? {
        get { read("anthropic.apiKey") }
        set {
            if let v = newValue, !v.isEmpty { write("anthropic.apiKey", v) }
            else { delete("anthropic.apiKey") }
            hasAnthropicKey = (newValue?.isEmpty == false)
        }
    }

    // MARK: - Underlying SecItem calls

    private func read(_ account: String) -> String? {
        var item: AnyObject?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private func write(_ account: String, _ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func delete(_ account: String) {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary)
    }
}
