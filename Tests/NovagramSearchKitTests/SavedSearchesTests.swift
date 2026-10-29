import XCTest
import NovagramSearchKit

final class SavedSearchesTests: XCTestCase {
    private struct AppStored: Codable, Equatable {
        var accountRecordId: Int64
        var pinned: [String]
        var recent: [String]
    }

    private let peer: Int64 = 777_000_123
    private let record: Int64 = -4_211_237_390_164_537_005
    private var isolated: IsolatedDefaults!
    private var center: NotificationCenter!
    private var settings: NovagramSearchSettings!
    private var store: NovagramSavedSearchStore!

    override func setUp() {
        super.setUp()
        isolated = IsolatedDefaults()
        center = NotificationCenter()
        settings = NovagramSearchSettings(defaults: isolated.defaults, notificationCenter: center)
        store = NovagramSavedSearchStore(defaults: isolated.defaults, settings: settings, notificationCenter: center)
    }

    override func tearDown() {
        isolated.tearDown()
        super.tearDown()
    }

    private func storedValue(_ accountPeerId: Int64) throws -> AppStored {
        let data = try XCTUnwrap(isolated.defaults.data(forKey: NovagramSavedSearchStore.key(accountPeerId: accountPeerId)))
        return try JSONDecoder().decode(AppStored.self, from: data)
    }

    func testKeyLayout() {
        XCTAssertEqual(NovagramSavedSearchStore.key(accountPeerId: 42), "novagram_saved_searches_42")
        XCTAssertEqual(NovagramSavedSearchStore.recentLimit, 20)
    }

    func testRecordTrimsIgnoresEmptyAndDedupesCaseInsensitively() {
        store.record("  Invoice  ", accountPeerId: peer, accountRecordId: record)
        store.record("   ", accountPeerId: peer, accountRecordId: record)
        store.record(nil, accountPeerId: peer, accountRecordId: record)
        store.record("report", accountPeerId: peer, accountRecordId: record)
        store.record("INVOICE", accountPeerId: peer, accountRecordId: record)
        XCTAssertEqual(store.list(accountPeerId: peer), [
            NovagramSavedSearch(query: "INVOICE", isPinned: false),
            NovagramSavedSearch(query: "report", isPinned: false)
        ])
    }

    func testRecentKeepsTwentyNewestAndPinnedHasNoLimit() {
        for index in 0..<25 {
            store.record("q\(index)", accountPeerId: peer, accountRecordId: record)
        }
        let recent = store.list(accountPeerId: peer)
        XCTAssertEqual(recent.count, 20)
        XCTAssertEqual(recent.first?.query, "q24")
        XCTAssertEqual(recent.last?.query, "q5")
        for index in 0..<25 {
            store.setPinned("p\(index)", pinned: true, accountPeerId: peer, accountRecordId: record)
        }
        XCTAssertEqual(store.list(accountPeerId: peer).filter { $0.isPinned }.count, 25)
    }

    func testPinUnpinAndRemove() {
        store.record("alpha", accountPeerId: peer, accountRecordId: record)
        store.record("beta", accountPeerId: peer, accountRecordId: record)
        store.setPinned("ALPHA", pinned: true, accountPeerId: peer, accountRecordId: record)
        XCTAssertEqual(store.list(accountPeerId: peer), [
            NovagramSavedSearch(query: "ALPHA", isPinned: true),
            NovagramSavedSearch(query: "beta", isPinned: false)
        ])
        store.record("alpha", accountPeerId: peer, accountRecordId: record)
        XCTAssertEqual(store.list(accountPeerId: peer).count, 2)
        store.setPinned("alpha", pinned: false, accountPeerId: peer, accountRecordId: record)
        XCTAssertEqual(store.list(accountPeerId: peer).first, NovagramSavedSearch(query: "alpha", isPinned: false))
        store.remove("Beta ", accountPeerId: peer, accountRecordId: record)
        XCTAssertEqual(store.list(accountPeerId: peer).map { $0.query }, ["alpha"])
    }

    func testClearRemovesOnlyThatAccountRecord() {
        store.record("mine", accountPeerId: peer, accountRecordId: record)
        store.record("other", accountPeerId: 5, accountRecordId: 9)
        store.clear(accountRecordId: record)
        XCTAssertEqual(store.list(accountPeerId: peer), [])
        XCTAssertEqual(store.list(accountPeerId: 5).map { $0.query }, ["other"])
    }

