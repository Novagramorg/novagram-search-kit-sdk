import Foundation

/// The identity of a super search result: one message.
public struct NovagramSuperSearchHitId: Hashable, Codable {
    public let peerId: Int64
    public let namespace: Int32
    public let id: Int32

    public init(peerId: Int64, namespace: Int32, id: Int32) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
    }

    static func isNewer(_ lhs: NovagramSuperSearchHitId, than rhs: NovagramSuperSearchHitId) -> Bool {
        if lhs.peerId != rhs.peerId {
            return lhs.peerId > rhs.peerId
        }
        if lhs.namespace != rhs.namespace {
            return lhs.namespace > rhs.namespace
        }
        return lhs.id > rhs.id
    }
}

/// One super search result.
public struct NovagramSuperSearchHit: Equatable {
    public let id: NovagramSuperSearchHitId
    public let date: Int32
    public let text: String
    public let source: NovagramSuperSearchSource
    public let chatTitle: String
    public let chatUsername: String?
    public let chatKind: NovagramSuperSearchChatKind
    public let mediaKind: NovagramSuperSearchMediaKind

    public init(id: NovagramSuperSearchHitId, date: Int32, text: String, source: NovagramSuperSearchSource, chatTitle: String, chatUsername: String?, chatKind: NovagramSuperSearchChatKind, mediaKind: NovagramSuperSearchMediaKind) {
        self.id = id
        self.date = date
        self.text = text
        self.source = source
        self.chatTitle = chatTitle
        self.chatUsername = chatUsername
        self.chatKind = chatKind
        self.mediaKind = mediaKind
    }

    func with(source: NovagramSuperSearchSource) -> NovagramSuperSearchHit {
        return NovagramSuperSearchHit(id: id, date: date, text: text, source: source, chatTitle: chatTitle, chatUsername: chatUsername, chatKind: chatKind, mediaKind: mediaKind)
    }
}

/// Super search results from every source, deduplicated by message.
public struct NovagramSuperSearchResults {
    private var hits: [NovagramSuperSearchHitId: NovagramSuperSearchHit] = [:]
    private var deliveredBy: [NovagramSuperSearchHitId: [NovagramSuperSearchSource]] = [:]

    public init() {
    }

    public var isEmpty: Bool {
        return hits.isEmpty
    }

    public mutating func add(_ newHits: [NovagramSuperSearchHit]) {
        for hit in newHits {
            if hits[hit.id] == nil {
                hits[hit.id] = hit
            }
            var sources = deliveredBy[hit.id] ?? []
            if !sources.contains(hit.source) {
                sources.append(hit.source)
            }
            deliveredBy[hit.id] = sources
        }
    }

    public func sources(of id: NovagramSuperSearchHitId) -> Set<NovagramSuperSearchSource> {
        return Set(deliveredBy[id] ?? [])
    }

    public var all: [NovagramSuperSearchHit] {
        return hits.values.sorted(by: NovagramSuperSearchResults.isNewer)
    }

    public func visible(filter: NovagramSuperSearchFilter, now: Int32) -> [NovagramSuperSearchHit] {
        let minDate = filter.period.minDate(now: now)
        return all.compactMap { hit -> NovagramSuperSearchHit? in
            guard let source = (deliveredBy[hit.id] ?? []).first(where: filter.sources.contains) else { return nil }
            if let minDate = minDate, hit.date < minDate {
                return nil
            }
            if !filter.chatKinds.isEmpty, !filter.chatKinds.contains(hit.chatKind) {
                return nil
            }
            if !filter.mediaKinds.isEmpty, !filter.mediaKinds.contains(hit.mediaKind) {
                return nil
            }
            if filter.hideSpam, NovagramSuperSearchSpam.isSpam(chatTitle: hit.chatTitle, chatUsername: hit.chatUsername, text: hit.text) {
                return nil
            }
            return hit.source == source ? hit : hit.with(source: source)
        }
    }

    public func count(for source: NovagramSuperSearchSource) -> Int {
        return deliveredBy.values.filter { $0.contains(source) }.count
    }

    public mutating func removeAll(from source: NovagramSuperSearchSource) {
        for (id, sources) in deliveredBy where sources.contains(source) {
            let remaining = sources.filter { $0 != source }
            if let first = remaining.first, let hit = hits[id] {
                deliveredBy[id] = remaining
                hits[id] = hit.source == source ? hit.with(source: first) : hit
            } else {
                deliveredBy[id] = nil
                hits[id] = nil
            }
        }
    }

    private static func isNewer(_ lhs: NovagramSuperSearchHit, _ rhs: NovagramSuperSearchHit) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date > rhs.date
        }
        return NovagramSuperSearchHitId.isNewer(lhs.id, than: rhs.id)
    }
}

/// The optional spam filter of super search: crypto, betting and promo chats and posts.
public enum NovagramSuperSearchSpam {
    public static func isSpam(chatTitle: String, chatUsername: String?, text: String) -> Bool {
        return NovagramJobSpamGuard.isSpamSource(title: chatTitle, username: chatUsername) || NovagramJobSpamGuard.isSpamText(text)
    }
}
