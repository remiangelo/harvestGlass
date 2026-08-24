package com.harvestglass.harvest.util

/**
 * A short, safe-to-display message for an exception.
 *
 * Postgrest exceptions stringify the entire request — URL, headers and the
 * `Authorization: Bearer <JWT>` — so rendering `e.message` directly puts the
 * signed-in user's access token on screen. Only the first line survives here,
 * anything from a `URL:` marker onward is cut, and the result is capped.
 *
 * Use this everywhere an exception reaches UI state.
 */
fun Throwable.userMessage(): String {
    val firstLine = message
        ?.lineSequence()
        ?.firstOrNull { it.isNotBlank() }
        ?.substringBefore("URL:")
        ?.trim()

    if (firstLine.isNullOrBlank()) return GENERIC_ERROR
    return if (firstLine.length > MAX_LENGTH) firstLine.take(MAX_LENGTH).trimEnd() else firstLine
}

private const val MAX_LENGTH = 200
private const val GENERIC_ERROR = "Something went wrong. Please try again."
