import Foundation

/// One active filter shown after the Messages header title.
public enum NovagramSearchFilterTitlePart: Equatable {
    case dates(from: Int32, to: Int32)
    case from(Int32)
    case to(Int32)
    case unreadOnly
    case mentionsOnly
}

/// The Messages section filters of global search; nothing is persisted.
public struct NovagramSearchFilterState: Equatable, Hashable {
    /// Start of the first day, local time.
    public var minDate: Int32?
    /// Last second of the last day, local time.
    public var maxDate: Int32?
    /// Only incoming messages the chat has not read yet.
    public var unreadOnly: Bool
    /// Only messages that mention the account.
    public var mentionsOnly: Bool

    /// A state with the given filters, none by default.
    public init(minDate: Int32? = nil, maxDate: Int32? = nil, unreadOnly: Bool = false, mentionsOnly: Bool = false) {
        self.minDate = minDate
        self.maxDate = maxDate
        self.unreadOnly = unreadOnly
        self.mentionsOnly = mentionsOnly
    }

    /// True while a date is set.
    public var hasDates: Bool {
        return minDate != nil || maxDate != nil
    }

    /// True when messages are dropped on the client, so pages have to be filled up.
    public var filtersMessages: Bool {
        return unreadOnly || mentionsOnly
    }

    /// True while any filter is set.
    public var isActive: Bool {
        return hasDates || filtersMessages
    }

    /// This state, or no filters while search features are off.
    public func effective(isFeaturesEnabled: Bool) -> NovagramSearchFilterState {
        return isFeaturesEnabled ? self : NovagramSearchFilterState()
    }

    /// Sets "From" to the start of `day`, or clears it when nil.
    public mutating func setFromDay(_ day: Date?, calendar: Calendar = .current) {
        minDate = day.map { NovagramSearchDay.start(of: $0, calendar: calendar) }
    }

    /// Sets "To" to the last second of `day`, or clears it when nil.
    public mutating func setToDay(_ day: Date?, calendar: Calendar = .current) {
        maxDate = day.map { NovagramSearchDay.end(of: $0, calendar: calendar) }
    }

    /// Clears both dates.
    public mutating func clearDates() {
        minDate = nil
        maxDate = nil
    }

    /// The range sent to the server: the later start and the earlier end of this state and a typed range.
    public func dateRange(intersecting typedMinDate: Int32?, _ typedMaxDate: Int32?) -> (minDate: Int32?, maxDate: Int32?) {
        return (NovagramSearchFilterState.later(typedMinDate, minDate), NovagramSearchFilterState.earlier(typedMaxDate, maxDate))
    }

    /// True when a message passes "Unread only" and "Mentions only".
    public func keeps(isUnread: Bool, mentionsAccount: Bool) -> Bool {
        if unreadOnly && !isUnread {
            return false
        }
        if mentionsOnly && !mentionsAccount {
            return false
        }
        return true
    }

    /// True for an incoming message after the read index; a chat without a read state counts as read.
    public static func isUnread(isIncoming: Bool, isRead: Bool?) -> Bool {
        guard isIncoming, let isRead = isRead else {
            return false
        }
        return !isRead
    }

    /// The active filters for the header title, in display order.
    public var titleParts: [NovagramSearchFilterTitlePart] {
        var parts: [NovagramSearchFilterTitlePart] = []
        switch (minDate, maxDate) {
        case let (from?, to?):
            parts.append(.dates(from: from, to: to))
        case let (from?, nil):
            parts.append(.from(from))
        case let (nil, to?):
            parts.append(.to(to))
        case (nil, nil):
            break
        }
        if unreadOnly {
            parts.append(.unreadOnly)
        }
        if mentionsOnly {
            parts.append(.mentionsOnly)
        }
        return parts
    }

    private static func later(_ lhs: Int32?, _ rhs: Int32?) -> Int32? {
        guard let lhs = lhs else {
            return rhs
        }
        guard let rhs = rhs else {
            return lhs
        }
        return max(lhs, rhs)
    }

    private static func earlier(_ lhs: Int32?, _ rhs: Int32?) -> Int32? {
        guard let lhs = lhs else {
            return rhs
        }
        guard let rhs = rhs else {
            return lhs
        }
        return min(lhs, rhs)
    }
}

/// Day boundaries and the day label of the date filters.
public enum NovagramSearchDay {
    /// The header date format, e.g. `01.10.26`.
    public static let dayFormat = "dd.MM.yy"

    private static let secondsPerDay: TimeInterval = 24 * 60 * 60

    /// Unix time of the start of `date`'s day.
    public static func start(of date: Date, calendar: Calendar = .current) -> Int32 {
        return Int32(calendar.startOfDay(for: date).timeIntervalSince1970)
    }

    /// Unix time of the last second of `date`'s day, so the whole day is included.
    public static func end(of date: Date, calendar: Calendar = .current) -> Int32 {
        let start = calendar.startOfDay(for: date)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(secondsPerDay)
        return Int32(next.timeIntervalSince1970) - 1
    }

    /// `timestamp` as `dd.MM.yy` in `timeZone`.
    public static func string(_ timestamp: Int32, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dayFormat
        formatter.timeZone = timeZone
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}
