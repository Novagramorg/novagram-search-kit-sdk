import XCTest
@testable import NovagramSearchKit

final class JobsPostParserTests: XCTestCase {
    func testUzbekLatinVacancy() throws {
        let info1 = NovagramJobPostParser.parse(uzLatinVacancy)
        XCTAssertEqual(info1.kind, .vacancy, "uz latin vacancy kind")
        XCTAssertEqual(info1.title, "Python dasturchi kerak", "uz latin vacancy title skips hashtag line")
        XCTAssertEqual(info1.salary?.min, 800, "uz latin salary min")
        XCTAssertEqual(info1.salary?.max, 1200, "uz latin salary max")
        XCTAssertEqual(info1.salary?.currency, .usd, "uz latin salary currency")
        XCTAssertEqual(info1.salary?.text, "800$ dan 1200$", "uz latin salary fragment")
        XCTAssertEqual(info1.cityIds, ["tashkent"], "uz latin city")
        XCTAssertEqual(info1.formats, [.office], "uz latin office format")
        XCTAssertEqual(info1.employment, [.fullTime], "uz latin full time")
        XCTAssertEqual(info1.experienceYears, 2, "uz latin experience")
        XCTAssertEqual(info1.contacts, [.phone("+998901234567"), .username("hr_example_uz")], "uz latin contacts")
    }

    func testRussianVacancy() throws {
        let info2 = NovagramJobPostParser.parse(ruVacancy)
        XCTAssertEqual(info2.kind, .vacancy, "ru vacancy kind")
        XCTAssertEqual(info2.title, "Требуется менеджер по продажам", "ru vacancy title")
        XCTAssertEqual(info2.salary, NovagramJobSalary(text: "от 5 000 000 до 8 000 000 сум", min: 5_000_000, max: 8_000_000, currency: .uzs), "ru salary range with от/до")
        XCTAssertEqual(info2.cityIds, ["tashkent"], "ru city with г.")
        XCTAssertEqual(info2.experienceYears, 1, "ru experience")
        XCTAssertEqual(info2.contacts, [.phone("+998935554433"), .email("hr@example.uz")], "ru contacts")
    }

    func testUzbekCyrillicVacancy() throws {
        let info3 = NovagramJobPostParser.parse(uzCyrillicVacancy)
        XCTAssertEqual(info3.kind, .vacancy, "uz cyrillic vacancy kind")
        XCTAssertEqual(info3.title, "Ҳисобчи керак", "uz cyrillic title")
        XCTAssertEqual(info3.cityIds, ["samarkand"], "uz cyrillic city declension")
        XCTAssertEqual(info3.employment, [.fullTime], "uz cyrillic full time")
        XCTAssertEqual(info3.salary?.min, 5_000_000, "multiplier propagates to range start")
        XCTAssertEqual(info3.salary?.max, 7_000_000, "multiplier on range end")
        XCTAssertEqual(info3.salary?.currency, .uzs, "сўм is uzs")
        XCTAssertEqual(info3.contacts, [.phone("+998912345678")], "local phone normalized")
    }

    func testEnglishResume() throws {
        let info4 = NovagramJobPostParser.parse(enResume)
        XCTAssertEqual(info4.kind, .resume, "en resume kind")
        XCTAssertEqual(info4.title, "Looking for a job: iOS developer", "en resume title")
        XCTAssertEqual(info4.experienceYears, 3, "en experience")
        XCTAssertEqual(info4.formats, [.remote, .hybrid], "en formats")
        XCTAssertEqual(info4.salary?.min, 1500, "$1500+ min")
        XCTAssertEqual(info4.salary?.max, nil, "$1500+ has no max")
        XCTAssertEqual(info4.contacts, [.username("dev_example"), .link("https://github.com/alidev")], "en contacts trim punctuation")
    }

    func testUzbekResume() throws {
        let info5 = NovagramJobPostParser.parse(uzResume)
        XCTAssertEqual(info5.kind, .resume, "uz resume kind")
        XCTAssertEqual(info5.cityIds, ["bukhara"], "Buxoroda is bukhara")
        XCTAssertEqual(info5.formats, [.remote], "masofadan is remote")
        XCTAssertEqual(info5.experienceYears, 2, "uz resume experience")
        XCTAssertEqual(info5.salary?.isNegotiable, true, "kelishilgan is negotiable")
        XCTAssertEqual(info5.salary?.min, nil, "negotiable salary has no amount")
        XCTAssertEqual(info5.contacts, [.phone("+998971112233")], "998 phone without plus")
    }

