import XCTest
@testable import NovagramSearchKit

final class CoreQueryTests: XCTestCase {
    func testNormalization() throws {
        XCTAssertEqual(NovagramSearchText.normalized("  Toshkentʻda   ISH\n bor "), "toshkent'da ish bor", "normalized folds case, apostrophes, whitespace")
        XCTAssertEqual(NovagramSearchText.normalized("Résumé O’QITUVCHI"), "resume o'qituvchi", "normalized folds diacritics")
    }

    func testTransliteration() throws {
        XCTAssertEqual(NovagramSearchTransliteration.uzbekLatinToCyrillic("Toshkent"), "Тошкент", "latin to cyrillic Toshkent")
        XCTAssertEqual(NovagramSearchTransliteration.uzbekLatinToCyrillic("o'qituvchi"), "ўқитувчи", "latin to cyrillic o'")
        XCTAssertEqual(NovagramSearchTransliteration.uzbekLatinToCyrillic("shahar"), "шаҳар", "latin to cyrillic sh and h")
        XCTAssertEqual(NovagramSearchTransliteration.uzbekLatinToCyrillic("g‘alaba"), "ғалаба", "latin to cyrillic g' with curly apostrophe")
        XCTAssertEqual(NovagramSearchTransliteration.uzbekLatinToCyrillic("ekspert yangi choy"), "эксперт янги чой", "latin to cyrillic word-initial e, ya, ch")
        XCTAssertEqual(NovagramSearchTransliteration.uzbekLatinToCyrillic("ta'lim"), "таълим", "latin to cyrillic tutuq belgisi")
        XCTAssertEqual(NovagramSearchTransliteration.uzbekCyrillicToLatin("Тошкент"), "Toshkent", "cyrillic to latin Toshkent")
        XCTAssertEqual(NovagramSearchTransliteration.uzbekCyrillicToLatin("ўқитувчи ғалаба"), "o'qituvchi g'alaba", "cyrillic to latin ў and ғ")
        XCTAssertEqual(NovagramSearchTransliteration.uzbekCyrillicToLatin("Ер юзи"), "Yer yuzi", "cyrillic to latin word-initial е")
        XCTAssertEqual(NovagramSearchTransliteration.uzbekCyrillicToLatin("ҳисобчи керак"), "hisobchi kerak", "cyrillic to latin ҳ and е")
    }

    func testOrAndScriptVariantServerQueries() throws {
        let orQuery = NovagramSearchQuery.parse("python yoki golang", expandScripts: false)
        XCTAssertEqual(orQuery.serverQueries, ["python", "golang"], "OR word splits branches")
        let pipeQuery = NovagramSearchQuery.parse("ios|android или flutter", expandScripts: false)
        XCTAssertEqual(pipeQuery.serverQueries, ["ios", "android", "flutter"], "pipe and или split branches")
        let expanded = NovagramSearchQuery.parse("dasturchi | менеджер")
        XCTAssertEqual(expanded.serverQueries, ["dasturchi", "менеджер", "дастурчи", "menedjer"], "script variants follow originals")
        let manyBranches = NovagramSearchQuery.parse("a1 | b2 | c3 | d4 | e5 | f6 | g7")
        XCTAssertEqual(manyBranches.serverQueries.count, NovagramSearchQuery.maxServerQueries, "server queries capped")
    }

    func testNotQuery() throws {
        let notQuery = NovagramSearchQuery.parse("iOS -junior")
        XCTAssertTrue(notQuery.matches("Senior iOS developer kerak"), "NOT query keeps text without excluded word")
        XCTAssertTrue(!notQuery.matches("Junior iOS developer kerak"), "NOT query rejects excluded word")
        XCTAssertEqual(NovagramSearchQuery.parse("-stajyor").serverQueries, [], "NOT-only query has no server query")
        XCTAssertTrue(NovagramSearchQuery.parse("-stajyor").isEmpty, "NOT-only query is empty for the server")
    }

