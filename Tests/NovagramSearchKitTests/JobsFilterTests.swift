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

    func testCustomHashtags() throws {
        var filter = NovagramJobFilter()
        XCTAssertEqual(filter.hashtags(for: .findJob), NovagramJobPresets.hashtags(for: .findJob), "job hashtags default to presets")
        XCTAssertFalse(filter.hasCustomHashtags(for: .findJob), "presets are not custom")
        let legacy = try JSONDecoder().decode(NovagramJobFilter.self, from: Data("{\"mode\":\"findJob\",\"query\":\"ios\"}".utf8))
        XCTAssertNil(legacy.jobHashtags, "decoding without the key gives nil")
        XCTAssertNil(legacy.candidateHashtags, "decoding without the key gives nil")
        filter.setHashtags(["#python", " swift ", "PYTHON", "bad-tag", String(repeating: "a", count: 33)], for: .findJob)
        XCTAssertEqual(filter.hashtags(for: .findJob), ["python", "swift"], "custom hashtags are cleaned and deduplicated")
        XCTAssertEqual(filter.hashtags(for: .findCandidates), NovagramJobPresets.hashtags(for: .findCandidates), "the other mode keeps presets")
        XCTAssertTrue(filter.hasCustomHashtags(for: .findJob), "changed list is custom")
        filter.setHashtags((0..<20).map { "tag\($0)" }, for: .findCandidates)
        XCTAssertEqual(filter.hashtags(for: .findCandidates).count, NovagramJobFilter.maxHashtags, "list is capped at 12")
        filter.setHashtags([], for: .findJob)
        XCTAssertTrue(filter.hashtags(for: .findJob).isEmpty, "empty custom list stays empty")
        let decoded = try JSONDecoder().decode(NovagramJobFilter.self, from: JSONEncoder().encode(filter))
        XCTAssertEqual(decoded, filter, "custom hashtags survive encoding")
        filter.setHashtags(nil, for: .findJob)
        XCTAssertEqual(filter.hashtags(for: .findJob), NovagramJobPresets.hashtags(for: .findJob), "nil resets to presets")
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
