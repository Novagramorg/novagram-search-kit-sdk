import Foundation

/// Decision rules of the translated global search query; the network call stays in the apps.
public enum NovagramQueryTranslation {
    /// Shortest trimmed query that is translated.
    public static let minQueryLength = 3
    /// Seconds the translate request starts late, so typing cancels it.
    public static let debounceSeconds: TimeInterval = 0.6
    /// Cached translations before the cache is cleared.
    public static let maxCachedQueries = 200
    /// Query prefixes that are never translated (hashtags and cashtags).
    public static let skippedPrefixes = ["#", "$"]

    /// The query as it is translated and cached.
    public static func trimmed(_ query: String) -> String {
        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the query qualifies: 3+ characters, not a hashtag or cashtag.
    public static func shouldTranslate(_ query: String) -> Bool {
        let text = trimmed(query)
        guard text.count >= minQueryLength else {
            return false
        }
        return !skippedPrefixes.contains(where: { text.hasPrefix($0) })
    }

    /// True when both switches are on and the query qualifies.
    public static func shouldTranslate(_ query: String, settings: NovagramSearchSettings) -> Bool {
        return settings.isTranslateActive && shouldTranslate(query)
    }

    /// True when a translation is empty or equals the query ignoring case and whitespace.
    public static func isSame(_ translation: String, as query: String) -> Bool {
        let translated = normalized(translation)
        return translated.isEmpty || translated == normalized(query)
    }

    /// The trimmed translation for the section, or nil when there is no section.
    public static func sectionText(translation: String?, query: String) -> String? {
        let text = trimmed(translation ?? "")
        return isSame(text, as: query) ? nil : text
    }

    private static func normalized(_ text: String) -> String {
        return NovagramSearchText.collapsingWhitespace(text.lowercased())
    }
}

/// In-memory translations keyed by language and query, cleared when full.
public final class NovagramQueryTranslationCache: @unchecked Sendable {
    /// The cached answer for a query.
    public enum Lookup: Equatable {
        case miss
        case noSection
        case translation(String)
    }

    /// The cache both apps' search uses.
    public static let shared = NovagramQueryTranslationCache()

    private let lock = NSLock()
    private let capacity: Int
    private var entries: [String: String] = [:]

    /// A cache cleared after `capacity` entries.
    public init(capacity: Int = NovagramQueryTranslation.maxCachedQueries) {
        self.capacity = max(1, capacity)
    }

    /// The cached answer for `query` in `language`.
    public func lookup(query: String, language: String) -> Lookup {
        lock.lock()
        defer { lock.unlock() }
        guard let value = entries[NovagramQueryTranslationCache.key(query: query, language: language)] else {
            return .miss
        }
        return value.isEmpty ? .noSection : .translation(value)
    }

    /// Stores a translate answer and returns the section text, nil when there is no section.
    @discardableResult
    public func store(translation: String?, query: String, language: String) -> String? {
        let text = NovagramQueryTranslation.sectionText(translation: translation, query: query)
        lock.lock()
        defer { lock.unlock() }
        if entries.count >= capacity {
            entries.removeAll()
        }
        entries[NovagramQueryTranslationCache.key(query: query, language: language)] = text ?? ""
        return text
    }

    /// The number of cached queries.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    private static func key(query: String, language: String) -> String {
        return language + "\n" + NovagramQueryTranslation.trimmed(query)
    }
}
