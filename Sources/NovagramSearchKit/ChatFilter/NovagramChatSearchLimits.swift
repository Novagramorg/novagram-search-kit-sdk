import Foundation

/// Limits of the exact phrase and `re:` search inside a chat.
public struct NovagramChatSearchLimits: Equatable {
    /// Messages requested per page by a `re:` scan.
    public var regexPageSize: Int32
    /// Messages a `re:` scan reads at most.
    public var maxScannedMessages: Int
    /// Pages read after the first one while a request adds too few matches.
    public var maxExtraPages: Int
    /// New matches a request should add before it stops reading pages.
    public var minimumNewMatches: Int
    /// Paging states remembered for "load more".
    public var cacheSize: Int
    /// Seconds one message may spend in the regular expression.
    public var regexTimeLimit: TimeInterval
    /// Seconds one page may spend in matching; after that the search counts as finished.
    public var pageTimeLimit: TimeInterval

    /// The shipped limits.
    public static let standard = NovagramChatSearchLimits()

    /// Limits with the shipped values unless given.
    public init(
        regexPageSize: Int32 = 100,
        maxScannedMessages: Int = 2000,
        maxExtraPages: Int = 5,
        minimumNewMatches: Int = 10,
        cacheSize: Int = 8,
        regexTimeLimit: TimeInterval = 0.05,
        pageTimeLimit: TimeInterval = 1
    ) {
        self.regexPageSize = regexPageSize
        self.maxScannedMessages = maxScannedMessages
        self.maxExtraPages = maxExtraPages
        self.minimumNewMatches = minimumNewMatches
        self.cacheSize = cacheSize
        self.regexTimeLimit = regexTimeLimit
        self.pageTimeLimit = pageTimeLimit
    }
}