    func testRussianResume() throws {
        let info6 = NovagramJobPostParser.parse(ruResume)
        XCTAssertEqual(info6.kind, .resume, "ru resume kind")
        XCTAssertEqual(info6.cityIds, ["moscow"], "в Москве is moscow")
        XCTAssertEqual(info6.experienceYears, 5, "опыт 5 лет")
        XCTAssertEqual(info6.employment, [.fullTime], "полная занятость")
        XCTAssertEqual(info6.salary?.min, 80_000, "rub salary")
        XCTAssertEqual(info6.salary?.currency, .rub, "руб is rub")
        XCTAssertEqual(info6.contacts, [.phone("+79991234567")], "+7 phone")
    }

    func testKindAndFalseSalaries() throws {
        XCTAssertEqual(NovagramJobPostParser.parse("Sotuv menejeri kerak. Rezyumeni @example_hr_team ga yuboring").kind, .vacancy, "send-resume request counts as vacancy")
        XCTAssertEqual(NovagramJobPostParser.parse("Salom hammaga, yaxshi kun").kind, .unknown, "no markers is unknown")
        XCTAssertEqual(NovagramJobPostParser.parse("Maosh yaxshi.\nTel: +998 90 123 45 67").salary, nil, "phone is not a salary")
        XCTAssertEqual(NovagramJobPostParser.parse("Ish haqi 2026-yil 1-yanvardan oshadi").salary, nil, "year and date are not a salary")
        XCTAssertEqual(NovagramJobPostParser.parse("Maosh 15.11.2026 dan beriladi, tel 90 123 45 67").salary, nil, "date and local phone are not a salary")
    }

    func testSalaryFormats() throws {
        XCTAssertEqual(NovagramJobPostParser.parse("Kompaniya 2015 yildan beri ishlaydi. Oylik maosh 3 000 000 so'm").salary?.min, 3_000_000, "year skipped, so'm salary found")
        XCTAssertEqual(NovagramJobPostParser.parse("Oylik: 1 000 000 – 2 000 000 so‘m").salary, NovagramJobSalary(text: "1 000 000 – 2 000 000 so'm", min: 1_000_000, max: 2_000_000, currency: .uzs), "grouped range with dash")
        XCTAssertEqual(NovagramJobPostParser.parse("Зарплата 1500 у.е.").salary?.currency, .usd, "у.е. is usd")
        XCTAssertEqual(NovagramJobPostParser.parse("Salary: 2,500 EUR").salary?.min, 2500, "comma thousands")
        XCTAssertEqual(NovagramJobPostParser.parse("ЗП 150 тыс руб").salary?.min, 150_000, "тыс multiplier")
        XCTAssertEqual(NovagramJobPostParser.parse("oylik 1.5 mln").salary?.min, 1_500_000, "decimal mln without currency")
        XCTAssertEqual(NovagramJobPostParser.parse("maosh 1500").salary?.min, 1500, "bare number with salary word")
        XCTAssertEqual(NovagramJobPostParser.parse("до 2000$ в месяц").salary?.max, 2000, "до gives max only")
        XCTAssertEqual(NovagramJobPostParser.parse("Зарплата по договоренности").salary?.isNegotiable, true, "ru negotiable")
    }

    func testCitiesContactsExperienceAndTitle() throws {
        XCTAssertEqual(NovagramJobPostParser.parse("Офис в Ташкенте и Самарканде, в г. Фергане").cityIds, ["tashkent", "samarkand", "fergana"], "ru city declensions in order")
        XCTAssertEqual(NovagramJobPostParser.parse("Qo‘qon va Farg'onada filiallar, Toshkentda ham").cityIds, ["kokand", "fergana", "tashkent"], "uz latin cities with apostrophes")
        XCTAssertEqual(NovagramJobPostParser.parse("Email: info@example.com, @example_user_ok, t.me/novagram_jobs").contacts, [.email("info@example.com"), .username("example_user_ok"), .link("t.me/novagram_jobs")], "email, username, t.me link")
        XCTAssertEqual(NovagramJobPostParser.parse("2+ years iOS, 18 years old").experienceYears, 2, "2+ years")
        let longTitle = NovagramJobPostParser.parse("🔥🔥 " + String(repeating: "Juda uzun sarlavha ", count: 10)).title ?? ""
        XCTAssertTrue(longTitle.count <= NovagramJobPostParser.maxTitleLength && longTitle.hasPrefix("Juda"), "title stripped and clipped")
    }
}