    func testPhrasesAndWordStartMatching() throws {
        let phraseQuery = NovagramSearchQuery.parse("“ish haqi” toshkent")
        XCTAssertTrue(phraseQuery.matches("Ish haqi yuqori, Toshkentda ofis"), "phrase plus word-prefix term matches")
        XCTAssertTrue(!phraseQuery.matches("Toshkentda ish bor, haqi yaxshi"), "phrase must be contiguous")
        XCTAssertTrue(NovagramSearchQuery.parse("«ish bor»").matches("Bugun ISH   BOR!"), "guillemet phrase matches normalized text")
        XCTAssertTrue(NovagramSearchQuery.parse("toshkent").matches("Тошкентда офисга ҳисобчи керак"), "latin term matches cyrillic text")
        XCTAssertTrue(NovagramSearchQuery.parse("ҳисобчи").matches("Toshkentda hisobchi kerak"), "cyrillic term matches latin text")
        XCTAssertTrue(NovagramSearchQuery.parse("dasturchi").matches("Dasturchilar kerak"), "word prefix matches longer word")
        XCTAssertTrue(!NovagramSearchQuery.parse("dasturchi").matches("Yangidasturchilar"), "term must start at a word")
        XCTAssertTrue(NovagramSearchQuery.parse("").matches("anything"), "empty query matches everything")
    }

    func testHashtagTerms() throws {
        XCTAssertEqual(NovagramSearchQuery.parse("#ios developer").hashtagTerms, ["ios", "developer"], "explicit hashtag first")
        XCTAssertEqual(NovagramSearchQuery.parse("c# или java | 1c | python").hashtagTerms, ["c#", "java", "1c"], "role keyword hashtags capped at 3")
        XCTAssertEqual(NovagramSearchQuery.parse("\"o'qituvchi kerak\"").hashtagTerms, [], "phrases are not hashtags")
    }

    func testEquatableAndPublicInit() throws {
        XCTAssertEqual(NovagramSearchQuery.parse("swift"), NovagramSearchQuery.parse("swift"), "query is equatable")
        XCTAssertTrue(NovagramSearchQuery(raw: "swift -junior", serverQueries: ["swift"], hashtagTerms: []).matches("Senior Swift"), "public init compiles the matcher")
        XCTAssertTrue(!NovagramSearchQuery(raw: "swift -junior", serverQueries: ["swift"], hashtagTerms: []).matches("Junior Swift"), "public init compiles NOT terms")
    }

    func testLanguageDetection() throws {
        XCTAssertEqual(NovagramSearchLanguage.detect("dasturchi kerak toshkentda"), .uzLatin, "detect uz latin words")
        XCTAssertEqual(NovagramSearchLanguage.detect("o‘qituvchi"), .uzLatin, "detect uz latin apostrophe")
        XCTAssertEqual(NovagramSearchLanguage.detect("hisobchi"), .uzLatin, "detect uz latin suffix")
        XCTAssertEqual(NovagramSearchLanguage.detect("ҳисобчи"), .uzCyrillic, "detect uz cyrillic letters")
        XCTAssertEqual(NovagramSearchLanguage.detect("дастурчи"), .uzCyrillic, "detect uz cyrillic suffix")
        XCTAssertEqual(NovagramSearchLanguage.detect("менеджер по продажам"), .russian, "detect russian")
        XCTAssertEqual(NovagramSearchLanguage.detect("врачи"), .russian, "russian plural in -ачи stays russian")
        XCTAssertEqual(NovagramSearchLanguage.detect("python developer"), .english, "detect english")
        XCTAssertEqual(NovagramSearchLanguage.detect("限时优惠 苹果手机"), nil, "detect CJK as other")
        XCTAssertEqual(NovagramSearchLanguage.detect(""), nil, "detect empty as other")
        XCTAssertEqual(NovagramSearchLanguage.uzCyrillic.translationCode, "uz", "uz cyrillic translation code")
    }

