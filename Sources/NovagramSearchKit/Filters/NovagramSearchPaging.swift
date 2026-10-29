import Foundation

/// Paging limits of the filtered Messages section.
public enum NovagramSearchPaging {
    /// Matches a load tries to reach.
    public static let filledResultCount = 20
    /// Pages read after the first one in one load.
    public static let extraPagesPerLoad = 5
    /// Loads started by themselves per query and filter while the list is short.
    public static let maxAutoLoads = 3
    /// Results of the translated section, one page.
    public static let translatedResultLimit = 20
}

/// Counts the matches of one load and decides whether the next page is read.
public struct NovagramFilledLoad<ID: Hashable> {
    /// Matches added since the load started.
    public private(set) var matched: Int
    /// Extra pages this load may still read.
    public private(set) var pagesLeft: Int

    private let target: Int
    private var seen: Set<ID>

    /// A load that continues after the already shown `previousIds`.
    public init(previousIds: Set<ID> = [], extraPages: Int = NovagramSearchPaging.extraPagesPerLoad, target: Int = NovagramSearchPaging.filledResultCount) {
        self.matched = 0
        self.pagesLeft = extraPages
        self.target = target
        self.seen = previousIds
    }

    /// Adds a merged page; returns true when the next page should be read.
    public mutating func add<Item>(page items: [Item], id: (Item) -> ID, completed: Bool, isKept: (Item) -> Bool) -> Bool {
        let added = items.filter { !seen.contains(id($0)) }
        matched += added.filter(isKept).count
        if pagesLeft == 0 || completed || matched >= target {
            return false
        }
        seen = Set(items.map(id))
        pagesLeft -= 1
        return true
    }
}

/// Asks for another load while the filtered list is short and the server has more.
public final class NovagramSearchAutoLoad: @unchecked Sendable {
    private struct State {
        var shown = 0
        var autoLoads = 0
        var pending = false
    }

    private let lock = NSLock()
    private let target: Int
    private let maxAutoLoads: Int
    private var state = State()

    /// An auto-loader with the shipped limits unless given.
    public init(target: Int = NovagramSearchPaging.filledResultCount, maxAutoLoads: Int = NovagramSearchPaging.maxAutoLoads) {
        self.target = target
        self.maxAutoLoads = maxAutoLoads
    }

    /// Call when a load starts; `fresh` resets the count for a new query or filter.
    public func startLoad(fresh: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if fresh {
            state = State()
        }
        state.pending = false
    }

    /// Call when a load ends with its match count.
    public func finishLoad(matched: Int, completed: Bool) {
        lock.lock()
        defer { lock.unlock() }
        state.shown += matched
        let isShort = state.shown < target
        state.pending = isShort && !completed && state.autoLoads < maxAutoLoads
    }

    /// True once per requested load; the caller then loads the next page.
    public func takeRequest() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard state.pending else {
            return false
        }
        state.pending = false
        state.autoLoads += 1
        return true
    }
}
