package com.harvestglass.harvest.data.service

/**
 * Re-paragraphs a Gardener reply so a wall of text never lands in the chat.
 * Port of formatResponse/splitIntoSentences in GardenerService.swift.
 */
object GardenerFormatter {

    fun format(text: String): String {
        val cleaned = text.replace("\r\n", "\n").trim()
        if (cleaned.isEmpty()) return text

        // Already paragraphed by the model: leave it alone.
        if (cleaned.contains("\n\n")) return cleaned

        val lines = cleaned.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
        if (lines.size > 1) return lines.joinToString("\n\n")

        val sentences = splitIntoSentences(cleaned)
        if (sentences.size <= 3) return cleaned

        val paragraphs = mutableListOf<String>()
        var index = 0
        while (index < sentences.size) {
            val remaining = sentences.size - index
            // A trailing three stays together rather than orphaning one.
            val chunk = if (remaining <= 3) remaining else 2
            paragraphs += sentences.subList(index, minOf(index + chunk, sentences.size))
                .joinToString(" ")
            index += chunk
        }
        return paragraphs.joinToString("\n\n")
    }

    internal fun splitIntoSentences(text: String): List<String> {
        val sentences = mutableListOf<String>()
        val current = StringBuilder()

        text.forEach { ch ->
            current.append(ch)
            if (ch == '.' || ch == '!' || ch == '?') {
                val trimmed = current.toString().trim()
                if (trimmed.isNotEmpty()) sentences += trimmed
                current.clear()
            }
        }

        val trailing = current.toString().trim()
        if (trailing.isNotEmpty()) {
            // An unterminated tail joins the previous sentence rather than
            // becoming a stray fragment of its own.
            if (sentences.isEmpty()) sentences += trailing
            else sentences[sentences.lastIndex] = sentences.last() + " " + trailing
        }

        return sentences
    }
}
