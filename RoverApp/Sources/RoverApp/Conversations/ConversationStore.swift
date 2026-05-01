import Foundation
import Combine

/// On-disk archive of past conversations, kept under
/// `~/Library/Application Support/Rover/conversations.json`. Capped at
/// `maxRecent` entries so the file stays small and the history menu doesn't
/// scroll forever.
@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []

    private let fileURL: URL
    private let maxRecent = 50

    init() {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSHomeDirectory())
        let dir = appSupport.appendingPathComponent("Rover", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("conversations.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([Conversation].self, from: data) else { return }
        // Sort newest first on load so the menu is in the order we'll show
        // it without further work.
        conversations = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(conversations) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    /// Insert or replace a conversation by id, keep the array sorted by
    /// updatedAt desc, and trim to maxRecent.
    func upsert(_ conv: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[idx] = conv
        } else {
            conversations.append(conv)
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }
        if conversations.count > maxRecent {
            conversations = Array(conversations.prefix(maxRecent))
        }
        persist()
    }

    func delete(id: UUID) {
        conversations.removeAll { $0.id == id }
        persist()
    }

    func conversation(id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }
}
