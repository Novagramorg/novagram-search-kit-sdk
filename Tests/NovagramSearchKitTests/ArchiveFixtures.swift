import Foundation
import NovagramSearchKit

enum ArchiveFixtures {
    static let accountPeerId: Int64 = 900_001
    static let accountRecordId: Int64 = 77
    static let otherAccountRecordId: Int64 = 78
    static let day: Int32 = 24 * 60 * 60
    static let now: Int32 = 1_800_000_000

    static func deleted(chat: Int64 = 1001, message: Int32, text: String, deletedAt: Int32 = now, account: Int64 = accountRecordId) -> NovagramArchivedMessage {
        return NovagramArchivedMessage(accountPeerId: accountPeerId, accountRecordId: account, chatPeerId: chat, messageId: message, authorPeerId: 500_001, date: deletedAt - 60, kind: .deleted(deletedAt: deletedAt), text: text)
    }

    static func edited(chat: Int64 = 1001, message: Int32, text: String, editDate: Int32 = now, account: Int64 = accountRecordId) -> NovagramArchivedMessage {
        return NovagramArchivedMessage(accountPeerId: accountPeerId, accountRecordId: account, chatPeerId: chat, messageId: message, threadId: nil, authorPeerId: 500_002, date: editDate - 600, kind: .edited(editDate: editDate), text: text)
    }

    static let macLegacyDefaults: [String: Any] = [
        "msg_1001_10": Data(#"[{"text":"Salom, test xabar","timestamp":1799990000},{"text":"Salom, test xabar 2","timestamp":1799990100,"mediaData":null}]"#.utf8),
        "msg_-2002_7": Data(#"[{"text":"Фейк хабар","timestamp":1799980000}]"#.utf8),
        "msg_3003_1": Data(#"[{"text":"Yashirin chat","timestamp":1799970000}]"#.utf8),
        "msg_bad_key": Data(#"[{"text":"x","timestamp":1}]"#.utf8),
        "msg_4004_2": Data("not json".utf8),
        "AppleLanguages": ["en"]
    ]
}

final class TemporaryDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("NovagramArchiveTests-\(UUID().uuidString)", isDirectory: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
