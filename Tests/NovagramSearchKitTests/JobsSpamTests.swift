import XCTest
@testable import NovagramSearchKit

final class JobsSpamTests: XCTestCase {
    func testSpamIsNotAJobPost() throws {
        XCTAssertEqual(NovagramJobPostParser.parse(cryptoSpam).kind, .unknown, "crypto spam is not a job post")
        XCTAssertTrue(!acceptedForJob(cryptoSpam), "crypto spam rejected for findJob query")
        XCTAssertTrue(!acceptedForJob(cryptoSpam, query: emptyQuery), "crypto spam rejected for empty query")
        XCTAssertEqual(NovagramJobPostParser.parse(chineseSpam).kind, .unknown, "CJK ad spam is not a job post")
        XCTAssertTrue(!acceptedForJob(chineseSpam), "CJK ad spam rejected")
        XCTAssertEqual(NovagramJobPostParser.parse(casinoSpam).kind, .unknown, "casino spam with нужен is not a vacancy")
        XCTAssertEqual(NovagramJobPostParser.parse(airdropSpam).kind, .unknown, "airdrop spam with apply is not a vacancy")
        XCTAssertEqual(NovagramJobPostParser.parse(bettingSpam).kind, .unknown, "betting spam is not a job post")
    }

    func testVacancyMarkers() throws {
        XCTAssertEqual(NovagramJobPostParser.parse("Crypto birjaga backend dasturchi kerak, #vakansiya, oylik 2000$").kind, .vacancy, "crypto company vacancy survives the spam guard")
        XCTAssertEqual(NovagramJobPostParser.parse("Bizning do'konga sotuvchi kerak. Maosh 4 mln so'm, Chilonzor. Tel 90 123 45 67").kind, .vacancy, "uz latin role kerak")
        XCTAssertTrue(acceptedForJob("iOS developer kerak, remote, tajriba 2 yil, @hr_company"), "uz latin iOS developer kerak accepted")
        XCTAssertEqual(NovagramJobPostParser.parse("Ofisga kerak: 2 nafar, ish vaqti 9-18").kind, .vacancy, "bare kerak with job word and office")
        XCTAssertEqual(NovagramJobPostParser.parse("Bugun havo yaxshi, soyabon kerak").kind, .unknown, "bare kerak without job signal stays unknown")
        XCTAssertEqual(NovagramJobPostParser.parse("Дастурчи керак, ойлик 10 млн сўм").kind, .vacancy, "uz cyrillic role керак")
        XCTAssertEqual(NovagramJobPostParser.parse("Нужен водитель на доставку, оплата ежедневно, +998 93 555 44 33").kind, .vacancy, "ru нужен")
        XCTAssertEqual(NovagramJobPostParser.parse("Приглашаем Android-разработчика, удалённо").kind, .vacancy, "ru приглашаем")
        XCTAssertEqual(NovagramJobPostParser.parse("Мы в поиске SMM-специалиста на позицию в Ташкенте").kind, .vacancy, "ru в поиске and на позицию")
        XCTAssertTrue(acceptedForJob("We’re looking for a Swift engineer to join our team. Apply via @talent_hr"), "en we're looking for accepted")
        XCTAssertEqual(NovagramJobPostParser.parse("Open role: Product designer (hybrid, Tashkent)").kind, .vacancy, "en open role")
        XCTAssertEqual(NovagramJobPostParser.parse("Python backend\nOylik: 1500$\nRemote\n@hr_python").kind, .vacancy, "salary, contact and format make a weak vacancy")
    }

    func testResumeMarkers() throws {
        let info4 = NovagramJobPostParser.parse(enResume)
        XCTAssertEqual(NovagramJobPostParser.parse("Ish kerak, 22 yosh, kompyuterni yaxshi bilaman").kind, .resume, "ish kerak is a resume")
        XCTAssertEqual(NovagramJobPostParser.parse("Нужна работа, опыт 3 года, удалённо").kind, .resume, "нужна работа is a resume")
        XCTAssertEqual(NovagramJobPostParser.parse("В поиске работы: frontend developer, 2 years").kind, .resume, "в поиске работы is a resume")
        XCTAssertEqual(NovagramJobPostParser.parse("Вы работаете на фрилансе и сейчас в поиске клиентов? Тогда стоит обратить внимание на этого бота").kind, .unknown, "в поиске клиентов is not a vacancy")
        XCTAssertEqual(NovagramJobPostParser.parse("Мы в поиске опытного продавца-консультанта, Ташкент").kind, .vacancy, "в поиске опытного продавца is a vacancy")
        XCTAssertTrue(NovagramJobFilter(mode: .findCandidates).accepts(text: enResume, info: info4, date: now, now: now, query: emptyQuery), "en resume accepted for findCandidates")
    }

    func testSpamGuardSourcesAndTexts() {
        XCTAssertTrue(NovagramJobSpamGuard.isSpamSource(title: "Crypto Signals", username: nil))
        XCTAssertTrue(NovagramJobSpamGuard.isSpamSource(title: "Daily picks", username: "bestpicks.com"))
        XCTAssertTrue(NovagramJobSpamGuard.isSpamSource(title: "NFT drops", username: nil))
        XCTAssertFalse(NovagramJobSpamGuard.isSpamSource(title: "IT Vakansiyalar", username: "it_jobs_uz"))
        XCTAssertTrue(NovagramJobSpamGuard.isSpamText("Buy BTC now"))
        XCTAssertFalse(NovagramJobSpamGuard.isSpamText("Crypto birjaga backend dasturchi kerak"))
    }

    func testChannelRelevance() {
        XCTAssertEqual(NovagramJobChannelRelevance.discoveryQueries(userQuery: " iOS ").prefix(3), ["iOS vakansiya", "iOS ish", "iOS вакансия"])
        XCTAssertEqual(NovagramJobChannelRelevance.discoveryQueries(userQuery: nil).count, min(NovagramJobPresets.channelDiscoveryQueries.count, NovagramJobChannelRelevance.maxDiscoveryQueries))
        XCTAssertTrue(NovagramJobChannelRelevance.hasJobSignal(title: "Toshkent Ish Bor", username: nil))
        XCTAssertTrue(NovagramJobChannelRelevance.hasJobSignal(title: "Uzbekistan", username: "uzjobs"))
        XCTAssertTrue(NovagramJobChannelRelevance.hasJobSignal(title: "IT HR club", username: nil))
        XCTAssertFalse(NovagramJobChannelRelevance.hasJobSignal(title: "Three friends", username: "chr_news"))
        XCTAssertTrue(NovagramJobChannelRelevance.hasJobSignal(title: "Ish e\u{2019}lonlari", username: nil))
    }
}
