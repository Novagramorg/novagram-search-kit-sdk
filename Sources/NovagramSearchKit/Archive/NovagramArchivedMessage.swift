import Foundation

/// What happened to an archived message text.
public enum NovagramArchivedMessageKind: Equatable {
    /// A previous version of an edited message, replaced by an edit at `editDate` (unix seconds).
    case edited(editDate: Int32)
    /// The last known version of a deleted message, deleted at `deletedAt` (unix seconds).
    case deleted(deletedAt: Int32)

    /// The time of the edit or the deletion.
    public var eventDate: Int32 {
        switch self {
        case let .edited(editDate):
            return editDate
        case let .deleted(deletedAt):
            return deletedAt
        }
    }

    /// True for `.deleted`.
    public var isDeleted: Bool {
        if case .deleted = self {
            return true
        }
        return false
    }
}

/// One archived message text: a previous version of an edited message or a deleted message.
public struct NovagramArchivedMessage: Codable, Equatable {
    public let accountPeerId: Int64
    public let accountRecordId: Int64
    public let chatPeerId: Int64
    public let messageId: Int32
    public let threadId: Int64?
    public let authorPeerId: Int64?
    /// The send date of the message (unix seconds).
    public let date: Int32
    public let kind: NovagramArchivedMessageKind
    public let text: String

    public init(accountPeerId: Int64, accountRecordId: Int64, chatPeerId: Int64, messageId: Int32, threadId: Int64? = nil, authorPeerId: Int64? = nil, date: Int32, kind: NovagramArchivedMessageKind, text: String) {
        self.accountPeerId = accountPeerId
        self.accountRecordId = accountRecordId
        self.chatPeerId = chatPeerId
        self.messageId = messageId
        self.threadId = threadId
        self.authorPeerId = authorPeerId
        self.date = date
        self.kind = kind
        self.text = text
    }

    /// Edited records for the previous versions of one message, as both apps keep them: each version with the
    /// time it was written (the send date for the first one). A version is replaced at the next version's time;
    /// the last one at `currentEditDate`, or at its own time when that is unknown. Identical texts are kept once.
    public static func editedVersions(accountPeerId: Int64, accountRecordId: Int64, chatPeerId: Int64, messageId: Int32, threadId: Int64? = nil, authorPeerId: Int64? = nil, date: Int32, previousVersions: [NovagramArchiveVersion], currentEditDate: Int32?) -> [NovagramArchivedMessage] {
        let versions = previousVersions.enumerated().sorted { lhs, rhs in
            lhs.element.timestamp == rhs.element.timestamp ? lhs.offset < rhs.offset : lhs.element.timestamp < rhs.element.timestamp
        }.map { $0.element }
        var seen = Set<String>()
        var result: [NovagramArchivedMessage] = []
        for (index, version) in versions.enumerated() {
            guard seen.insert(version.text).inserted else { continue }
            let replacedAt = index + 1 < versions.count ? versions[index + 1].timestamp : (currentEditDate ?? version.timestamp)
            result.append(NovagramArchivedMessage(accountPeerId: accountPeerId, accountRecordId: accountRecordId, chatPeerId: chatPeerId, messageId: messageId, threadId: threadId, authorPeerId: authorPeerId, date: date, kind: .edited(editDate: replacedAt), text: version.text))
        }
        return result
    }

    struct Identity: Hashable {
        let chatPeerId: Int64
        let messageId: Int32
        let isDeleted: Bool
        let text: String
    }

    var identity: Identity {
        let isDeleted = kind.isDeleted
        return Identity(chatPeerId: chatPeerId, messageId: messageId, isDeleted: isDeleted, text: isDeleted ? "" : text)
    }

    private enum CodingKeys: String, CodingKey {
        case accountPeerId = "a"
        case accountRecordId = "r"
        case chatPeerId = "c"
        case messageId = "m"
        case threadId = "th"
        case authorPeerId = "au"
        case date = "d"
        case kind = "k"
        case eventDate = "e"
        case text = "t"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountPeerId = try container.decode(Int64.self, forKey: .accountPeerId)
        accountRecordId = try container.decode(Int64.self, forKey: .accountRecordId)
        chatPeerId = try container.decode(Int64.self, forKey: .chatPeerId)
        messageId = try container.decode(Int32.self, forKey: .messageId)
        threadId = try container.decodeIfPresent(Int64.self, forKey: .threadId)
        authorPeerId = try container.decodeIfPresent(Int64.self, forKey: .authorPeerId)
        date = try container.decode(Int32.self, forKey: .date)
        text = try container.decode(String.self, forKey: .text)
        let eventDate = try container.decode(Int32.self, forKey: .eventDate)
        switch try container.decode(String.self, forKey: .kind) {
        case "e":
            kind = .edited(editDate: eventDate)
        case "d":
            kind = .deleted(deletedAt: eventDate)
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown archive kind")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountPeerId, forKey: .accountPeerId)
        try container.encode(accountRecordId, forKey: .accountRecordId)
        try container.encode(chatPeerId, forKey: .chatPeerId)
        try container.encode(messageId, forKey: .messageId)
        try container.encodeIfPresent(threadId, forKey: .threadId)
        try container.encodeIfPresent(authorPeerId, forKey: .authorPeerId)
        try container.encode(date, forKey: .date)
        try container.encode(kind.isDeleted ? "d" : "e", forKey: .kind)
        try container.encode(kind.eventDate, forKey: .eventDate)
        try container.encode(text, forKey: .text)
    }
}

/// A previous message version as the apps keep it: its text and the time it was written.
public struct NovagramArchiveVersion: Equatable {
    public let text: String
    public let timestamp: Int32

    public init(text: String, timestamp: Int32) {
        self.text = text
        self.timestamp = timestamp
    }
}
