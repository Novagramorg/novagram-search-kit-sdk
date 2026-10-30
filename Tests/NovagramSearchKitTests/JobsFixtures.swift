import Foundation
@testable import NovagramSearchKit

let uzLatinVacancy = """
📢 #vakansiya
🏢 Python dasturchi kerak
📍 Manzil: Toshkent shahri, Chilonzor tumani
💰 Maosh: 800$ dan 1200$ gacha
🕘 Ish vaqti: 9:00-18:00, to'liq stavka, ofisda
📌 Tajriba: kamida 2 yil
📞 +998 90 123-45-67
✉️ @hr_example_uz
"""
let ruVacancy = """
#вакансия
Требуется менеджер по продажам
г. Ташкент, офис
Зарплата: от 5 000 000 до 8 000 000 сум
Опыт работы от 1 года
Тел: +998 (93) 555 44 33
hr@example.uz
"""
let uzCyrillicVacancy = """
#вакансия
Ҳисобчи керак
Самарқандда, тўлиқ кун
Ойлик: 5-7 млн сўм
Телефон: 91 234 56 78
"""
let enResume = """
#resume #cv
Looking for a job: iOS developer
3 years of experience with Swift
Remote or hybrid
Expected salary: $1500+
Contact: @dev_example, https://github.com/alidev.
"""
let uzResume = """
#rezyume
Ism: Aziz, 24 yosh
Ish qidiryapman, Buxoroda yoki masofadan
Tajriba: 2 yillik
Oylik: kelishilgan
Tel: 998971112233
"""
let ruResume = """
Резюме
Ищу работу бухгалтером в Москве
Опыт 5 лет, полная занятость
Желаемая зарплата 80 000 руб.
+7 (999) 123-45-67
"""
let now: Int32 = 1_800_000_000
let vacancyInfo = NovagramJobPostInfo(kind: .vacancy, salary: NovagramJobSalary(text: "800$", min: 800, max: 800, currency: .usd), cityIds: ["tashkent"], formats: [.office])
let resumeInfo = NovagramJobPostInfo(kind: .resume)
let emptyQuery = NovagramSearchQuery.parse("")
let cryptoSpam = """
🚀 MegaCoin MEC $0.000763
Market cap: $2,000 - $200,000
We provide a 100% profitable trading strategy. Join now: t.me/megacoin_signals
#ios #swift #iphone
"""
let chineseSpam = "限时优惠！苹果 iOS 手机 低价出售，正品保证，联系微信 abc123 #ios #swift 全国包邮 欢迎咨询"
let casinoSpam = "Казино онлайн! Ставки на спорт, бонус 100%. Нужен только телефон, вывод на карту от 500 000 сум. @example_casino_bot"
let airdropSpam = "Free airdrop! Claim your token now, pump x100 guaranteed. Apply here: https://example.com/claim #swift"
let bettingSpam = "Betting tips for iOS app users: earn $500 daily, write @example_tipster"
let legacyFilterJSON = #"{"mode":"findCandidates","query":"swift","cityIds":["tashkent"],"formats":["remote"],"period":"month","onlyWithSalary":true}"#

let jobFilter = NovagramJobFilter(mode: .findJob, query: "iOS | swift -junior", period: .month)
let jobQuery = NovagramSearchQuery.parse(jobFilter.query)
func acceptedForJob(_ text: String, query: NovagramSearchQuery = jobQuery) -> Bool {
    return jobFilter.accepts(text: text, info: NovagramJobPostParser.parse(text), date: now, now: now, query: query)
}
