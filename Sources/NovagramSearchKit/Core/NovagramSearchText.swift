import Foundation

/// Text normalization shared by the search features.
public enum NovagramSearchText {
    /// Characters treated as the same apostrophe as `'`.
    public static let apostropheVariants: Set<Character> = ["\u{2018}", "\u{2019}", "\u{02BB}", "\u{02BC}", "\u{0060}", "\u{00B4}", "\u{2032}"]

    private static let apostrophe: Character = "'"
    private static let comparisonOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// The text with every apostrophe variant replaced by `'`.
    public static func unifyingApostrophes(_ text: String) -> String {
        guard text.contains(where: { apostropheVariants.contains($0) }) else {
            return text
        }
        return String(text.map { apostropheVariants.contains($0) ? apostrophe : $0 })
    }

    /// The text trimmed, with every run of whitespace and newlines replaced by one space.
    public static func collapsingWhitespace(_ text: String) -> String {
        return text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Lowercased, without diacritics, apostrophes unified and whitespace collapsed.
    public static func normalized(_ text: String) -> String {
        let folded = unifyingApostrophes(text).folding(options: comparisonOptions, locale: nil)
        return collapsingWhitespace(folded)
    }

    /// True when `text` contains `phrase`, ignoring case, diacritics, apostrophe variants and whitespace runs.
    public static func contains(_ text: String, phrase: String) -> Bool {
        let needle = collapsingWhitespace(unifyingApostrophes(phrase))
        guard !needle.isEmpty else {
            return false
        }
        let haystack = collapsingWhitespace(unifyingApostrophes(text))
        return haystack.range(of: needle, options: comparisonOptions) != nil
    }
}
