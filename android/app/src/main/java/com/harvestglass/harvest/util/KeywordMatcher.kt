package com.harvestglass.harvest.util

/**
 * Shared matching rules for the safety and mindful-messaging lexicons.
 * Port of Harvest/Utilities/KeywordMatcher.swift.
 *
 * Both lists used to be scanned with a plain `contains`, which matched *inside*
 * words: "hello" hit "hell", "shoes" hit "hoe", "one of us" hit "f u",
 * "breakfast" hit "break". Every match here is anchored to word boundaries
 * instead, on a normalized copy of the text.
 */
object KeywordMatcher {

    /**
     * Words that address the other person. A `directed` keyword only counts
     * when one of these shares its clause — "kill some time" and "I'll kill
     * you" are not the same message.
     */
    private val SECOND_PERSON = setOf(
        "you", "youre", "your", "yours", "yourself", "yourselves", "u", "ur", "urself"
    )

    /** Apostrophe variants stripped so "can't" and "cant" are one keyword. */
    private val APOSTROPHES = charArrayOf('\'', '’', '‘', 'ʼ', '`', '´')

    private val WHITESPACE_RUN = Regex("\\s+")

    private val CLAUSE_SEPARATORS = charArrayOf('.', '!', '?', ';', ',', '\n', '\r')

    /**
     * Lowercases, drops apostrophes, and reduces every other non-alphanumeric to
     * a single space. The result holds only letters, digits and spaces — which
     * is what makes `\b` mean what it looks like it means.
     */
    fun normalize(text: String): String {
        val lowered = text.lowercase().filterNot { it in APOSTROPHES }
        val stripped = buildString(lowered.length) {
            lowered.forEach { append(if (it.isLetterOrDigit()) it else ' ') }
        }
        return WHITESPACE_RUN.replace(stripped, " ").trim()
    }

    /**
     * Splits on sentence and clause punctuation *before* normalizing, so
     * "you know, that was stupid" doesn't read as an insult aimed at anyone.
     */
    fun clauses(text: String): List<String> =
        text.split(*CLAUSE_SEPARATORS)
            .map { normalize(it) }
            .filter { it.isNotEmpty() }

    /**
     * True when [keyword] appears in already-normalized [text] as whole words.
     *
     * Single-word keywords also match simple inflections — "stalk" matches
     * "stalks", "stalked", "stalking" — but never a longer stem, so "hell"
     * still does not match "hello".
     */
    fun contains(keyword: String, text: String): Boolean {
        val normalizedKeyword = normalize(keyword)
        if (normalizedKeyword.isEmpty()) return false

        // Cheap reject first: a substring hit is necessary (inflections only
        // append), so the regex runs for a handful of candidates rather than
        // for every keyword in every lexicon on every message.
        if (!text.contains(normalizedKeyword)) return false

        val escaped = Regex.escape(normalizedKeyword)
        val inflection = if (normalizedKeyword.contains(" ")) "" else "(?:s|es|ed|ing)?"
        return Regex("\\b$escaped$inflection\\b").containsMatchIn(text)
    }

    /**
     * True when [keyword] shares a clause with a word addressing the other
     * person. Use for terms that are only concerning when aimed at someone.
     */
    fun containsDirected(keyword: String, clauses: List<String>): Boolean =
        clauses.any { clause -> addressesOtherPerson(clause) && contains(keyword, clause) }

    /** [clause] must already be normalized. */
    fun addressesOtherPerson(clause: String): Boolean =
        clause.split(" ").any { SECOND_PERSON.contains(it) }
}
