import Foundation

/// Where a super search looks for results.
public enum NovagramSuperSearchSource: String, CaseIterable, Codable {
    case myChats
    case publicChats
    case publicChannelPosts
    case hashtagPosts
    case globalPosts
    case archive
}

/// How old a super search result may be.
public enum NovagramSuperSearchPeriod: String, CaseIterable, Codable {
    case day
    case week
    case month
    case year
    case any

    public func minDate(now: Int32) -> Int32? {
        let day: Int32 = 24 * 60 * 60
        switch self {
        case .day:
            return now - day
        case .week:
            return now - 7 * day
        case .month:
            return now - 30 * day
        case .year:
            return now - 365 * day
        case .any:
            return nil
        }
    }
}

/// The kind of chat a super search result comes from.
public enum NovagramSuperSearchChatKind: String, CaseIterable, Codable {
    case privateChat
    case group
    case channel
    case bot
}

/// The content kind of a super search result.
public enum NovagramSuperSearchMediaKind: String, CaseIterable, Codable {
    case text
    case photo
    case video
    case file
    case link
    case voice
    case music
}

/// The super search filter. Every filter is off by default, stored as JSON.
public struct NovagramSuperSearchFilter: Equatable, Codable {
    public static let defaultSources: Set<NovagramSuperSearchSource> = Set(NovagramSuperSearchSource.allCases.filter { $0 != .globalPosts })

    public var sources: Set<NovagramSuperSearchSource>
    public var period: NovagramSuperSearchPeriod
    public var chatKinds: Set<NovagramSuperSearchChatKind>
    public var mediaKinds: Set<NovagramSuperSearchMediaKind>
    public var hideSpam: Bool
    public var languages: Set<NovagramSearchLanguage>

    public init(
        sources: Set<NovagramSuperSearchSource> = NovagramSuperSearchFilter.defaultSources,
        period: NovagramSuperSearchPeriod = .any,
        chatKinds: Set<NovagramSuperSearchChatKind> = [],
        mediaKinds: Set<NovagramSuperSearchMediaKind> = [],
        hideSpam: Bool = false,
        languages: Set<NovagramSearchLanguage> = []
    ) {
        self.sources = sources
        self.period = period
        self.chatKinds = chatKinds
        self.mediaKinds = mediaKinds
        self.hideSpam = hideSpam
        self.languages = languages
    }

    public var isDefault: Bool {
        return self == NovagramSuperSearchFilter()
    }

    public var activeFilterCount: Int {
        let active = [period != .any, !chatKinds.isEmpty, !mediaKinds.isEmpty, hideSpam, !languages.isEmpty]
        return active.filter { $0 }.count
    }

    private enum CodingKeys: String, CodingKey {
        case sources
        case period
        case chatKinds
        case mediaKinds
        case hideSpam
        case languages
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sources = NovagramSuperSearchFilter.decodeSet(container, .sources) ?? NovagramSuperSearchFilter.defaultSources
        self.period = (try? container.decodeIfPresent(String.self, forKey: .period)).flatMap { $0.flatMap(NovagramSuperSearchPeriod.init(rawValue:)) } ?? .any
        self.chatKinds = NovagramSuperSearchFilter.decodeSet(container, .chatKinds) ?? []
        self.mediaKinds = NovagramSuperSearchFilter.decodeSet(container, .mediaKinds) ?? []
        self.hideSpam = (try? container.decodeIfPresent(Bool.self, forKey: .hideSpam)).flatMap { $0 } ?? false
        self.languages = NovagramSuperSearchFilter.decodeSet(container, .languages) ?? []
    }

    private static func decodeSet<Value: RawRepresentable & Hashable>(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Set<Value>? where Value.RawValue == String {
        guard let raw = (try? container.decodeIfPresent([String].self, forKey: key)).flatMap({ $0 }) else { return nil }
        return Set(raw.compactMap(Value.init(rawValue:)))
    }
}
