import Foundation

/// A source of monotonic time in seconds, injectable for tests.
public struct NovagramSearchClock {
    private let read: () -> TimeInterval

    /// A clock that returns `read()`.
    public init(_ read: @escaping () -> TimeInterval) {
        self.read = read
    }

    /// The system uptime clock.
    public static let system = NovagramSearchClock { ProcessInfo.processInfo.systemUptime }

    /// The current time in seconds.
    public var now: TimeInterval {
        return read()
    }
}
