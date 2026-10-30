import Foundation

/// Which archived kinds a search returns.
public struct NovagramArchiveKinds: OptionSet, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let edited = NovagramArchiveKinds(rawValue: 1 << 0)
    public static let deleted = NovagramArchiveKinds(rawValue: 1 << 1)
    public static let all: NovagramArchiveKinds = [.edited, .deleted]

    func contains(_ kind: NovagramArchivedMessageKind) -> Bool {
        return contains(kind.isDeleted ? .deleted : .edited)
    }
}

/// The position after the last result of a page; pass it back to get the next page.
public struct NovagramArchiveSearchCursor: Equatable {
    let key: NovagramArchiveSortKey
}

/// One archive search: the query, filters and page.
public struct NovagramArchiveSearchRequest {
    public static let defaultLimit = 50
    public static let maxLimit = 200

    public var query: NovagramSearchQuery
    public var kinds: NovagramArchiveKinds
    public var accountRecordId: Int64?
    public var chatPeerId: Int64?
    public var limit: Int
    public var cursor: NovagramArchiveSearchCursor?

    public init(query: NovagramSearchQuery, kinds: NovagramArchiveKinds = .all, accountRecordId: Int64? = nil, chatPeerId: Int64? = nil, limit: Int = NovagramArchiveSearchRequest.defaultLimit, cursor: NovagramArchiveSearchCursor? = nil) {
        self.query = query
        self.kinds = kinds
        self.accountRecordId = accountRecordId
        self.chatPeerId = chatPeerId
        self.limit = limit
        self.cursor = cursor
    }

    /// A request for a typed query; with `languages` the query also matches their transliterations.
    public init(rawQuery: String, languages: Set<NovagramSearchLanguage> = [], kinds: NovagramArchiveKinds = .all, accountRecordId: Int64? = nil, chatPeerId: Int64? = nil, limit: Int = NovagramArchiveSearchRequest.defaultLimit, cursor: NovagramArchiveSearchCursor? = nil) {
        let query = languages.isEmpty ? NovagramSearchQuery.parse(rawQuery) : NovagramSearchQuery.parse(rawQuery, languages: languages, translations: [:])
        self.init(query: query, kinds: kinds, accountRecordId: accountRecordId, chatPeerId: chatPeerId, limit: limit, cursor: cursor)
    }
}

/// One page of archive search results.
public struct NovagramArchiveSearchPage: Equatable {
    /// Matches, newest edit or deletion first.
    public let records: [NovagramArchivedMessage]
    /// Set when more matches follow.
    public let nextCursor: NovagramArchiveSearchCursor?
}

/// Search in edited versions and deleted messages. An empty query lists every record that passes the filters.
public enum NovagramArchiveSearch {
    /// Matches in `index`. `isChatExcluded` must return true for hidden and locked chats: their records are never returned.
    public static func search(_ request: NovagramArchiveSearchRequest, in index: NovagramArchiveIndex, isChatExcluded: (Int64) -> Bool) -> NovagramArchiveSearchPage {
        let limit = min(max(request.limit, 1), NovagramArchiveSearchRequest.maxLimit)
        let rows = index.rows
        let matchesEverything = request.query.matchesEverything
        var excludedChats: [Int64: Bool] = [:]
        var results: [NovagramArchivedMessage] = []
        var lastKey: NovagramArchiveSortKey?
        var hasMore = false
        var position = request.cursor.map { firstRow(after: $0.key, in: rows) } ?? 0
        while position < rows.count {
            let row = rows[position]
            position += 1
            let record = row.record
            if let chatPeerId = request.chatPeerId, record.chatPeerId != chatPeerId {
                continue
            }
            if let accountRecordId = request.accountRecordId, record.accountRecordId != accountRecordId {
                continue
            }
            guard request.kinds.contains(record.kind) else { continue }
            guard matchesEverything || request.query.matches(normalized: row.normalizedText) else { continue }
            let excluded: Bool
            if let cached = excludedChats[record.chatPeerId] {
                excluded = cached
            } else {
                excluded = isChatExcluded(record.chatPeerId)
                excludedChats[record.chatPeerId] = excluded
            }
            guard !excluded else { continue }
            if results.count == limit {
                hasMore = true
                break
            }
            results.append(record)
            lastKey = row.key
        }
        let nextCursor = hasMore ? lastKey.map(NovagramArchiveSearchCursor.init) : nil
        return NovagramArchiveSearchPage(records: results, nextCursor: nextCursor)
    }

    /// Matches in any records the app supplies, for example ones read from its database.
    public static func search(_ request: NovagramArchiveSearchRequest, in records: [NovagramArchivedMessage], isChatExcluded: (Int64) -> Bool) -> NovagramArchiveSearchPage {
        return search(request, in: NovagramArchiveIndex(records: records), isChatExcluded: isChatExcluded)
    }

    private static func firstRow(after key: NovagramArchiveSortKey, in rows: [NovagramArchiveIndex.Row]) -> Int {
        var low = 0
        var high = rows.count
        while low < high {
            let middle = (low + high) / 2
            if key.precedes(rows[middle].key) {
                high = middle
            } else {
                low = middle + 1
            }
        }
        return low
    }
}
