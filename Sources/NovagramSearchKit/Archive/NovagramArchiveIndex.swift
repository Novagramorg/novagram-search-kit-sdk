import Foundation

/// An immutable, search-ready snapshot of archived messages: deduplicated, normalized once and sorted newest first.
/// Build it from any records (for example ones read from the app database) or take it from `NovagramMessageArchiveStore`.
public struct NovagramArchiveIndex {
    struct Row {
        let record: NovagramArchivedMessage
        let normalizedText: String
        let key: NovagramArchiveSortKey
    }

    let rows: [Row]

    /// An index of `records`. Repeated records (the same deleted message, or the same text of the same edited
    /// message) are kept once, the first one wins.
    public init(records: [NovagramArchivedMessage]) {
        var seen = Set<NovagramArchivedMessage.Identity>()
        var rows: [Row] = []
        rows.reserveCapacity(records.count)
        for record in records where seen.insert(record.identity).inserted {
            rows.append(NovagramArchiveIndex.row(record))
        }
        self.init(unsortedRows: rows)
    }

    init(unsortedRows: [Row]) {
        rows = unsortedRows.sorted { $0.key.precedes($1.key) }
    }

    static func row(_ record: NovagramArchivedMessage, normalizedText: String? = nil) -> Row {
        return Row(record: record, normalizedText: normalizedText ?? NovagramSearchText.normalized(record.text), key: NovagramArchiveSortKey(record))
    }

    /// The number of records.
    public var count: Int {
        return rows.count
    }

    /// All records, newest event first.
    public var records: [NovagramArchivedMessage] {
        return rows.map { $0.record }
    }
}

struct NovagramArchiveSortKey: Equatable {
    let eventDate: Int32
    let chatPeerId: Int64
    let messageId: Int32
    let isDeleted: Bool
    let text: String

    init(_ record: NovagramArchivedMessage) {
        eventDate = record.kind.eventDate
        chatPeerId = record.chatPeerId
        messageId = record.messageId
        isDeleted = record.kind.isDeleted
        text = isDeleted ? "" : record.text
    }

    func precedes(_ other: NovagramArchiveSortKey) -> Bool {
        if eventDate != other.eventDate {
            return eventDate > other.eventDate
        }
        if chatPeerId != other.chatPeerId {
            return chatPeerId > other.chatPeerId
        }
        if messageId != other.messageId {
            return messageId > other.messageId
        }
        if isDeleted != other.isDeleted {
            return isDeleted
        }
        return text < other.text
    }
}
