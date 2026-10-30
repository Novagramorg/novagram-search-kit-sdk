import XCTest
@testable import NovagramSearchKit

final class ArchiveSearchTests: XCTestCase {
    private let records: [NovagramArchivedMessage] = [
        ArchiveFixtures.deleted(chat: 1001, message: 1, text: "Ertaga soat 10 da uchrashamiz", deletedAt: ArchiveFixtures.now - 50),
        ArchiveFixtures.edited(chat: 1001, message: 2, text: "Эртага соат 11 да учрашамиз", editDate: ArchiveFixtures.now - 40),
        ArchiveFixtures.deleted(chat: 2002, message: 3, text: "Test hisobot tayyor", deletedAt: ArchiveFixtures.now - 30),
        ArchiveFixtures.edited(chat: 3003, message: 4, text: "Yashirin chatdagi uchrashuv", editDate: ArchiveFixtures.now - 20),
        ArchiveFixtures.deleted(chat: 1001, message: 5, text: "Boshqa account xabari", deletedAt: ArchiveFixtures.now - 10, account: ArchiveFixtures.otherAccountRecordId)
    ]

    private func search(_ request: NovagramArchiveSearchRequest, hidden: Set<Int64> = []) -> NovagramArchiveSearchPage {
        return NovagramArchiveSearch.search(request, in: records, isChatExcluded: { hidden.contains($0) })
    }

    func testLatinQueryFindsCyrillicAndBack() {
        XCTAssertEqual(search(NovagramArchiveSearchRequest(rawQuery: "uchrashamiz")).records.map { $0.messageId }, [2, 1])
        XCTAssertEqual(search(NovagramArchiveSearchRequest(rawQuery: "учрашамиз")).records.map { $0.messageId }, [2, 1])
        XCTAssertEqual(search(NovagramArchiveSearchRequest(rawQuery: "ERTAGA -11")).records.map { $0.messageId }, [1])
    }

    func testKindChatAndAccountFilters() {
        XCTAssertEqual(search(NovagramArchiveSearchRequest(rawQuery: "", kinds: .deleted)).records.map { $0.messageId }, [5, 3, 1])
        XCTAssertEqual(search(NovagramArchiveSearchRequest(rawQuery: "", kinds: .edited)).records.map { $0.messageId }, [4, 2])
        XCTAssertEqual(search(NovagramArchiveSearchRequest(rawQuery: "", chatPeerId: 1001)).records.map { $0.messageId }, [5, 2, 1])
        XCTAssertEqual(search(NovagramArchiveSearchRequest(rawQuery: "", accountRecordId: ArchiveFixtures.accountRecordId)).records.map { $0.messageId }, [4, 3, 2, 1])
    }

    func testExcludedChatsNeverAppear() {
        var asked: [Int64] = []
        let page = NovagramArchiveSearch.search(NovagramArchiveSearchRequest(rawQuery: "uchrash"), in: records, isChatExcluded: { chat in
            asked.append(chat)
            return chat == 3003
        })
        XCTAssertEqual(page.records.map { $0.messageId }, [2, 1])
        XCTAssertEqual(asked.sorted(), [1001, 3003])
        XCTAssertTrue(search(NovagramArchiveSearchRequest(rawQuery: "yashirin", chatPeerId: 3003), hidden: [3003]).records.isEmpty)
    }

    func testCursorPaging() {
        var collected: [Int32] = []
        var cursor: NovagramArchiveSearchCursor?
        var pages = 0
        repeat {
            let page = search(NovagramArchiveSearchRequest(rawQuery: "", limit: 2, cursor: cursor))
            collected += page.records.map { $0.messageId }
            cursor = page.nextCursor
            pages += 1
        } while cursor != nil && pages < 10
        XCTAssertEqual(collected, [5, 4, 3, 2, 1])
        XCTAssertEqual(pages, 3)
        XCTAssertNil(search(NovagramArchiveSearchRequest(rawQuery: "", limit: 5)).nextCursor)
    }

    func testCursorStaysValidWhenNewerRecordsArrive() {
        let first = search(NovagramArchiveSearchRequest(rawQuery: "", limit: 2))
        let newer = records + [ArchiveFixtures.deleted(chat: 1001, message: 6, text: "Yangi", deletedAt: ArchiveFixtures.now)]
        let second = NovagramArchiveSearch.search(NovagramArchiveSearchRequest(rawQuery: "", limit: 10, cursor: first.nextCursor), in: newer, isChatExcluded: { _ in false })
        XCTAssertEqual(second.records.map { $0.messageId }, [3, 2, 1])
    }

    func testStoreIndexIsSearchable() {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = NovagramMessageArchiveStore(directory: directory.url, now: { ArchiveFixtures.now })
        store.save(records)
        let index = store.index(accountRecordId: ArchiveFixtures.accountRecordId)
        let page = NovagramArchiveSearch.search(NovagramArchiveSearchRequest(rawQuery: "hisobot"), in: index, isChatExcluded: { _ in false })
        XCTAssertEqual(page.records.map { $0.messageId }, [3])
    }

    func testSearchOf20kRecordsIsFast() {
        let words = ["salom", "ertaga", "hisobot", "loyiha", "uchrashuv", "kod", "test", "reja", "dastur", "xabar", "привет", "отчёт"]
        var generated: [NovagramArchivedMessage] = []
        generated.reserveCapacity(20_000)
        for number in 0..<20_000 {
            let text = (0..<12).map { words[(number * 7 + $0 * 3) % words.count] }.joined(separator: " ") + " raqam \(number)"
            let chat = Int64(1000 + number % 300)
            let date = ArchiveFixtures.now - Int32(number)
            generated.append(number % 2 == 0 ? ArchiveFixtures.deleted(chat: chat, message: Int32(number), text: text, deletedAt: date) : ArchiveFixtures.edited(chat: chat, message: Int32(number), text: text, editDate: date))
        }
        let index = NovagramArchiveIndex(records: generated)
        XCTAssertEqual(index.count, 20_000)
        let requests = [
            NovagramArchiveSearchRequest(rawQuery: "yo'qolgan so'z"),
            NovagramArchiveSearchRequest(rawQuery: "otchyot -kod", kinds: .deleted),
            NovagramArchiveSearchRequest(rawQuery: "raqam 19999"),
            NovagramArchiveSearchRequest(rawQuery: "учрашув | reja", chatPeerId: 1005)
        ]
        for request in requests {
            let start = Date()
            let page = NovagramArchiveSearch.search(request, in: index, isChatExcluded: { $0 == 1010 })
            let elapsed = Date().timeIntervalSince(start)
            XCTAssertLessThan(elapsed, 0.2, "\(request.query.raw) took \(Int(elapsed * 1000)) ms")
            XCTAssertFalse(page.records.contains { $0.chatPeerId == 1010 })
        }
    }
}
