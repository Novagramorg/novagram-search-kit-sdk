import Foundation

/// How a query typed into a chat's search is handled.
public enum NovagramChatSearchMode: Equatable {
    case normal
    case plain(String)
    case phrase(String)
    case regex(String)
}

/// A parsed chat search query.
public struct NovagramChatSearchQuery: Equatable {
    /// The lowercase prefix of a regular expression query.
    public static let regexPrefix = "re:"
    /// Characters that may open a quoted phrase.
    public static let openingQuotes: Set<Character> = ["\"", "\u{201C}", "\u{201D}", "\u{201E}"]
    /// Characters that may close a quoted phrase.
    public static let closingQuotes: Set<Character> = ["\"", "\u{201C}", "\u{201D}"]
    /// The shortest quoted query, quotes included.
    public static let minimumQuotedLength = 3
    /// Options of every `re:` pattern.
    public static let regexOptions: NSRegularExpression.Options = [.caseInsensitive]

    /// The query as typed.
    public let typed: String
    /// What the query means.
    public let mode: NovagramChatSearchMode

    /// Parses `query`; with search features off every query is `.normal`.
    public init(_ query: String, isFeaturesEnabled: Bool = true) {
        self.typed = query
        self.mode = isFeaturesEnabled ? NovagramChatSearchQuery.parse(query) : .normal
    }

    /// The text sent to the server.
    public var serverQuery: String {
        switch mode {
        case .normal:
            return typed
        case let .plain(text):
            return text
        case let .phrase(phrase):
            return phrase
        case .regex:
            return ""
        }
    }

    /// True when the results are matched on the client.
    public var filtersMessages: Bool {
        switch mode {
        case .phrase, .regex:
            return true
        case .normal, .plain:
            return false
        }
    }

    /// Messages scanned at most, nil when unlimited.
    public func scanLimit(_ limits: NovagramChatSearchLimits = .standard) -> Int? {
        if case .regex = mode {
            return limits.maxScannedMessages
        }
        return nil
    }

    /// Messages per page: the scan page size for `re:`, else `requested`.
    public func pageSize(requested: Int32, limits: NovagramChatSearchLimits = .standard) -> Int32 {
        if case .regex = mode {
            return limits.regexPageSize
        }
        return requested
    }

    private static func parse(_ query: String) -> NovagramChatSearchMode {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(regexPrefix) {
            let pattern = String(trimmed.dropFirst(regexPrefix.count)).trimmingCharacters(in: .whitespaces)
            guard !pattern.isEmpty else {
                return .normal
            }
            guard (try? NSRegularExpression(pattern: pattern, options: regexOptions)) != nil else {
                return .plain(pattern)
            }
            return .regex(pattern)
        }
        guard trimmed.count >= minimumQuotedLength, let first = trimmed.first, let last = trimmed.last, openingQuotes.contains(first), closingQuotes.contains(last) else {
            return .normal
        }
        let phrase = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        return phrase.isEmpty ? .normal : .phrase(phrase)
    }
}
