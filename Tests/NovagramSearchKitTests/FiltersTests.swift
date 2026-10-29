import XCTest
import NovagramSearchKit

final class FiltersTests: XCTestCase {
    private func calendar(_ identifier: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: identifier))
        return calendar
    }

    private func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, hour: Int = 12) throws -> Date {
        return try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    func testToDateCoversTheWholeDay() throws {
        let utc = try calendar("UTC")
        var state = NovagramSearchFilterState()
        state.setFromDay(try date(utc, 2026, 10, 1, hour: 15), calendar: utc)
        state.setToDay(try date(utc, 2026, 10, 1, hour: 9), calendar: utc)
        let from = try XCTUnwrap(state.minDate)
        let to = try XCTUnwrap(state.maxDate)
        XCTAssertEqual(from, Int32(try date(utc, 2026, 10, 1, hour: 0).timeIntervalSince1970))
        XCTAssertEqual(to - from, 86_399)
    }

    func testToDateFollowsCalendarDayOnDaylightSavingChange() throws {
        let berlin = try calendar("Europe/Berlin")
        let day = try date(berlin, 2026, 10, 25)
        XCTAssertEqual(NovagramSearchDay.end(of: day, calendar: berlin) - NovagramSearchDay.start(of: day, calendar: berlin), 25 * 3600 - 1)
    }

    func testActiveFlagsAndClearing() throws {
        var state = NovagramSearchFilterState()
        XCTAssertFalse(state.isActive)
        state.unreadOnly = true
        XCTAssertTrue(state.filtersMessages)
        XCTAssertFalse(state.hasDates)
        XCTAssertTrue(state.isActive)
        state.unreadOnly = false
        state.setToDay(Date(), calendar: try calendar("UTC"))
        XCTAssertTrue(state.hasDates)
        XCTAssertFalse(state.filtersMessages)
        state.clearDates()
        XCTAssertFalse(state.isActive)
    }

    func testFeaturesOffDisablesEveryFilter() {
        let state = NovagramSearchFilterState(minDate: 10, maxDate: 20, unreadOnly: true, mentionsOnly: true)
        XCTAssertFalse(state.effective(isFeaturesEnabled: false).isActive)
        XCTAssertEqual(state.effective(isFeaturesEnabled: true), state)
    }

    func testDateRangeIntersectsTypedDates() {
        let state = NovagramSearchFilterState(minDate: 200, maxDate: 400)
        XCTAssertTrue(state.dateRange(intersecting: 100, 500) == (200, 400))
        XCTAssertTrue(state.dateRange(intersecting: 300, 350) == (300, 350))
        XCTAssertTrue(state.dateRange(intersecting: nil, nil) == (200, 400))
        XCTAssertTrue(NovagramSearchFilterState().dateRange(intersecting: 100, nil) == (100, nil))
    }

    func testUnreadAndMentionRules() {
        let both = NovagramSearchFilterState(unreadOnly: true, mentionsOnly: true)
        XCTAssertTrue(both.keeps(isUnread: true, mentionsAccount: true))
        XCTAssertFalse(both.keeps(isUnread: true, mentionsAccount: false))
        XCTAssertFalse(both.keeps(isUnread: false, mentionsAccount: true))
        XCTAssertTrue(NovagramSearchFilterState().keeps(isUnread: false, mentionsAccount: false))
        XCTAssertTrue(NovagramSearchFilterState.isUnread(isIncoming: true, isRead: false))
        XCTAssertFalse(NovagramSearchFilterState.isUnread(isIncoming: true, isRead: nil))
        XCTAssertFalse(NovagramSearchFilterState.isUnread(isIncoming: false, isRead: false))
    }

    func testTitleParts() {
        XCTAssertEqual(NovagramSearchFilterState(minDate: 1, maxDate: 2, unreadOnly: true, mentionsOnly: true).titleParts, [.dates(from: 1, to: 2), .unreadOnly, .mentionsOnly])
        XCTAssertEqual(NovagramSearchFilterState(minDate: 1).titleParts, [.from(1)])
        XCTAssertEqual(NovagramSearchFilterState(maxDate: 2).titleParts, [.to(2)])
        XCTAssertEqual(NovagramSearchFilterState().titleParts, [])
    }

    func testDayString() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        XCTAssertEqual(NovagramSearchDay.string(0, timeZone: utc), "01.01.70")
    }

    func testPagingConstants() {
        XCTAssertEqual(NovagramSearchPaging.filledResultCount, 20)
        XCTAssertEqual(NovagramSearchPaging.extraPagesPerLoad, 5)
        XCTAssertEqual(NovagramSearchPaging.maxAutoLoads, 3)
    }

    func testFilledLoadCountsOnlyNewMatchesAndStopsAtTarget() {
        var load = NovagramFilledLoad<Int>(previousIds: Set(0..<10), target: 5)
        let isKept: (Int) -> Bool = { $0 % 2 == 0 }
        XCTAssertTrue(load.add(page: Array(0..<14), id: { $0 }, completed: false, isKept: isKept))
        XCTAssertEqual(load.matched, 2)
        XCTAssertEqual(load.pagesLeft, 4)
        XCTAssertFalse(load.add(page: Array(0..<20), id: { $0 }, completed: false, isKept: isKept))
        XCTAssertEqual(load.matched, 5)
    }

    func testFilledLoadStopsWhenServerIsDoneOrPagesRunOut() {
        var done = NovagramFilledLoad<Int>()
        XCTAssertFalse(done.add(page: [1], id: { $0 }, completed: true, isKept: { _ in false }))
        var short = NovagramFilledLoad<Int>(extraPages: 1)
        XCTAssertTrue(short.add(page: [1], id: { $0 }, completed: false, isKept: { _ in false }))
        XCTAssertFalse(short.add(page: [1, 2], id: { $0 }, completed: false, isKept: { _ in false }))
    }

    func testAutoLoadAsksAtMostThreeTimesWhileShort() {
        let autoLoad = NovagramSearchAutoLoad()
        autoLoad.startLoad(fresh: true)
        var requests = 0
        for _ in 0..<5 {
            autoLoad.finishLoad(matched: 1, completed: false)
            if autoLoad.takeRequest() {
                requests += 1
                autoLoad.startLoad(fresh: false)
            }
        }
        XCTAssertEqual(requests, 3)
        XCTAssertFalse(autoLoad.takeRequest())
    }

    func testAutoLoadStopsWhenFullOrCompleted() {
        let autoLoad = NovagramSearchAutoLoad()
        autoLoad.startLoad(fresh: true)
        autoLoad.finishLoad(matched: 20, completed: false)
        XCTAssertFalse(autoLoad.takeRequest())
        autoLoad.startLoad(fresh: true)
        autoLoad.finishLoad(matched: 2, completed: true)
        XCTAssertFalse(autoLoad.takeRequest())
    }
}
