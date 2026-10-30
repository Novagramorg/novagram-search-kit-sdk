import XCTest
import NovagramSearchKit

final class TranslateTargetsTests: XCTestCase {
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

    func testKeyConstantsAndLimits() {
        XCTAssertEqual(NovagramSearchSettings.Keys.translateTargets, "novagram_search_translate_langs")
        XCTAssertEqual(NovagramSearchSettings.translateTargetCodes, ["uz-Latn", "uz-Cyrl", "ru", "en"])
        XCTAssertEqual(NovagramSearchSettings.maxServerTranslations, 3)
    }

    func testMissingKeyFollowsLegacyLanguageWithoutWriting() {
        let expectations: [(String?, [String])] = [("uz", ["uz-Latn"]), ("ru", ["ru"]), ("en", ["en"]), ("de", ["de"]), ("tr", ["tr"]), (nil, ["en"]), ("", ["en"])]
        for (legacy, expected) in expectations {
            if let legacy = legacy {
                isolated.defaults.set(legacy, forKey: "auto_translate_lang")
            } else {
                isolated.defaults.removeObject(forKey: "auto_translate_lang")
            }
            XCTAssertEqual(settings.translateTargets, expected, "legacy \(legacy ?? "none")")
            XCTAssertNil(isolated.defaults.object(forKey: "novagram_search_translate_langs"))
        }
    }

    func testStoredOrderIsKeptAndUnknownCodesDropped() {
        isolated.defaults.set("ru", forKey: "auto_translate_lang")
        isolated.defaults.set(["en", "xx", "uz-Cyrl", "de", "ru"], forKey: "novagram_search_translate_langs")
        XCTAssertEqual(settings.translateTargets, ["en", "uz-Cyrl", "ru"])
    }

    func testStoredEmptyArrayMeansNone() {
        isolated.defaults.set("uz", forKey: "auto_translate_lang")
        isolated.defaults.set([String](), forKey: "novagram_search_translate_langs")
        XCTAssertEqual(settings.translateTargets, [])
    }

    func testSetterFiltersDedupesAndPosts() {
        var posts = 0
        let token = center.addObserver(forName: NovagramSearchSettings.didChangeNotification, object: settings, queue: nil) { _ in
            posts += 1
        }
        settings.setTranslateTargets(["ru", "de", "uz-Latn", "ru", "en", "uz"])
        XCTAssertEqual(isolated.defaults.stringArray(forKey: "novagram_search_translate_langs"), ["ru", "uz-Latn", "en"])
        XCTAssertEqual(settings.translateTargets, ["ru", "uz-Latn", "en"])
        settings.setTranslateTargets([])
        XCTAssertEqual(isolated.defaults.stringArray(forKey: "novagram_search_translate_langs"), [])
        XCTAssertEqual(settings.translateTargets, [])
        center.removeObserver(token)
        XCTAssertEqual(posts, 2)
    }

    func testServerCodesMergeUzbekScripts() {
        XCTAssertEqual(NovagramSearchSettings.serverTranslationCodes(for: ["uz-Latn", "uz-Cyrl", "ru"]), ["uz", "ru"])
        XCTAssertEqual(NovagramSearchSettings.serverTranslationCodes(for: ["en", "uz-Cyrl", "en"]), ["en", "uz"])
        XCTAssertEqual(NovagramSearchSettings.serverTranslationCodes(for: []), [])
    }

    func testServerCodesCappedAtThree() {
        XCTAssertEqual(NovagramSearchSettings.serverTranslationCodes(for: ["ru", "en", "de", "tr"]), ["ru", "en", "de"])
        XCTAssertEqual(NovagramSearchSettings.serverTranslationCodes(for: ["uz-Latn", "uz-Cyrl", "ru", "en"]), ["uz", "ru", "en"])
    }
}
