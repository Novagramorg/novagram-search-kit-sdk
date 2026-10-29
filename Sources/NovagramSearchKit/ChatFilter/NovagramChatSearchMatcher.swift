import Foundation

/// One filtered page of a chat search.
public struct NovagramChatSearchPage<Item, ID: Hashable> {
    /// Items that match, in page order.
    public let kept: [Item]
    /// Every decided item id and whether it matched.
    public let checked: [ID: Bool]
    /// True when the page time limit left items unchecked.
    public let timedOut: Bool
}

/// Matches message texts against a quoted phrase or a `re:` pattern.
public final class NovagramChatSearchMatcher: @unchecked Sendable {
    /// The parsed query.
    public let query: NovagramChatSearchQuery
    /// The limits in use.
    public let limits: NovagramChatSearchLimits

    private enum Rule {
        case phrase(String)
        case regex(NSRegularExpression)
    }

    private let rule: Rule
    private let clock: NovagramSearchClock

    /// A matcher for `query`, or nil when the query needs no client matching.
    public convenience init?(query: String, isFeaturesEnabled: Bool = true, limits: NovagramChatSearchLimits = .standard, clock: NovagramSearchClock = .system) {
        self.init(NovagramChatSearchQuery(query, isFeaturesEnabled: isFeaturesEnabled), limits: limits, clock: clock)
    }

    /// A matcher for a parsed query, or nil when it needs no client matching.
    public init?(_ query: NovagramChatSearchQuery, limits: NovagramChatSearchLimits = .standard, clock: NovagramSearchClock = .system) {
        switch query.mode {
        case let .phrase(phrase):
            self.rule = .phrase(phrase)
        case let .regex(pattern):
            guard let regex = try? NSRegularExpression(pattern: pattern, options: NovagramChatSearchQuery.regexOptions) else {
                return nil
            }
            self.rule = .regex(regex)
        case .normal, .plain:
            return nil
        }
        self.query = query
        self.limits = limits
        self.clock = clock
    }

    /// True when one message text matches.
    public func matches(_ text: String) -> Bool {
        switch rule {
        case let .phrase(phrase):
            return NovagramSearchText.contains(text, phrase: phrase)
        case let .regex(regex):
            return regexMatches(regex, in: text)
        }
    }

    /// Filters one merged page; returns nil when `isCancelled` turned true.
    public func filterPage<Item, ID: Hashable>(
        _ items: [Item],
        id: (Item) -> ID,
        text: (Item) -> String,
        checked: [ID: Bool] = [:],
        isCancelled: () -> Bool = { false }
    ) -> NovagramChatSearchPage<Item, ID>? {
        let deadline = clock.now + limits.pageTimeLimit
        var checked = checked
        var kept: [Item] = []
        var timedOut = false
        for item in items {
            if isCancelled() {
                return nil
            }
            let itemId = id(item)
            if let known = checked[itemId] {
                if known {
                    kept.append(item)
                }
                continue
            }
            guard clock.now < deadline else {
                timedOut = true
                continue
            }
            let hit = matches(text(item))
            checked[itemId] = hit
            if hit {
                kept.append(item)
            }
        }
        return NovagramChatSearchPage(kept: kept, checked: checked, timedOut: timedOut)
    }

    /// True when the search is done: server done, scan cap reached, page timed out or no progress.
    public func isFinished(serverCompleted: Bool, scannedCount: Int, timedOut: Bool, stateUnchanged: Bool) -> Bool {
        let capped = query.scanLimit(limits).map { scannedCount >= $0 } ?? false
        return serverCompleted || capped || timedOut || stateUnchanged
    }

    /// True when the next page should be read within the same request.
    public func shouldReadNextPage(matched: Int, previousMatched: Int, isFinished: Bool, extraPagesRead: Int) -> Bool {
        let isShort = matched - previousMatched < limits.minimumNewMatches
        return isShort && !isFinished && extraPagesRead < limits.maxExtraPages
    }

    private func regexMatches(_ regex: NSRegularExpression, in text: String) -> Bool {
        let deadline = clock.now + limits.regexTimeLimit
        let clock = self.clock
        var found = false
        regex.enumerateMatches(in: text, options: [.reportProgress], range: NSRange(text.startIndex..., in: text)) { match, _, stop in
            if match != nil {
                found = true
                stop.pointee = true
            } else if clock.now > deadline {
                stop.pointee = true
            }
        }
        return found
    }
}
