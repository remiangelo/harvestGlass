import Foundation

/// Shared matching rules for the safety and mindful-messaging lexicons.
///
/// Both lists used to be scanned with a plain `contains`, which matched
/// *inside* words: "hello" hit "hell", "shoes" hit "hoe", "one of us" hit
/// "f u", "breakfast" hit "break". Every match here is anchored to word
/// boundaries instead, on a normalized copy of the text.
enum KeywordMatcher {

    /// Words that address the other person. A `directed` keyword only counts
    /// when one of these shares its clause — "kill some time" and "I'll kill
    /// you" are not the same message.
    private static let secondPerson: Set<String> = [
        "you", "youre", "your", "yours", "yourself", "yourselves", "u", "ur", "urself"
    ]

    /// Lowercases, drops apostrophes so "can't" and "cant" match one keyword,
    /// and reduces every other non-alphanumeric to a single space. The result
    /// holds only letters, digits and spaces — which is what makes `\b` mean
    /// what it looks like it means.
    static func normalize(_ text: String) -> String {
        var lowered = text.lowercased()
        for mark in ["'", "\u{2019}", "\u{2018}", "\u{02BC}", "`", "\u{00B4}"] {
            lowered = lowered.replacingOccurrences(of: mark, with: "")
        }

        let stripped = String(lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : Character(" ")
        })

        return stripped
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Splits on sentence and clause punctuation *before* normalizing, so
    /// "you know, that was stupid" doesn't read as an insult aimed at anyone.
    static func clauses(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ".!?;,\n\r"))
            .map { normalize($0) }
            .filter { !$0.isEmpty }
    }

    /// True when `keyword` appears in already-normalized `text` as whole words.
    ///
    /// Single-word keywords also match simple inflections — "stalk" matches
    /// "stalks", "stalked", "stalking" — but never a longer stem, so "hell"
    /// still does not match "hello".
    static func contains(_ keyword: String, in text: String) -> Bool {
        let normalizedKeyword = normalize(keyword)
        guard !normalizedKeyword.isEmpty else { return false }

        // Cheap reject first: a substring hit is necessary (inflections only
        // append), so the regex runs for a handful of candidates rather than
        // for every keyword in every lexicon on every message.
        guard text.contains(normalizedKeyword) else { return false }

        let escaped = NSRegularExpression.escapedPattern(for: normalizedKeyword)
        let inflection = normalizedKeyword.contains(" ") ? "" : "(?:s|es|ed|ing)?"
        return text.range(
            of: "\\b\(escaped)\(inflection)\\b",
            options: .regularExpression
        ) != nil
    }

    /// True when `keyword` shares a clause with a word addressing the other
    /// person. Use for terms that are only concerning when aimed at someone.
    static func containsDirected(_ keyword: String, inClauses clauses: [String]) -> Bool {
        clauses.contains { clause in
            addressesOtherPerson(clause) && contains(keyword, in: clause)
        }
    }

    /// `clause` must already be normalized.
    static func addressesOtherPerson(_ clause: String) -> Bool {
        clause.split(separator: " ").contains { secondPerson.contains(String($0)) }
    }
}
