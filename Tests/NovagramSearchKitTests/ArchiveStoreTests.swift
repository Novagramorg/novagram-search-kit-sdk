import XCTest
@testable import NovagramSearchKit

final class ArchiveStoreTests: XCTestCase {
    private var directory: TemporaryDirectory!
    private var now: Int32 = ArchiveFixtures.now

    override func setUp() {
        super.setUp()
        directory = TemporaryDirectory()
        now = ArchiveFixtures.now
    }

    override func tearDown() {
        directory.remove()
        super.tearDown()
    }

    private func makeStore(limits: NovagramArchiveLimits = NovagramArchiveLimits()) -> NovagramMessageArchiveStore {
        return NovagramMessageArchiveStore(directory: directory.url, limits: limits, now: { [unowned self] in self.now })
    }

    private var accountFile: URL {
        return makeStore().fileURL(accountRecordId: ArchiveFixtures.accountRecordId)
    }

    func testRecordCodableRoundTrip() throws {
        let records = [ArchiveFixtures.deleted(message: 1, text: "Salom"), ArchiveFixtures.edited(message: 2, text: "Привет")]
        let decoded = try JSONDecoder().decode([NovagramArchivedMessage].self, from: JSONEncoder().encode(records))
        XCTAssertEqual(decoded, records)
    }

