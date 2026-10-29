import XCTest
import NovagramSearchKit

final class ChatFilterTests: XCTestCase {
    func testQuotedPhraseIsParsedAndSentWithoutQuotes() {
        let query = NovagramChatSearchQuery("  \"two words\" ")
        XCTAssertEqual(query.mode, .phrase("two words"))
        XCTAssertEqual(query.serverQuery, "two words")
        XCTAssertTrue(query.filtersMessages)
        XCTAssertNil(query.scanLimit())
        XCTAssertEqual(query.pageSize(requested: 50), 50)
    }

    func testCurlyQuotesOpenAndCloseAPhrase() {
        XCTAssertEqual(NovagramChatSearchQuery("\u{201C}o\u{2018}zbek tili\u{201D}").mode, .phrase("o\u{2018}zbek tili"))
        XCTAssertEqual(NovagramChatSearchQuery("\u{201E}Hallo Welt\u{201C}").mode, .phrase("Hallo Welt"))
    }

    func testShortOrEmptyQuotesStayNormal() {
        XCTAssertEqual(NovagramChatSearchQuery("\"\"").mode, .normal)
        XCTAssertEqual(NovagramChatSearchQuery("\"   \"").mode, .normal)
        XCTAssertEqual(NovagramChatSearchQuery("\"open only").mode, .normal)
    }

    func testLowercaseRegexPrefixScansHistory() {
        let query = NovagramChatSearchQuery("re: inv(oice)?\\s+\\d+")
        XCTAssertEqual(query.mode, .regex("inv(oice)?\\s+\\d+"))
        XCTAssertEqual(query.serverQuery, "")
        XCTAssertEqual(query.pageSize(requested: 50), 100)
        XCTAssertEqual(query.scanLimit(), 2000)
    }

    func testCapitalizedRePrefixStaysPlainSearch() {
        let query = NovagramChatSearchQuery("Re: invoice")
        XCTAssertEqual(query.mode, .normal)
        XCTAssertEqual(query.serverQuery, "Re: invoice")
        XCTAssertNil(NovagramChatSearchMatcher(query))
    }

    func testEmptyRegexPatternIsNormal() {
        XCTAssertEqual(NovagramChatSearchQuery("re:").mode, .normal)
        XCTAssertEqual(NovagramChatSearchQuery("re:   ").mode, .normal)
    }

    func testInvalidRegexFallsBackToPlainText() {
        let query = NovagramChatSearchQuery("re:[a-")
        XCTAssertEqual(query.mode, .plain("[a-"))
        XCTAssertEqual(query.serverQuery, "[a-")
        XCTAssertFalse(query.filtersMessages)
        XCTAssertNil(NovagramChatSearchMatcher(query))
    }

    func testFeaturesOffMakesEveryQueryNormal() {
        XCTAssertEqual(NovagramChatSearchQuery("\"two words\"", isFeaturesEnabled: false).mode, .normal)
        XCTAssertEqual(NovagramChatSearchQuery("re:\\d+", isFeaturesEnabled: false).serverQuery, "re:\\d+")
        XCTAssertNil(NovagramChatSearchMatcher(query: "re:\\d+", isFeaturesEnabled: false))
    }

    func testPhraseMatchingIgnoresCaseDiacriticsApostrophesAndSpaces() throws {
        let matcher = try XCTUnwrap(NovagramChatSearchMatcher(query: "\"two words\""))
        XCTAssertTrue(matcher.matches("We need TWO   words\nhere"))
        XCTAssertTrue(matcher.matches("Twó wörds"))
        XCTAssertFalse(matcher.matches("two-words"))
        XCTAssertFalse(matcher.matches("words two"))
        let uzbek = try XCTUnwrap(NovagramChatSearchMatcher(query: "\"o'zbek tili\""))
        XCTAssertTrue(uzbek.matches("Oʻzbek tili darsi"))
        XCTAssertTrue(uzbek.matches("O\u{2019}ZBEK TILI"))
    }

    func testRegexMatchingIsCaseInsensitive() throws {
        let matcher = try XCTUnwrap(NovagramChatSearchMatcher(query: "re:inv(oice)?\\s+\\d+"))
        XCTAssertTrue(matcher.matches("Paid INVOICE 42 today"))
        XCTAssertTrue(matcher.matches("inv 7"))
        XCTAssertFalse(matcher.matches("invoice number"))
    }

