import XCTest
@testable import NovagramSearchKit

final class SuperSearchTests: XCTestCase {
    private let now: Int32 = 1_800_000_000

    private func hit(_ id: Int32, date: Int32? = nil, text: String = "hello", source: NovagramSuperSearchSource = .myChats, title: String = "Chat", username: String? = nil, chatKind: NovagramSuperSearchChatKind = .group, mediaKind: NovagramSuperSearchMediaKind = .text) -> NovagramSuperSearchHit {
        return NovagramSuperSearchHit(id: NovagramSuperSearchHitId(peerId: 100, namespace: 0, id: id), date: date ?? now - id, text: text, source: source, chatTitle: title, chatUsername: username, chatKind: chatKind, mediaKind: mediaKind)
    }

    func testFilterDefaults() {
        let filter = NovagramSuperSearchFilter()
        XCTAssertEqual(filter.sources, Set(NovagramSuperSearchSource.allCases).subtracting([.globalPosts]), "every source but global posts")
        XCTAssertEqual(filter.period, .any)
        XCTAssertTrue(filter.chatKinds.isEmpty && filter.mediaKinds.isEmpty && filter.languages.isEmpty)
        XCTAssertFalse(filter.hideSpam, "spam filter is off by default")
        XCTAssertTrue(filter.isDefault)
        XCTAssertEqual(filter.activeFilterCount, 0)
        var changed = filter
        changed.sources.insert(.globalPosts)
        XCTAssertEqual(changed.activeFilterCount, 0, "sources are not counted")
        XCTAssertFalse(changed.isDefault)
        changed = NovagramSuperSearchFilter(period: .week, chatKinds: [.channel], mediaKinds: [.photo], hideSpam: true, languages: [.russian])
        XCTAssertEqual(changed.activeFilterCount, 5)
        XCTAssertNil(NovagramSuperSearchPeriod.any.minDate(now: now))
        XCTAssertEqual(NovagramSuperSearchPeriod.year.minDate(now: now), now - 365 * 86_400)
    }

    func testFilterCodable() throws {
        let filter = NovagramSuperSearchFilter(sources: [.myChats, .globalPosts], period: .month, chatKinds: [.bot, .privateChat], mediaKinds: [.voice], hideSpam: true, languages: [.uzCyrillic, .english])
        let decoded = try JSONDecoder().decode(NovagramSuperSearchFilter.self, from: JSONEncoder().encode(filter))
        XCTAssertEqual(decoded, filter, "round trip")
        let empty = try JSONDecoder().decode(NovagramSuperSearchFilter.self, from: Data("{}".utf8))
        XCTAssertEqual(empty, NovagramSuperSearchFilter(), "missing keys decode to defaults")
        let legacy = try JSONDecoder().decode(NovagramSuperSearchFilter.self, from: Data("{\"hideSpam\":true,\"period\":\"decade\"}".utf8))
        XCTAssertTrue(legacy.hideSpam)
        XCTAssertEqual(legacy.period, .any, "unknown period decodes to any")
        XCTAssertEqual(legacy.sources, NovagramSuperSearchFilter.defaultSources)
        let unknown = try JSONDecoder().decode(NovagramSuperSearchFilter.self, from: Data("{\"sources\":[\"myChats\",\"futureSource\"],\"mediaKinds\":[\"sticker\",\"photo\"],\"languages\":[\"de\",\"ru\"]}".utf8))
        XCTAssertEqual(unknown.sources, [.myChats], "unknown source is skipped")
        XCTAssertEqual(unknown.mediaKinds, [.photo])
        XCTAssertEqual(unknown.languages, [.russian])
    }

    func testPlanForPlainQuery() {
        let plan = NovagramSuperSearchPlan.make(raw: "ios developer", filter: NovagramSuperSearchFilter(), translations: [:])
        XCTAssertFalse(plan.isEmpty)
        XCTAssertEqual(plan.textQueries.first, "ios developer")
        XCTAssertLessThanOrEqual(plan.textQueries.count, NovagramSuperSearchPlan.maxTextQueries)
        XCTAssertEqual(plan.peerQuery, "ios developer")
        XCTAssertEqual(plan.hashtags, ["iosdeveloper", "ios", "developer"])
        XCTAssertEqual(plan.sources, [.myChats, .publicChats, .publicChannelPosts, .hashtagPosts, .archive], "global posts only on request")
        let withGlobal = NovagramSuperSearchPlan.make(raw: "ios developer", filter: NovagramSuperSearchFilter(sources: [.archive, .globalPosts]), translations: [:])
        XCTAssertEqual(withGlobal.sources, [.globalPosts, .archive], "enum order")
    }

