package com.harvestglass.harvest.ui.components.chat

import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId

/** Where a message sits within a run of consecutive messages from one sender. */
data class MessagePosition(
    val showsDateSeparator: Boolean,
    val isFirstInGroup: Boolean,
    val isLastInGroup: Boolean
)

/**
 * Port of Harvest/Views/Components/Chat/MessageGrouping.swift.
 * Decides how messages clump together in a transcript. Pure and synchronous
 * so it can be unit tested without a view or a network.
 */
object MessageGrouping {

    /**
     * Messages from one sender closer together than this, on the same day,
     * render as a single group.
     */
    const val GROUP_WINDOW_SECONDS = 5L * 60L

    /**
     * Parses a Supabase timestamp. Postgres emits up to six fractional
     * digits; java.time handles that natively, which is why this is simpler
     * than the Swift original (ISO8601DateFormatter accepts only three, so
     * the iOS version has to trim and retry).
     */
    fun date(from: String?): Instant? {
        if (from == null) return null
        return runCatching { OffsetDateTime.parse(from).toInstant() }
            .recoverCatching { Instant.parse(from) }
            .getOrNull()
    }

    fun position(
        previousSender: String?, previousDate: Instant?,
        currentSender: String, currentDate: Instant?,
        nextSender: String?, nextDate: Instant?
    ): MessagePosition {
        // Without a usable timestamp a message can't be placed in a run,
        // so it stands alone rather than guessing.
        if (currentDate == null) {
            return MessagePosition(
                showsDateSeparator = false,
                isFirstInGroup = true,
                isLastInGroup = true
            )
        }

        val showsDateSeparator = when {
            previousSender == null -> true              // top of the transcript
            previousDate == null -> false               // unusable — don't invent a break
            else -> !isSameDay(previousDate, currentDate)
        }

        return MessagePosition(
            showsDateSeparator = showsDateSeparator,
            isFirstInGroup = !continues(previousSender, previousDate, currentSender, currentDate),
            isLastInGroup = !continues(currentSender, currentDate, nextSender, nextDate)
        )
    }

    /**
     * True when the second message continues the first: same sender, same
     * calendar day, inside the window.
     */
    private fun continues(
        fromSender: String?, fromDate: Instant?,
        toSender: String?, toDate: Instant?
    ): Boolean {
        if (fromSender == null || toSender == null || fromSender != toSender) return false
        if (fromDate == null || toDate == null) return false
        if (!isSameDay(fromDate, toDate)) return false
        return (toDate.epochSecond - fromDate.epochSecond) < GROUP_WINDOW_SECONDS
    }

    private fun isSameDay(a: Instant, b: Instant): Boolean {
        val zone = ZoneId.systemDefault()
        return a.atZone(zone).toLocalDate() == b.atZone(zone).toLocalDate()
    }
}