    func testSignedInAccountsSyncClearsLoggedOutRecords() {
        store.record("one", accountPeerId: 1, accountRecordId: 11)
        store.record("two", accountPeerId: 2, accountRecordId: 22)
        store.syncSignedInAccounts([11, 22])
        XCTAssertEqual(store.list(accountPeerId: 1).count, 1)
        store.syncSignedInAccounts([22])
        XCTAssertEqual(store.list(accountPeerId: 1), [])
        XCTAssertEqual(store.list(accountPeerId: 2).count, 1)
    }

    func testFeaturesOffSavesNothingAndKeepsStoredJSON() throws {
        store.record("kept", accountPeerId: peer, accountRecordId: record)
        let before = isolated.defaults.data(forKey: NovagramSavedSearchStore.key(accountPeerId: peer))
        settings.isSearchFeaturesEnabled = false
        store.record("new", accountPeerId: peer, accountRecordId: record)
        XCTAssertEqual(isolated.defaults.data(forKey: NovagramSavedSearchStore.key(accountPeerId: peer)), before)
        XCTAssertEqual(store.list(accountPeerId: peer).map { $0.query }, ["kept"])
    }

    func testChangesArePostedOnTheInjectedCenter() {
        var posts = 0
        let token = center.addObserver(forName: NovagramSavedSearchStore.didChangeNotification, object: store, queue: nil) { _ in
            posts += 1
        }
        store.record("a", accountPeerId: peer, accountRecordId: record)
        store.remove("missing", accountPeerId: 99, accountRecordId: record)
        store.clear(accountRecordId: record)
        center.removeObserver(token)
        XCTAssertEqual(posts, 2)
        XCTAssertNil(isolated.defaults.data(forKey: NovagramSavedSearchStore.key(accountPeerId: 99)))
    }

    func testReadsTheMacFormat() {
        let macJSON = #"{"accountRecordId":-4211237390164537005,"pinned":["Invoice"],"recent":["o'zbek tili","Daily report"]}"#
        isolated.defaults.set(Data(macJSON.utf8), forKey: "novagram_saved_searches_777000123")
        XCTAssertEqual(store.list(accountPeerId: peer), [
            NovagramSavedSearch(query: "Invoice", isPinned: true),
            NovagramSavedSearch(query: "o'zbek tili", isPinned: false),
            NovagramSavedSearch(query: "Daily report", isPinned: false)
        ])
        store.clear(accountRecordId: record)
        XCTAssertEqual(store.list(accountPeerId: peer), [])
    }

    func testReadsTheIOSFormat() {
        let iosJSON = #"{"recent":["hello \/ world"],"pinned":[],"accountRecordId":5}"#
        isolated.defaults.set(Data(iosJSON.utf8), forKey: "novagram_saved_searches_42")
        XCTAssertEqual(store.list(accountPeerId: 42), [NovagramSavedSearch(query: "hello / world", isPinned: false)])
    }

    func testWritesBytesTheAppsWrite() throws {
        store.setPinned("Invoice", pinned: true, accountPeerId: peer, accountRecordId: record)
        store.record("Daily report", accountPeerId: peer, accountRecordId: record)
        let written = try XCTUnwrap(isolated.defaults.data(forKey: NovagramSavedSearchStore.key(accountPeerId: peer)))
        let expected = try JSONEncoder().encode(AppStored(accountRecordId: record, pinned: ["Invoice"], recent: ["Daily report"]))
        XCTAssertEqual(written, expected)
        XCTAssertEqual(try storedValue(peer), AppStored(accountRecordId: record, pinned: ["Invoice"], recent: ["Daily report"]))
    }

    func testUnreadableEntryIsSkipped() {
        isolated.defaults.set(Data("not json".utf8), forKey: NovagramSavedSearchStore.key(accountPeerId: peer))
        XCTAssertEqual(store.list(accountPeerId: peer), [])
        store.clear(accountRecordId: record)
        XCTAssertNotNil(isolated.defaults.data(forKey: NovagramSavedSearchStore.key(accountPeerId: peer)))
    }
}
