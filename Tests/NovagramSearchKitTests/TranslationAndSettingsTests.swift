import XCTest
import NovagramSearchKit

final class TranslationAndSettingsTests: XCTestCase {
    private var isolated: IsolatedDefaults!
    private var center: NotificationCenter!
    private var settings: NovagramSearchSettings!

    override func setUp() {
        super.setUp()
        isolated = IsolatedDefaults()
        center = NotificationCenter()
        settings = NovagramSearchSettings(defaults: isolated.defaults, notificationCenter: center)
    }

    override func tearDown() {
        isolated.tearDown()
        super.tearDown()
    }

    func testSettingsDefaultsWhenKeysAreMissing() {
        XCTAssertTrue(settings.isSearchFeaturesEnabled)
        XCTAssertFalse(settings.isTranslateEnabled)
        XCTAssertFalse(settings.isTranslateActive)
        XCTAssertEqual(settings.translationLanguage, "en")
        isolated.defaults.set("", forKey: "auto_translate_lang")
        XCTAssertEqual(settings.translationLanguage, "en")
        isolated.defaults.set("uz", forKey: "auto_translate_lang")
        XCTAssertEqual(settings.translationLanguage, "uz")
    }

    func testSettingsKeysAndSlugs() {
        XCTAssertEqual(NovagramSearchSettings.suiteName, "pro_messager")
        XCTAssertEqual(NovagramSearchSettings.Keys.searchFeatures, "novagram_search_features")
        XCTAssertEqual(NovagramSearchSettings.Keys.searchTranslate, "novagram_search_translate")
        XCTAssertEqual(NovagramSearchSettings.DeepLinkSlug.searchFeatures, "search-features")
        XCTAssertEqual(NovagramSearchSettings.DeepLinkSlug.searchTranslate, "search-translate")
    }

    func testSettingsWriteBoolsAndPostChanges() {
        var posts = 0
        let token = center.addObserver(forName: NovagramSearchSettings.didChangeNotification, object: settings, queue: nil) { _ in
            posts += 1
        }
        settings.isSearchFeaturesEnabled = false
        settings.isTranslateEnabled = true
        center.removeObserver(token)
        XCTAssertEqual(isolated.defaults.object(forKey: "novagram_search_features") as? Bool, false)
        XCTAssertEqual(isolated.defaults.object(forKey: "novagram_search_translate") as? Bool, true)
        XCTAssertFalse(settings.isTranslateActive)
        XCTAssertEqual(posts, 2)
    }

    func testTranslationLengthAndPrefixRules() {
        XCTAssertFalse(NovagramQueryTranslation.shouldTranslate("ab"))
        XCTAssertFalse(NovagramQueryTranslation.shouldTranslate("  ab  "))
        XCTAssertTrue(NovagramQueryTranslation.shouldTranslate("  abc "))
        XCTAssertFalse(NovagramQueryTranslation.shouldTranslate("#news"))
        XCTAssertFalse(NovagramQueryTranslation.shouldTranslate(" $usd"))
    }

    func testTranslationNeedsBothSwitches() {
        XCTAssertFalse(NovagramQueryTranslation.shouldTranslate("salom", settings: settings))
        settings.isTranslateEnabled = true
        XCTAssertTrue(NovagramQueryTranslation.shouldTranslate("salom", settings: settings))
        settings.isSearchFeaturesEnabled = false
        XCTAssertFalse(NovagramQueryTranslation.shouldTranslate("salom", settings: settings))
    }

    func testNoSectionWhenTranslationEqualsQuery() {
        XCTAssertTrue(NovagramQueryTranslation.isSame("Hello   World", as: " hello world "))
        XCTAssertTrue(NovagramQueryTranslation.isSame("", as: "hello"))
        XCTAssertNil(NovagramQueryTranslation.sectionText(translation: nil, query: "hello"))
        XCTAssertNil(NovagramQueryTranslation.sectionText(translation: "HELLO", query: "hello"))
        XCTAssertEqual(NovagramQueryTranslation.sectionText(translation: " Salom dunyo ", query: "hello world"), "Salom dunyo")
    }

    func testTranslationConstants() {
        XCTAssertEqual(NovagramQueryTranslation.minQueryLength, 3)
        XCTAssertEqual(NovagramQueryTranslation.debounceSeconds, 0.6)
        XCTAssertEqual(NovagramQueryTranslation.maxCachedQueries, 200)
    }

    func testTranslationCacheLookupAndClearWhenFull() {
        let cache = NovagramQueryTranslationCache(capacity: 2)
        XCTAssertEqual(cache.lookup(query: "hello", language: "uz"), .miss)
        XCTAssertEqual(cache.store(translation: "salom", query: " hello ", language: "uz"), "salom")
        XCTAssertNil(cache.store(translation: "Hello", query: "hello", language: "en"))
        XCTAssertEqual(cache.lookup(query: "hello", language: "uz"), .translation("salom"))
        XCTAssertEqual(cache.lookup(query: "hello", language: "en"), .noSection)
        cache.store(translation: "privet", query: "hello", language: "ru")
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.lookup(query: "hello", language: "uz"), .miss)
    }
}
