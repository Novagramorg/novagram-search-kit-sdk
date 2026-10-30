import Foundation

/// The search switches stored in the shared `pro_messager` suite.
public final class NovagramSearchSettings: @unchecked Sendable {
    /// The UserDefaults suite both apps share.
    public static let suiteName = "pro_messager"

    /// UserDefaults keys.
    public enum Keys {
        public static let searchFeatures = "novagram_search_features"
        public static let searchTranslate = "novagram_search_translate"
        public static let translationLanguage = "auto_translate_lang"
        public static let translateTargets = "novagram_search_translate_langs"
    }

    /// Settings deep-link slugs.
    public enum DeepLinkSlug {
        public static let searchFeatures = "search-features"
        public static let searchTranslate = "search-translate"
    }

    /// Posted with the settings object after a switch is written.
    public static let didChangeNotification = Notification.Name("NovagramSearchSettingsDidChange")

    /// The language a query is translated into when `auto_translate_lang` is missing or empty.
    public static let fallbackTranslationLanguage = "en"

    /// The codes `novagram_search_translate_langs` may hold, in their default section order.
    public static let translateTargetCodes = ["uz-Latn", "uz-Cyrl", "ru", "en"]

    /// The most translations requested from the server for one query.
    public static let maxServerTranslations = 3

    /// Settings backed by the `pro_messager` suite.
    public static let shared = NovagramSearchSettings(defaults: UserDefaults(suiteName: suiteName) ?? .standard)

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter

    /// Settings backed by `defaults`; changes are posted on `notificationCenter`.
    public init(defaults: UserDefaults, notificationCenter: NotificationCenter = .default) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    /// The master "Search features" switch; a missing key counts as on.
    public var isSearchFeaturesEnabled: Bool {
        get {
            return defaults.object(forKey: Keys.searchFeatures) as? Bool ?? true
        }
        set {
            write(newValue, forKey: Keys.searchFeatures)
        }
    }

    /// The "Search the translated query too" switch; a missing key counts as off.
    public var isTranslateEnabled: Bool {
        get {
            return defaults.object(forKey: Keys.searchTranslate) as? Bool ?? false
        }
        set {
            write(newValue, forKey: Keys.searchTranslate)
        }
    }

    /// True when the translated section may run: both switches are on.
    public var isTranslateActive: Bool {
        return isSearchFeaturesEnabled && isTranslateEnabled
    }

    /// `auto_translate_lang`, or `en` when it is missing or empty.
    public var translationLanguage: String {
        guard let language = defaults.string(forKey: Keys.translationLanguage), !language.isEmpty else {
            return NovagramSearchSettings.fallbackTranslationLanguage
        }
        return language
    }

    /// The translated-section languages in section order; an empty array means no translation.
    public var translateTargets: [String] {
        guard let stored = defaults.object(forKey: Keys.translateTargets) else {
            return [NovagramSearchSettings.legacyTarget(translationLanguage)]
        }
        let codes = stored as? [String] ?? []
        return codes.filter { NovagramSearchSettings.translateTargetCodes.contains($0) }
    }

    /// Stores the allowed codes of `codes`, deduplicated in order; an empty array stores no translation.
    public func setTranslateTargets(_ codes: [String]) {
        var seen = Set<String>()
        let allowed = codes.filter { NovagramSearchSettings.translateTargetCodes.contains($0) && seen.insert($0).inserted }
        defaults.set(allowed, forKey: Keys.translateTargets)
        notificationCenter.post(name: NovagramSearchSettings.didChangeNotification, object: self)
    }

    /// The server translation codes for `targets`: both Uzbek scripts become one `uz`, deduplicated, at most 3.
    public static func serverTranslationCodes(for targets: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for target in targets {
            let code = target == "uz-Latn" || target == "uz-Cyrl" ? "uz" : target
            if seen.insert(code).inserted {
                result.append(code)
            }
        }
        return Array(result.prefix(maxServerTranslations))
    }

    private static func legacyTarget(_ language: String) -> String {
        return language == "uz" ? "uz-Latn" : language
    }

    private func write(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
        notificationCenter.post(name: NovagramSearchSettings.didChangeNotification, object: self)
    }
}
