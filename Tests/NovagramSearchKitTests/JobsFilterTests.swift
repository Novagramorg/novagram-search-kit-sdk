import XCTest
@testable import NovagramSearchKit

final class JobsFilterTests: XCTestCase {
    func testFilterModesAndFields() throws {
        let info5 = NovagramJobPostParser.parse(uzResume)
        XCTAssertTrue(NovagramJobFilter(mode: .findJob).accepts(text: "x", info: vacancyInfo, date: now, now: now, query: emptyQuery), "findJob accepts vacancy")
        XCTAssertTrue(!NovagramJobFilter(mode: .findJob).accepts(text: "x", info: resumeInfo, date: now, now: now, query: emptyQuery), "findJob rejects resume")
        XCTAssertTrue(!NovagramJobFilter(mode: .findCandidates).accepts(text: "x", info: vacancyInfo, date: now, now: now, query: emptyQuery), "findCandidates rejects vacancy")
        XCTAssertTrue(!NovagramJobFilter(mode: .findCandidates).accepts(text: "x", info: NovagramJobPostInfo(), date: now, now: now, query: emptyQuery), "findCandidates rejects unknown")
        XCTAssertTrue(!NovagramJobFilter(mode: .findJob).accepts(text: "x", info: NovagramJobPostInfo(), date: now, now: now, query: emptyQuery), "findJob rejects unknown")
        XCTAssertTrue(NovagramJobFilter(mode: .findCandidates).accepts(text: "x", info: resumeInfo, date: now, now: now, query: emptyQuery), "findCandidates accepts resume")
        XCTAssertTrue(!NovagramJobFilter(period: .day).accepts(text: "x", info: vacancyInfo, date: now - 2 * 86_400, now: now, query: emptyQuery), "period rejects old post")
        XCTAssertTrue(!NovagramJobFilter(cityIds: ["samarkand"]).accepts(text: "x", info: vacancyInfo, date: now, now: now, query: emptyQuery), "city filter rejects other city")
        XCTAssertTrue(NovagramJobFilter(cityIds: ["samarkand"]).accepts(text: "x", info: NovagramJobPostInfo(kind: .vacancy), date: now, now: now, query: emptyQuery), "city filter keeps post without city")
        XCTAssertTrue(!NovagramJobFilter(formats: [.remote]).accepts(text: "x", info: vacancyInfo, date: now, now: now, query: emptyQuery), "format filter rejects office")
        XCTAssertTrue(!NovagramJobFilter(mode: .findCandidates, onlyWithSalary: true).accepts(text: "x", info: info5, date: now, now: now, query: emptyQuery), "onlyWithSalary rejects negotiable")
        XCTAssertTrue(NovagramJobFilter(onlyWithSalary: true).accepts(text: "x", info: vacancyInfo, date: now, now: now, query: emptyQuery), "onlyWithSalary keeps amount")
        XCTAssertTrue(!NovagramJobFilter().accepts(text: "Junior python", info: vacancyInfo, date: now, now: now, query: NovagramSearchQuery.parse("python -junior")), "filter applies query")
    }

    func testPresets() throws {
        XCTAssertTrue(NovagramJobPresets.hashtags(for: .findJob).count <= 8 && NovagramJobPresets.hashtags(for: .findJob).first == "vakansiya", "job hashtags")
        XCTAssertTrue(NovagramJobPresets.hashtags(for: .findCandidates).allSatisfy { !$0.hasPrefix("#") }, "hashtags without #")
        XCTAssertEqual(NovagramJobPresets.cities.count, 20, "20 cities")
        XCTAssertTrue(NovagramJobPresets.city(id: "bukhara")?.variants.contains("бухар") == true, "bukhara cyrillic stem")
        XCTAssertTrue((6...8).contains(NovagramJobPresets.channelDiscoveryQueries.count), "6-8 discovery queries")
    }

    func testFilterLanguagesAndLegacyJSON() throws {
        XCTAssertEqual(NovagramJobFilter().languages, NovagramSearchLanguage.all, "filter languages default all")
        let legacyFilter = try? JSONDecoder().decode(NovagramJobFilter.self, from: Data(legacyFilterJSON.utf8))
        XCTAssertEqual(legacyFilter?.languages, NovagramSearchLanguage.all, "stored filter without languages decodes all four")
        XCTAssertEqual(legacyFilter?.mode, .findCandidates, "stored filter keeps other fields")
        let noneFilter = NovagramJobFilter(languages: [])
        let noneData = try? JSONEncoder().encode(noneFilter)
        XCTAssertEqual(noneData.flatMap { try? JSONDecoder().decode(NovagramJobFilter.self, from: $0) }, noneFilter, "empty languages round trip")
    }
}