    func testConversionPlan() throws {
        XCTAssertEqual(NovagramSearchConversion.plan(query: "dasturchi", languages: NovagramSearchLanguage.all), NovagramSearchConversionPlan(sourceLanguage: .uzLatin, transliterations: [.uzCyrillic: "дастурчи"], translationsNeeded: [.russian, .english]), "plan uz latin all languages")
        XCTAssertEqual(NovagramSearchConversion.plan(query: "dasturchi", languages: []), .empty, "plan None is empty")
        XCTAssertTrue(NovagramSearchConversion.plan(query: "dasturchi", languages: [.uzLatin]).isEmpty, "plan own language only is empty")
        XCTAssertEqual(NovagramSearchConversion.plan(query: "dasturchi", languages: [.russian]).translationsNeeded, [.russian], "plan uz latin to russian")
        XCTAssertEqual(NovagramSearchConversion.plan(query: "ҳисобчи", languages: NovagramSearchLanguage.all), NovagramSearchConversionPlan(sourceLanguage: .uzCyrillic, transliterations: [.uzLatin: "hisobchi"], translationsNeeded: [.russian, .english]), "plan uz cyrillic all languages")
        XCTAssertEqual(NovagramSearchConversion.plan(query: "менеджер", languages: NovagramSearchLanguage.all), NovagramSearchConversionPlan(sourceLanguage: .russian, transliterations: [:], translationsNeeded: [.uzLatin, .uzCyrillic, .english]), "plan russian all languages")
        XCTAssertEqual(NovagramSearchConversion.plan(query: "python", languages: NovagramSearchLanguage.all), NovagramSearchConversionPlan(sourceLanguage: .english, transliterations: [:], translationsNeeded: [.uzLatin, .uzCyrillic, .russian]), "plan never transliterates python")
        XCTAssertEqual(NovagramSearchConversion.plan(query: "python dasturchi", languages: [.uzCyrillic]).transliterations, [.uzCyrillic: "python дастурчи"], "mixed query keeps english word")
        XCTAssertEqual(NovagramSearchConversion.plan(query: "python", languages: [.uzCyrillic]).translationsNeeded, [.uzCyrillic], "english to uz cyrillic needs translation")
        XCTAssertTrue(NovagramSearchConversion.plan(query: "developer", languages: [.english]).isEmpty, "english to english is empty")
    }

    func testQueryWithLanguages() throws {
        XCTAssertEqual(NovagramSearchQuery.parse("python").serverQueries, ["python"], "expandScripts never adds python transliteration")
        XCTAssertEqual(NovagramSearchQuery.parse("python | dasturchi").serverQueries, ["python", "dasturchi", "дастурчи"], "expandScripts is uz scripts only")
        let convertedQuery = NovagramSearchQuery.parse("dasturchi -junior", languages: NovagramSearchLanguage.all, translations: [.russian: "программист", .english: "developer", .uzLatin: "dasturchi"])
        XCTAssertEqual(convertedQuery.serverQueries, ["dasturchi", "дастурчи", "программист", "developer"], "original, transliteration, translations order")
        XCTAssertTrue(convertedQuery.matches("Требуется программист в Ташкенте"), "translation is an OR alternative for matching")
        XCTAssertTrue(convertedQuery.matches("Senior developer kerak"), "english translation matches")
        XCTAssertTrue(!convertedQuery.matches("Junior developer kerak"), "raw NOT term applies to translations")
        XCTAssertEqual(NovagramSearchQuery.parse("python", languages: [], translations: [.russian: "питон"]).serverQueries, ["python"], "None searches the query as typed")
        let uzFromLatin = NovagramSearchQuery.parse("менеджер", languages: [.uzCyrillic], translations: [.uzLatin: "menejer"])
        XCTAssertEqual(uzFromLatin.serverQueries, ["менеджер", "менежер"], "uz cyrillic reached by translating to uz then transliterating")
        XCTAssertTrue(uzFromLatin.matches("Menejer kerak"), "converted variant matches across scripts")
        let cappedQuery = NovagramSearchQuery.parse("a1 | b2 | c3 | d4", languages: NovagramSearchLanguage.all, translations: [.russian: "р1 | р2", .uzLatin: "u1"])
        XCTAssertEqual(cappedQuery.serverQueries.count, NovagramSearchQuery.maxServerQueries, "converted server queries capped")
        XCTAssertEqual(cappedQuery.serverQueries.first, "a1", "original query first")
    }
}
