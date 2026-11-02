import Foundation

/// What a super search sends to the server for one query.
public struct NovagramSuperSearchPlan: Equatable {
    public static let maxTextQueries = 5
    public static let maxHashtags = 5
    public static let maxChannelsToSearchInside = 10

    public let raw: String
    public let query: NovagramSearchQuery
    public let textQueries: [String]
    public let peerQuery: String?
    public let hashtags: [String]
    public let sources: [NovagramSuperSearchSource]

    public var isEmpty: Bool {
        return textQueries.isEmpty && peerQuery == nil && hashtags.isEmpty
    }

    public init(raw: String, query: NovagramSearchQuery, textQueries: [String], peerQuery: String?, hashtags: [String], sources: [NovagramSuperSearchSource]) {
        self.raw = raw
        self.query = query
        self.textQueries = textQueries
        self.peerQuery = peerQuery
        self.hashtags = hashtags
        self.sources = sources
    }

    public static func make(raw: String, filter: NovagramSuperSearchFilter, translations: [NovagramSearchLanguage: String]) -> NovagramSuperSearchPlan {
        let syntax = NovagramSearchQuerySyntax(raw)
        let base = NovagramSearchQuery.parse(raw)
        let query = filter.languages.isEmpty ? base : NovagramSearchQuery.parse(raw, languages: filter.languages, translations: translations)
        let textQueries = dedupedPrefix(base.serverQueries + query.serverQueries, limit: maxTextQueries, key: NovagramSearchText.normalized)
        let peerQuery = makePeerQuery(syntax)
        let hashtags = makeHashtags(syntax)
        let runnable = NovagramSuperSearchSource.allCases.filter { source in
            guard filter.sources.contains(source) else { return false }
            switch source {
            case .myChats, .globalPosts, .archive:
                return !textQueries.isEmpty
            case .publicChats:
                return peerQuery != nil
            case .publicChannelPosts:
                return peerQuery != nil && !textQueries.isEmpty
            case .hashtagPosts:
                return !hashtags.isEmpty
            }
        }
        return NovagramSuperSearchPlan(raw: raw, query: query, textQueries: textQueries, peerQuery: peerQuery, hashtags: hashtags, sources: runnable)
    }

    public static func translationsNeeded(raw: String, filter: NovagramSuperSearchFilter) -> [NovagramSearchLanguage] {
        guard !filter.languages.isEmpty else { return [] }
        return NovagramSearchConversion.plan(query: raw, languages: filter.languages).translationsNeeded
    }

    private static func makePeerQuery(_ syntax: NovagramSearchQuerySyntax) -> String? {
        var words = syntax.branches.flatMap { $0.terms.map { $0.text } }
        if words.isEmpty {
            words = syntax.branches.flatMap { $0.phrases }
        }
        let result = dedupedPrefix(words, limit: Int.max, key: { $0.lowercased() }).joined(separator: " ")
        return result.isEmpty ? nil : result
    }

    private static func makeHashtags(_ syntax: NovagramSearchQuerySyntax) -> [String] {
        let explicit = syntax.branches.flatMap { $0.terms.filter { $0.isHashtag }.map { hashtagText($0.text) } }
        let plainBranches = syntax.branches.map { dedupedPrefix($0.terms.filter { !$0.isHashtag }.map { hashtagText($0.text) }, limit: Int.max, key: { $0 }) }
        let joined = plainBranches.filter { (2...3).contains($0.count) }.map { $0.joined() }
        let words = plainBranches.flatMap { $0 }.filter { $0.filter { $0.isLetter }.count >= 3 }
        return dedupedPrefix((explicit + joined + words).filter { !$0.isEmpty }, limit: maxHashtags, key: { $0 })
    }

    private static func hashtagText(_ text: String) -> String {
        return String(text.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" })
    }

    private static func dedupedPrefix(_ values: [String], limit: Int, key: (String) -> String) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for value in values where result.count < limit {
            let valueKey = key(value)
            guard !valueKey.isEmpty, seen.insert(valueKey).inserted else { continue }
            result.append(value)
        }
        return result
    }
}