    func testPlanForOperators() {
        let plan = NovagramSuperSearchPlan.make(raw: "#python -junior \"to'liq stavka\" | swift", filter: NovagramSuperSearchFilter(), translations: [:])
        let peerQuery = plan.peerQuery ?? ""
        XCTAssertFalse(peerQuery.contains("junior"), "excluded word is not in peer query")
        XCTAssertFalse(peerQuery.contains("stavka"), "quoted words are not in peer query")
        XCTAssertFalse(peerQuery.contains("#"))
        XCTAssertTrue(peerQuery.contains("python") && peerQuery.contains("swift"))
        XCTAssertEqual(plan.hashtags.first, "python", "explicit tag first")
        XCTAssertTrue(plan.hashtags.contains("swift"))
        XCTAssertFalse(plan.hashtags.contains("junior"))
        XCTAssertFalse(plan.textQueries.contains(where: { $0.contains("junior") }))
    }

    func testPlanHashtagCap() {
        let plan = NovagramSuperSearchPlan.make(raw: "#a #b #c #d alpha beta gamma delta", filter: NovagramSuperSearchFilter(), translations: [:])
        XCTAssertEqual(plan.hashtags.count, NovagramSuperSearchPlan.maxHashtags)
        XCTAssertEqual(Array(plan.hashtags.prefix(4)), ["a", "b", "c", "d"])
        let dupes = NovagramSuperSearchPlan.make(raw: "#Swift swift SWIFT", filter: NovagramSuperSearchFilter(), translations: [:])
        XCTAssertEqual(dupes.hashtags, ["swift"], "deduped case-insensitively")
    }

    func testPlanUzbekScriptVariant() {
        let plan = NovagramSuperSearchPlan.make(raw: "dasturchi kerak", filter: NovagramSuperSearchFilter(), translations: [:])
        XCTAssertTrue(plan.textQueries.contains("dasturchi kerak"))
        XCTAssertTrue(plan.textQueries.contains(where: { $0.contains(where: NovagramSearchText.isCyrillicLetter) }), "Cyrillic variant is added: \(plan.textQueries)")
    }

    func testEmptyPlan() {
        for raw in ["", "   ", "-junior"] {
            let plan = NovagramSuperSearchPlan.make(raw: raw, filter: NovagramSuperSearchFilter(), translations: [:])
            XCTAssertTrue(plan.isEmpty, "empty for '\(raw)'")
            XCTAssertTrue(plan.sources.isEmpty)
            XCTAssertTrue(plan.hashtags.isEmpty)
            XCTAssertNil(plan.peerQuery)
        }
    }

    func testTranslationsOnlyWithLanguages() {
        let translations: [NovagramSearchLanguage: String] = [.russian: "разработчик"]
        XCTAssertEqual(NovagramSuperSearchPlan.translationsNeeded(raw: "developer", filter: NovagramSuperSearchFilter()), [])
        let plain = NovagramSuperSearchPlan.make(raw: "developer", filter: NovagramSuperSearchFilter(), translations: translations)
        XCTAssertFalse(plain.textQueries.contains("разработчик"), "no translation without languages")
        let filter = NovagramSuperSearchFilter(languages: [.russian])
        XCTAssertEqual(NovagramSuperSearchPlan.translationsNeeded(raw: "developer", filter: filter), [.russian])
        let translated = NovagramSuperSearchPlan.make(raw: "developer", filter: filter, translations: translations)
        XCTAssertEqual(translated.textQueries.first, "developer")
        XCTAssertTrue(translated.textQueries.contains("разработчик"), "translation is a text variant")
        XCTAssertEqual(translated.peerQuery, "developer", "peer query stays as typed")
    }

