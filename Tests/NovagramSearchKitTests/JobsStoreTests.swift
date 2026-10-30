import XCTest
@testable import NovagramSearchKit

final class JobsStoreTests: XCTestCase {
    func testStore() throws {
        let suiteName = "novagram_job_checks_\(UUID().uuidString)"
        let previousDefaults = NovagramJobStore.defaults
        defer { NovagramJobStore.defaults = previousDefaults }
        if let suite = UserDefaults(suiteName: suiteName) {
            NovagramJobStore.defaults = suite
            var notifications = 0
            let observer = NotificationCenter.default.addObserver(forName: NovagramJobStore.didChangeNotification, object: nil, queue: nil) { _ in
                notifications += 1
            }
            let account = NovagramJobAccount(peerId: 111, recordId: 7)
            let otherAccount = NovagramJobAccount(peerId: 222, recordId: 8)
            let first = NovagramJobSavedSearch(id: "a", title: "iOS", filter: NovagramJobFilter(query: "ios"))
            let second = NovagramJobSavedSearch(id: "b", title: "Python", filter: NovagramJobFilter(query: "python"))
            NovagramJobStore.save(first, account: account)
            NovagramJobStore.save(second, account: account)
            XCTAssertEqual(NovagramJobStore.savedSearches(account: account).map { $0.id }, ["b", "a"], "saved searches newest first")
            var edited = first
            edited.alertsEnabled = true
            NovagramJobStore.save(edited, account: account)
            XCTAssertEqual(NovagramJobStore.savedSearches(account: account), [second, edited], "save replaces by id")
            for index in 0..<25 {
                NovagramJobStore.save(NovagramJobSavedSearch(id: "n\(index)", title: "n", filter: NovagramJobFilter()), account: account)
            }
            XCTAssertEqual(NovagramJobStore.savedSearches(account: account).count, 20, "saved searches capped")
            NovagramJobStore.remove(id: "n24", account: account)
            XCTAssertTrue(!NovagramJobStore.savedSearches(account: account).contains { $0.id == "n24" }, "remove saved search")
            NovagramJobStore.setWatched(5, watched: true, account: account)
            NovagramJobStore.setWatched(6, watched: true, account: account)
            NovagramJobStore.setWatched(5, watched: false, account: account)
            XCTAssertEqual(NovagramJobStore.watchedChannels(account: account), [6], "watched channels")
            let filter = NovagramJobFilter(mode: .findCandidates, query: "swift", cityIds: ["tashkent"], formats: [.remote], period: .month, onlyWithSalary: true)
            NovagramJobStore.setLastFilter(filter, account: account)
            XCTAssertEqual(NovagramJobStore.lastFilter(account: account), filter, "last filter round trip")
            NovagramJobStore.setLastFilter(NovagramJobFilter(), account: otherAccount)
            XCTAssertTrue(notifications >= 33, "notification after every write")
            NovagramJobStore.clear(accountRecordId: 7)
            XCTAssertEqual(NovagramJobStore.savedSearches(account: account), [], "clear removes account data")
            XCTAssertEqual(NovagramJobStore.lastFilter(account: otherAccount), NovagramJobFilter(), "clear keeps other accounts")
            NotificationCenter.default.removeObserver(observer)
            suite.removePersistentDomain(forName: suiteName)
        } else {
            XCTFail("throwaway defaults suite")
        }
    }
}