    func testSlowRegexStopsAtTheMessageTimeLimit() throws {
        let limits = NovagramChatSearchLimits(regexTimeLimit: 0.05)
        let matcher = try XCTUnwrap(NovagramChatSearchMatcher(query: "re:^(a+)+$", limits: limits))
        let text = String(repeating: "a", count: 32) + "!"
        let started = Date()
        XCTAssertFalse(matcher.matches(text))
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5)
    }

    func testInjectedClockStopsRegexAtFirstProgressReport() throws {
        let time = SteppingTime(step: 1)
        let matcher = try XCTUnwrap(NovagramChatSearchMatcher(query: "re:^(a+)+$", clock: time.clock))
        XCTAssertFalse(matcher.matches(String(repeating: "a", count: 40) + "!"))
    }

    func testPageTimeLimitSkipsTheRestAndReportsTimeout() throws {
        let time = SteppingTime(step: 0.4)
        let limits = NovagramChatSearchLimits(pageTimeLimit: 1)
        let matcher = try XCTUnwrap(NovagramChatSearchMatcher(query: "\"hit\"", limits: limits, clock: time.clock))
        let messages = (1...4).map { TestMessage(id: $0, text: "a hit \($0)") }
        let page = try XCTUnwrap(matcher.filterPage(messages, id: { $0.id }, text: { $0.text }))
        XCTAssertEqual(page.kept.map { $0.id }, [1, 2])
        XCTAssertEqual(page.checked.count, 2)
        XCTAssertTrue(page.timedOut)
    }

    func testCheckedMessagesAreNotMatchedAgain() throws {
        let matcher = try XCTUnwrap(NovagramChatSearchMatcher(query: "\"hit\""))
        let messages = [TestMessage(id: 1, text: "no"), TestMessage(id: 2, text: "hit"), TestMessage(id: 3, text: "miss")]
        let page = try XCTUnwrap(matcher.filterPage(messages, id: { $0.id }, text: { $0.text }, checked: [1: true]))
        XCTAssertEqual(page.kept.map { $0.id }, [1, 2])
        XCTAssertEqual(page.checked, [1: true, 2: true, 3: false])
        XCTAssertFalse(page.timedOut)
    }

    func testCancelledPageReturnsNil() throws {
        let matcher = try XCTUnwrap(NovagramChatSearchMatcher(query: "\"hit\""))
        XCTAssertNil(matcher.filterPage([TestMessage(id: 1, text: "hit")], id: { $0.id }, text: { $0.text }, isCancelled: { true }))
    }

    func testScanCapFinishesRegexSearchOnly() throws {
        let limits = NovagramChatSearchLimits(maxScannedMessages: 50)
        let regex = try XCTUnwrap(NovagramChatSearchMatcher(query: "re:x", limits: limits))
        XCTAssertTrue(regex.isFinished(serverCompleted: false, scannedCount: 50, timedOut: false, stateUnchanged: false))
        XCTAssertFalse(regex.isFinished(serverCompleted: false, scannedCount: 49, timedOut: false, stateUnchanged: false))
        XCTAssertTrue(regex.isFinished(serverCompleted: false, scannedCount: 1, timedOut: true, stateUnchanged: false))
        let phrase = try XCTUnwrap(NovagramChatSearchMatcher(query: "\"x y\"", limits: limits))
        XCTAssertFalse(phrase.isFinished(serverCompleted: false, scannedCount: 5000, timedOut: false, stateUnchanged: false))
        XCTAssertTrue(phrase.isFinished(serverCompleted: false, scannedCount: 10, timedOut: false, stateUnchanged: true))
    }

    func testExtraPagesStopAtLimitOrEnoughMatches() throws {
        let matcher = try XCTUnwrap(NovagramChatSearchMatcher(query: "re:x"))
        XCTAssertTrue(matcher.shouldReadNextPage(matched: 13, previousMatched: 4, isFinished: false, extraPagesRead: 0))
        XCTAssertFalse(matcher.shouldReadNextPage(matched: 14, previousMatched: 4, isFinished: false, extraPagesRead: 0))
        XCTAssertFalse(matcher.shouldReadNextPage(matched: 0, previousMatched: 0, isFinished: false, extraPagesRead: 5))
        XCTAssertFalse(matcher.shouldReadNextPage(matched: 0, previousMatched: 0, isFinished: true, extraPagesRead: 0))
    }

    func testStandardLimits() {
        let limits = NovagramChatSearchLimits.standard
        XCTAssertEqual(limits.regexPageSize, 100)
        XCTAssertEqual(limits.maxScannedMessages, 2000)
        XCTAssertEqual(limits.maxExtraPages, 5)
        XCTAssertEqual(limits.minimumNewMatches, 10)
        XCTAssertEqual(limits.cacheSize, 8)
        XCTAssertEqual(limits.regexTimeLimit, 0.05)
        XCTAssertEqual(limits.pageTimeLimit, 1)
    }

    func testProgressCacheKeysByQueryAndStateAndKeepsNewest() {
        let cache = NovagramChatSearchProgressCache<Int, String>(capacity: 2)
        cache.store("a", query: "re:x", state: 1)
        cache.store("b", query: "re:y", state: 1)
        XCTAssertEqual(cache.value(query: "re:x", state: 1), "a")
        XCTAssertEqual(cache.value(query: "re:y", state: 1), "b")
        cache.store("c", query: "re:x", state: 2)
        XCTAssertNil(cache.value(query: "re:x", state: 1))
        XCTAssertEqual(cache.count, 2)
    }

    func testNormalizedText() {
        XCTAssertEqual(NovagramSearchText.normalized("  Oʻzbek   Tíli\n"), "o'zbek tili")
        XCTAssertEqual(NovagramSearchText.unifyingApostrophes("it\u{2019}s `x\u{02BC}"), "it's 'x'")
        XCTAssertFalse(NovagramSearchText.contains("anything", phrase: "   "))
    }
}
