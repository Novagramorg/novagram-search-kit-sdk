import Foundation

/// The last paging states of filtered chat searches, keyed by typed query and paging state.
public final class NovagramChatSearchProgressCache<State: Equatable, Value>: @unchecked Sendable {
    private struct Entry {
        let query: String
        let state: State
        let value: Value
    }

    private let lock = NSLock()
    private let capacity: Int
    private var entries: [Entry] = []

    /// A cache that keeps the newest `capacity` states.
    public init(capacity: Int = NovagramChatSearchLimits.standard.cacheSize) {
        self.capacity = max(1, capacity)
    }

    /// The value stored for `query` and `state`.
    public func value(query: String, state: State) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return entries.last(where: { $0.query == query && $0.state == state })?.value
    }

    /// Stores `value`, replacing the same key and dropping the oldest entries.
    public func store(_ value: Value, query: String, state: State) {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll(where: { $0.query == query && $0.state == state })
        entries.append(Entry(query: query, state: state, value: value))
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    /// The number of stored states.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}