    func testResultsDedupeAndOrder() {
        var results = NovagramSuperSearchResults()
        XCTAssertTrue(results.isEmpty)
        results.add([hit(1, source: .myChats), hit(2, source: .myChats)])
        results.add([hit(1, text: "other", source: .hashtagPosts), hit(3, source: .hashtagPosts)])
        XCTAssertEqual(results.all.count, 3)
        let first = NovagramSuperSearchHitId(peerId: 100, namespace: 0, id: 1)
        XCTAssertEqual(results.sources(of: first), [.myChats, .hashtagPosts])
        XCTAssertEqual(results.all.first(where: { $0.id == first })?.source, .myChats, "the first source keeps the hit")
        XCTAssertEqual(results.all.first(where: { $0.id == first })?.text, "hello")
        XCTAssertEqual(results.count(for: .myChats), 2)
        XCTAssertEqual(results.count(for: .hashtagPosts), 2)
        XCTAssertEqual(results.all.map { $0.id.id }, [1, 2, 3], "newest first")
        results.add([hit(9, date: now, source: .archive), hit(8, date: now, source: .archive)])
        XCTAssertEqual(results.all.map { $0.id.id }, [9, 8, 1, 2, 3], "same date: higher id first")
    }

    func testVisibleFilters() {
        var results = NovagramSuperSearchResults()
        let spam = hit(1, text: "Buy BTC now, airdrop", title: "Crypto Signals")
        let old = hit(2, date: now - 40 * 86_400, chatKind: .channel, mediaKind: .photo)
        let recent = hit(3, chatKind: .privateChat, mediaKind: .video)
        results.add([spam, old, recent])
        let all = NovagramSuperSearchFilter()
        XCTAssertEqual(results.visible(filter: all, now: now).count, 3, "nothing is cut by default")
        XCTAssertTrue(results.visible(filter: all, now: now).contains(spam), "spam is kept when hideSpam is off")
        XCTAssertFalse(results.visible(filter: NovagramSuperSearchFilter(hideSpam: true), now: now).contains(spam))
        XCTAssertEqual(results.visible(filter: NovagramSuperSearchFilter(period: .month), now: now).map { $0.id.id }, [1, 3])
        XCTAssertEqual(results.visible(filter: NovagramSuperSearchFilter(chatKinds: [.channel]), now: now).map { $0.id.id }, [2])
        XCTAssertEqual(results.visible(filter: NovagramSuperSearchFilter(mediaKinds: [.video, .photo]), now: now).map { $0.id.id }, [3, 2])
        XCTAssertTrue(results.visible(filter: NovagramSuperSearchFilter(sources: [.archive]), now: now).isEmpty, "hit whose only source is off is hidden")
    }

    func testVisibleWithSharedSourceAndRemoveAll() {
        var results = NovagramSuperSearchResults()
        results.add([hit(1, source: .myChats), hit(2, source: .myChats)])
        results.add([hit(1, source: .publicChannelPosts)])
        let visible = results.visible(filter: NovagramSuperSearchFilter(sources: [.publicChannelPosts]), now: now)
        XCTAssertEqual(visible.map { $0.id.id }, [1], "a shared hit stays while one of its sources is on")
        XCTAssertEqual(visible.first?.source, .publicChannelPosts)
        results.removeAll(from: .myChats)
        XCTAssertEqual(results.all.map { $0.id.id }, [1])
        XCTAssertEqual(results.all.first?.source, .publicChannelPosts, "the next source takes the hit")
        XCTAssertEqual(results.count(for: .myChats), 0)
        results.removeAll(from: .publicChannelPosts)
        XCTAssertTrue(results.isEmpty)
    }

    func testSpam() {
        XCTAssertTrue(NovagramSuperSearchSpam.isSpam(chatTitle: "Crypto Signals", chatUsername: nil, text: "hello"))
        XCTAssertTrue(NovagramSuperSearchSpam.isSpam(chatTitle: "News", chatUsername: nil, text: "BTC to the moon"))
        XCTAssertFalse(NovagramSuperSearchSpam.isSpam(chatTitle: "iOS Developers", chatUsername: "iosdev", text: "Swift meetup on Friday"))
    }
}
