import Foundation

/// A saved global search query.
public struct NovagramSavedSearch: Equatable, Hashable {
    /// The trimmed query text.
    public let query: String
    /// True for a pinned query.
    public let isPinned: Bool

    /// A saved query.
    public init(query: String, isPinned: Bool) {
        self.query = query
        self.isPinned = isPinned
    }
}

/// Saved and pinned global search queries, one JSON entry per account in the `pro_messager` suite.
public final class NovagramSavedSearchStore: @unchecked Sendable {
    /// Recent queries kept per account; pinned ones have no limit.
    public static let recentLimit = 20
    /// Prefix of the per-account key, followed by the account peer id.
    public static let keyPrefix = "novagram_saved_searches_"
    /// Posted with the store after any change.
    public static let didChangeNotification = Notification.Name("NovagramSavedSearchesDidChange")

    /// The store of the `pro_messager` suite.
    public static let shared = NovagramSavedSearchStore(
        defaults: UserDefaults(suiteName: NovagramSearchSettings.suiteName) ?? .standard,
        settings: .shared
    )

    struct Stored: Codable, Equatable {
        var accountRecordId: Int64
        var pinned: [String]
        var recent: [String]
    }

    private let lock = NSLock()
    private let defaults: UserDefaults
    private let settings: NovagramSearchSettings
    private let notificationCenter: NotificationCenter
    private let recentLimit: Int
    private var knownAccounts: Set<Int64>?

    /// A store on `defaults`; `record` saves nothing while `settings` has search features off.
    public init(defaults: UserDefaults, settings: NovagramSearchSettings, notificationCenter: NotificationCenter = .default, recentLimit: Int = NovagramSavedSearchStore.recentLimit) {
        self.defaults = defaults
        self.settings = settings
        self.notificationCenter = notificationCenter
        self.recentLimit = recentLimit
    }

    /// The UserDefaults key of an account.
    public static func key(accountPeerId: Int64) -> String {
        return keyPrefix + "\(accountPeerId)"
    }

    /// Pinned queries first, newest first, then recent ones, newest first.
    public func list(accountPeerId: Int64) -> [NovagramSavedSearch] {
        lock.lock()
        let stored = load(accountPeerId)
        lock.unlock()
        guard let stored = stored else {
            return []
        }
        return stored.pinned.map { NovagramSavedSearch(query: $0, isPinned: true) } + stored.recent.map { NovagramSavedSearch(query: $0, isPinned: false) }
    }

    /// Saves a query a result was opened from; empty, already pinned or features-off queries change nothing.
    public func record(_ query: String?, accountPeerId: Int64, accountRecordId: Int64) {
        guard settings.isSearchFeaturesEnabled, let text = NovagramSavedSearchStore.trimmed(query) else {
            return
        }
        let limit = recentLimit
        update(accountPeerId, accountRecordId) { stored in
            guard !stored.pinned.contains(where: { NovagramSavedSearchStore.same($0, text) }) else {
                return
            }
            stored.recent.removeAll(where: { NovagramSavedSearchStore.same($0, text) })
            stored.recent.insert(text, at: 0)
            stored.recent = Array(stored.recent.prefix(limit))
        }
    }

    /// Pins a query, or moves it back to the top of the recent ones.
    public func setPinned(_ query: String, pinned: Bool, accountPeerId: Int64, accountRecordId: Int64) {
        guard let text = NovagramSavedSearchStore.trimmed(query) else {
            return
        }
        let limit = recentLimit
        update(accountPeerId, accountRecordId) { stored in
            stored.pinned.removeAll(where: { NovagramSavedSearchStore.same($0, text) })
            stored.recent.removeAll(where: { NovagramSavedSearchStore.same($0, text) })
            if pinned {
                stored.pinned.insert(text, at: 0)
            } else {
                stored.recent.insert(text, at: 0)
                stored.recent = Array(stored.recent.prefix(limit))
            }
        }
    }

    /// Removes a query from both lists.
    public func remove(_ query: String, accountPeerId: Int64, accountRecordId: Int64) {
        guard let text = NovagramSavedSearchStore.trimmed(query) else {
            return
        }
        update(accountPeerId, accountRecordId) { stored in
            stored.pinned.removeAll(where: { NovagramSavedSearchStore.same($0, text) })
            stored.recent.removeAll(where: { NovagramSavedSearchStore.same($0, text) })
        }
    }

    /// Removes every entry written for an account record.
    public func clear(accountRecordId: Int64) {
        lock.lock()
        let decoder = JSONDecoder()
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(NovagramSavedSearchStore.keyPrefix) {
            guard let data = value as? Data, let stored = try? decoder.decode(Stored.self, from: data) else {
                continue
            }
            if stored.accountRecordId == accountRecordId {
                defaults.removeObject(forKey: key)
            }
        }
        lock.unlock()
        notify()
    }

    /// Call with the signed-in account records on every change; records that left are cleared.
    public func syncSignedInAccounts(_ accountRecordIds: Set<Int64>) {
        lock.lock()
        let previous = knownAccounts ?? accountRecordIds
        knownAccounts = accountRecordIds
        lock.unlock()
        for accountRecordId in previous.subtracting(accountRecordIds) {
            clear(accountRecordId: accountRecordId)
        }
    }

    static func trimmed(_ query: String?) -> String? {
        let text = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    static func same(_ lhs: String, _ rhs: String) -> Bool {
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    private func load(_ accountPeerId: Int64) -> Stored? {
        guard let data = defaults.data(forKey: NovagramSavedSearchStore.key(accountPeerId: accountPeerId)) else {
            return nil
        }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private func update(_ accountPeerId: Int64, _ accountRecordId: Int64, _ change: (inout Stored) -> Void) {
        lock.lock()
        let current = load(accountPeerId)
        var stored = current ?? Stored(accountRecordId: accountRecordId, pinned: [], recent: [])
        stored.accountRecordId = accountRecordId
        change(&stored)
        let isNewEmpty = current == nil && stored.pinned.isEmpty && stored.recent.isEmpty
        guard stored != current, !isNewEmpty, let data = try? JSONEncoder().encode(stored) else {
            lock.unlock()
            return
        }
        defaults.set(data, forKey: NovagramSavedSearchStore.key(accountPeerId: accountPeerId))
        lock.unlock()
        notify()
    }

    private func notify() {
        notificationCenter.post(name: NovagramSavedSearchStore.didChangeNotification, object: self)
    }
}
