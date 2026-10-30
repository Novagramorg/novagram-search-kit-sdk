import Foundation

/// Reads the macOS edit history kept before the archive: the `uz.fenixuz.app.editedHistory` suite, one key
/// `msg_<chatPeerId>_<messageId>` per message holding JSON `[{"text", "timestamp", "mediaData"?}]`, not per account.
public enum NovagramArchiveMacLegacyImport {
    public static let suiteName = "uz.fenixuz.app.editedHistory"
    public static let keyPrefix = "msg_"

    private struct LegacyEntry: Decodable {
        let text: String
        let timestamp: Int32
    }

    /// Edited records for every legacy key in `values` (for example `UserDefaults(suiteName:)?.dictionaryRepresentation()`)
    /// whose chat `includeChat` accepts. The legacy store has no author, thread or send date; the date of the first
    /// saved version stands in for the send date.
    public static func records(from values: [String: Any], accountPeerId: Int64, accountRecordId: Int64, includeChat: (Int64) -> Bool = { _ in true }) -> [NovagramArchivedMessage] {
        let decoder = JSONDecoder()
        var result: [NovagramArchivedMessage] = []
        for key in values.keys.sorted() {
            guard let (chatPeerId, messageId) = parseKey(key), includeChat(chatPeerId) else { continue }
            guard let data = values[key] as? Data, let entries = try? decoder.decode([LegacyEntry].self, from: data), !entries.isEmpty else { continue }
            let versions = entries.map { NovagramArchiveVersion(text: $0.text, timestamp: $0.timestamp) }
            let date = versions.map { $0.timestamp }.min() ?? 0
            result += NovagramArchivedMessage.editedVersions(accountPeerId: accountPeerId, accountRecordId: accountRecordId, chatPeerId: chatPeerId, messageId: messageId, date: date, previousVersions: versions, currentEditDate: nil)
        }
        return result
    }

    /// The legacy keys in `values`, to remove once their records are saved.
    public static func legacyKeys(in values: [String: Any]) -> [String] {
        return values.keys.filter { parseKey($0) != nil }.sorted()
    }

    static func parseKey(_ key: String) -> (Int64, Int32)? {
        guard key.hasPrefix(keyPrefix) else { return nil }
        let body = key.dropFirst(keyPrefix.count)
        guard let separator = body.lastIndex(of: "_") else { return nil }
        guard let chatPeerId = Int64(body[body.startIndex..<separator]), let messageId = Int32(body[body.index(after: separator)...]) else { return nil }
        return (chatPeerId, messageId)
    }
}