    func testRoundTripThroughFile() {
        let store = makeStore()
        XCTAssertEqual(store.save([ArchiveFixtures.deleted(message: 1, text: "Birinchi"), ArchiveFixtures.edited(message: 2, text: "Ikkinchi")]), 2)
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.count(accountRecordId: ArchiveFixtures.accountRecordId), 2)
        XCTAssertEqual(Set(reloaded.index(accountRecordId: ArchiveFixtures.accountRecordId).records.map { $0.text }), ["Birinchi", "Ikkinchi"])
        XCTAssertEqual(reloaded.count(accountRecordId: ArchiveFixtures.otherAccountRecordId), 0)
    }

    func testFileHasVersionedHeader() throws {
        makeStore().save(ArchiveFixtures.deleted(message: 1, text: "Matn"))
        let firstLine = try String(contentsOf: accountFile, encoding: .utf8).components(separatedBy: "\n")[0]
        XCTAssertTrue(firstLine.contains("\"format\":\"novagram-message-archive\""))
        XCTAssertTrue(firstLine.contains("\"version\":1"))
    }

    func testNewerFormatIsNotReadOrOverwritten() throws {
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        let future = Data(#"{"format":"novagram-message-archive","version":2,"accountRecordId":77}"#.utf8 + [10])
        try future.write(to: accountFile)
        let store = makeStore()
        XCTAssertEqual(store.count(accountRecordId: ArchiveFixtures.accountRecordId), 0)
        store.save(ArchiveFixtures.deleted(message: 1, text: "Matn"))
        XCTAssertEqual(try Data(contentsOf: accountFile), future)
    }

    func testDeletedUpsertKeepsEarliestDeletionAndLatestText() {
        let store = makeStore()
        XCTAssertTrue(store.save(ArchiveFixtures.deleted(message: 5, text: "Eski", deletedAt: ArchiveFixtures.now - 100)))
        XCTAssertFalse(store.save(ArchiveFixtures.deleted(message: 5, text: "Eski", deletedAt: ArchiveFixtures.now - 100)))
        XCTAssertTrue(store.save(ArchiveFixtures.deleted(message: 5, text: "Yangi", deletedAt: ArchiveFixtures.now)))
        let records = makeStore().records(accountRecordId: ArchiveFixtures.accountRecordId, chatPeerId: 1001, messageId: 5)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.text, "Yangi")
        XCTAssertEqual(records.first?.kind, .deleted(deletedAt: ArchiveFixtures.now - 100))
    }

    func testEditVersionsAppendAndDedupeIdenticalText() {
        let store = makeStore()
        XCTAssertTrue(store.save(ArchiveFixtures.edited(message: 9, text: "v1", editDate: ArchiveFixtures.now - 20)))
        XCTAssertTrue(store.save(ArchiveFixtures.edited(message: 9, text: "v2", editDate: ArchiveFixtures.now - 10)))
        XCTAssertFalse(store.save(ArchiveFixtures.edited(message: 9, text: "v1", editDate: ArchiveFixtures.now)))
        XCTAssertTrue(store.save(ArchiveFixtures.deleted(message: 9, text: "v3")))
        let records = store.records(accountRecordId: ArchiveFixtures.accountRecordId, chatPeerId: 1001, messageId: 9)
        XCTAssertEqual(records.map { $0.text }, ["v1", "v2", "v3"])
    }

    func testPruneByCountKeepsNewest() {
        let store = makeStore(limits: NovagramArchiveLimits(maxRecordsPerAccount: 5))
        for message in 1...8 {
            store.save(ArchiveFixtures.deleted(message: Int32(message), text: "m\(message)", deletedAt: ArchiveFixtures.now - Int32(100 - message)))
        }
        XCTAssertEqual(store.count(accountRecordId: ArchiveFixtures.accountRecordId), 5)
        let reloaded = makeStore(limits: NovagramArchiveLimits(maxRecordsPerAccount: 5))
        XCTAssertEqual(reloaded.index(accountRecordId: ArchiveFixtures.accountRecordId).records.map { $0.messageId }, [8, 7, 6, 5, 4])
        store.save((9...48).map { ArchiveFixtures.deleted(message: Int32($0), text: "b\($0)", deletedAt: ArchiveFixtures.now) })
        XCTAssertEqual(store.count(accountRecordId: ArchiveFixtures.accountRecordId), 5)
    }

    func testPruneByAge() {
        let store = makeStore(limits: NovagramArchiveLimits(maxAge: 10 * ArchiveFixtures.day))
        XCTAssertFalse(store.save(ArchiveFixtures.deleted(message: 1, text: "Juda eski", deletedAt: ArchiveFixtures.now - 11 * ArchiveFixtures.day)))
        store.save(ArchiveFixtures.deleted(message: 2, text: "Eski", deletedAt: ArchiveFixtures.now - 9 * ArchiveFixtures.day))
        store.save(ArchiveFixtures.deleted(message: 3, text: "Yangi", deletedAt: ArchiveFixtures.now))
        XCTAssertEqual(store.count(accountRecordId: ArchiveFixtures.accountRecordId), 2)
        now += 2 * ArchiveFixtures.day
        store.prune(accountRecordId: ArchiveFixtures.accountRecordId)
        XCTAssertEqual(store.index(accountRecordId: ArchiveFixtures.accountRecordId).records.map { $0.messageId }, [3])
        now += 20 * ArchiveFixtures.day
        XCTAssertEqual(makeStore(limits: NovagramArchiveLimits(maxAge: 10 * ArchiveFixtures.day)).count(accountRecordId: ArchiveFixtures.accountRecordId), 0)
    }

    func testRemoveChatAndClearAccount() {
        let store = makeStore()
        store.save([ArchiveFixtures.deleted(chat: 1001, message: 1, text: "a"), ArchiveFixtures.deleted(chat: 2002, message: 1, text: "b")])
        store.save(ArchiveFixtures.deleted(message: 1, text: "c", account: ArchiveFixtures.otherAccountRecordId))
        store.remove(chatPeerId: 1001, accountRecordId: ArchiveFixtures.accountRecordId)
        XCTAssertEqual(makeStore().index(accountRecordId: ArchiveFixtures.accountRecordId).records.map { $0.chatPeerId }, [2002])
        store.clear(accountRecordId: ArchiveFixtures.accountRecordId)
        XCTAssertFalse(FileManager.default.fileExists(atPath: accountFile.path))
        XCTAssertEqual(store.count(accountRecordId: ArchiveFixtures.accountRecordId), 0)
        XCTAssertEqual(makeStore().count(accountRecordId: ArchiveFixtures.otherAccountRecordId), 1)
    }

    func testTornLastLineIsSkippedAndRepaired() throws {
        let store = makeStore()
        store.save(ArchiveFixtures.deleted(message: 1, text: "Butun"))
        store.save(ArchiveFixtures.deleted(message: 2, text: "Ikkinchi"))
        let handle = try FileHandle(forWritingTo: accountFile)
        handle.seekToEndOfFile()
        handle.write(Data(#"{"op":"put","record":{"a":1,"#.utf8))
        handle.closeFile()
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.count(accountRecordId: ArchiveFixtures.accountRecordId), 2)
        reloaded.save(ArchiveFixtures.deleted(message: 3, text: "Uchinchi"))
        XCTAssertEqual(makeStore().count(accountRecordId: ArchiveFixtures.accountRecordId), 3)
    }

    func testAppendedChangesAreCompacted() throws {
        let store = makeStore()
        for step in 0..<1_200 {
            store.save(ArchiveFixtures.deleted(message: 1, text: "matn \(step)"))
        }
        let lines = try String(contentsOf: accountFile, encoding: .utf8).split(separator: "\n")
        XCTAssertLessThan(lines.count, 1_100)
        XCTAssertEqual(makeStore().records(accountRecordId: ArchiveFixtures.accountRecordId, chatPeerId: 1001, messageId: 1).first?.text, "matn 1199")
    }

    func testConcurrentSaves() {
        let store = makeStore()
        DispatchQueue.concurrentPerform(iterations: 400) { message in
            store.save(ArchiveFixtures.deleted(message: Int32(message), text: "parallel \(message)"))
            _ = store.index(accountRecordId: ArchiveFixtures.accountRecordId)
        }
        XCTAssertEqual(store.count(accountRecordId: ArchiveFixtures.accountRecordId), 400)
        XCTAssertEqual(makeStore().count(accountRecordId: ArchiveFixtures.accountRecordId), 400)
    }

    func testMacLegacyImport() {
        let records = NovagramArchiveMacLegacyImport.records(from: ArchiveFixtures.macLegacyDefaults, accountPeerId: ArchiveFixtures.accountPeerId, accountRecordId: ArchiveFixtures.accountRecordId, includeChat: { $0 != 3003 })
        XCTAssertEqual(records.count, 3)
        let message10 = records.filter { $0.messageId == 10 }
        XCTAssertEqual(message10.map { $0.text }, ["Salom, test xabar", "Salom, test xabar 2"])
        XCTAssertEqual(message10.map { $0.kind }, [.edited(editDate: 1_799_990_100), .edited(editDate: 1_799_990_100)])
        XCTAssertEqual(message10.first?.date, 1_799_990_000)
        XCTAssertEqual(records.first(where: { $0.messageId == 7 })?.chatPeerId, -2002)
        XCTAssertEqual(NovagramArchiveMacLegacyImport.legacyKeys(in: ArchiveFixtures.macLegacyDefaults), ["msg_-2002_7", "msg_1001_10", "msg_3003_1", "msg_4004_2"])
        let store = makeStore()
        XCTAssertEqual(store.save(records), 3)
        XCTAssertEqual(store.save(records), 0)
    }

    func testEditedVersionsFromPlainHistory() {
        let versions = [NovagramArchiveVersion(text: "B", timestamp: 200), NovagramArchiveVersion(text: "A", timestamp: 100), NovagramArchiveVersion(text: "A", timestamp: 300)]
        let records = NovagramArchivedMessage.editedVersions(accountPeerId: 1, accountRecordId: 2, chatPeerId: 3, messageId: 4, threadId: 5, authorPeerId: 6, date: 100, previousVersions: versions, currentEditDate: 400)
        XCTAssertEqual(records.map { $0.text }, ["A", "B"])
        XCTAssertEqual(records.map { $0.kind }, [.edited(editDate: 200), .edited(editDate: 300)])
        XCTAssertEqual(records.first?.threadId, 5)
    }
}
