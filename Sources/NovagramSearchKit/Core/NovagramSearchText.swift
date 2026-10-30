import Foundation

/// Text normalization shared by the search features.
public enum NovagramSearchText {
    /// Characters treated as the same apostrophe as `'`.
    public static let apostropheVariants: Set<Character> = ["\u{2018}", "\u{2019}", "\u{02BB}", "\u{02BC}", "\u{0060}", "\u{00B4}", "\u{2032}"]

    private static let apostropheScalars: Set<Unicode.Scalar> = ["\u{2018}", "\u{2019}", "\u{02BB}", "\u{02BC}", "\u{0060}", "\u{00B4}", "\u{2032}"]
    private static let apostrophe: Unicode.Scalar = "'"
    private static let comparisonOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// The text with every apostrophe variant replaced by `'`.
    public static func unifyingApostrophes(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: { apostropheScalars.contains($0) }) else {
            return text
        }
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            scalars.append(apostropheScalars.contains(scalar) ? apostrophe : scalar)
        }
        return String(scalars)
    }

    /// The same as `unifyingApostrophes(_:)`.
    public static func unifiedApostrophes(_ text: String) -> String {
        return unifyingApostrophes(text)
    }

    /// The text trimmed, with every run of whitespace and newlines replaced by one space.
    public static func collapsingWhitespace(_ text: String) -> String {
        return text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Lowercased, without diacritics, apostrophes unified and whitespace trimmed and collapsed.
    public static func normalized(_ text: String) -> String {
        let folded = unifyingApostrophes(text).folding(options: comparisonOptions, locale: nil).lowercased()
        var scalars = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                pendingSpace = !scalars.isEmpty
                continue
            }
            if pendingSpace {
                scalars.append(" ")
                pendingSpace = false
            }
            scalars.append(apostropheScalars.contains(scalar) ? apostrophe : scalar)
        }
        return String(scalars)
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

    /// True for the ASCII letters A-Z and a-z.
    public static func isLatinLetter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return (scalar.value >= 0x41 && scalar.value <= 0x5A) || (scalar.value >= 0x61 && scalar.value <= 0x7A)
    }

    /// True for letters of the Cyrillic block U+0400-U+04FF.
    public static func isCyrillicLetter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return scalar.value >= 0x0400 && scalar.value <= 0x04FF
    }

    static func isWordCharacter(_ character: Character) -> Bool {
        return character.isLetter || character.isNumber || character == "'" || character == "_"
    }

    static func containsAtWordStart(_ haystack: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, options: .literal, range: searchRange) {
            if found.lowerBound == haystack.startIndex || !isWordCharacter(haystack[haystack.index(before: found.lowerBound)]) {
                return true
            }
            searchRange = haystack.index(after: found.lowerBound)..<haystack.endIndex
        }
        return false
    }
}
