package com.harvestglass.harvest.ui.values

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.ContactPage
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Shield
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Port of Harvest/ViewModels/TipsViewModel.swift.
 *
 * Static copy, not table data — the Swift version hardcodes it too, so this is
 * a straight transcription rather than a service.
 */
enum class TipCategory(val label: String) {
    CONVERSATION("Conversation"),
    PROFILE("Profile"),
    SAFETY("Safety"),
    MINDFULNESS("Mindfulness")
}

data class Tip(
    val title: String,
    val body: String,
    val category: TipCategory,
    val icon: ImageVector
)

data class TipFaq(val question: String, val answer: String)

object Tips {
    val all: List<Tip> = listOf(
        Tip(
            title = "Lead With Your Values",
            body = "Don't open with 'how was your day' — open with a question about " +
                "something you actually value. 'What's a value you live by lately?' " +
                "tells you more in one message than ten about logistics.",
            category = TipCategory.CONVERSATION,
            icon = Icons.AutoMirrored.Filled.Chat
        ),
        Tip(
            title = "Show the Values You Bring",
            body = "Instead of saying 'I'm honest,' share a story that demonstrates the " +
                "value. Your profile lands when your photos and bio together show what " +
                "you stand for, not just what you do.",
            category = TipCategory.PROFILE,
            icon = Icons.Filled.ContactPage
        ),
        Tip(
            title = "Trust Misalignment Signals",
            body = "When someone's actions don't match the values they claim, that's " +
                "data. Slow down, ask one direct question, and trust what you hear back. " +
                "Misalignment early is a gift.",
            category = TipCategory.SAFETY,
            icon = Icons.Filled.Shield
        ),
        Tip(
            title = "Depth Over Volume",
            body = "Better to have one conversation rooted in shared values than five " +
                "surface chats. Invest where the values overlap; let the rest fade " +
                "without guilt.",
            category = TipCategory.MINDFULNESS,
            icon = Icons.Filled.Favorite
        ),
        Tip(
            title = "Photos That Show Your Values",
            body = "One clear face shot, one full-body, and one photo of you doing " +
                "something that reflects what matters to you — a meal you cooked, a " +
                "place that grounds you, a project you finished.",
            category = TipCategory.PROFILE,
            icon = Icons.Filled.PhotoLibrary
        ),
        Tip(
            title = "Meet in Public First",
            body = "First dates in public are about value alignment in low-stakes " +
                "settings, and they're also about safety. Pick a place you'd happily go " +
                "alone, and tell someone where you'll be.",
            category = TipCategory.SAFETY,
            icon = Icons.Filled.LocationOn
        )
    )

    val faqs: List<TipFaq> = listOf(
        TipFaq(
            question = "How do I lead with values without sounding stiff?",
            answer = "Anchor a value in a story or a small detail. 'I value honesty — " +
                "last week I had to tell a friend a hard truth and we're closer for it' " +
                "lands warmer than the abstract version."
        ),
        TipFaq(
            question = "When should I suggest meeting in person?",
            answer = "Move to meeting once you've heard enough to know your values " +
                "aren't going to actively clash. Usually 5–10 days of consistent " +
                "messaging. Pick a low-pressure activity that lets you see who they " +
                "are, not who they perform as."
        ),
        TipFaq(
            question = "How do I handle rejection from someone whose values I liked?",
            answer = "Compatibility is more than overlap — it's also fit, timing, and a " +
                "hundred things you can't control. Thank them, wish them well, and let " +
                "the values you valued in them sharpen your sense of what's next."
        )
    )

    /** Null shows everything, matching `filteredTips`. */
    fun filtered(category: TipCategory?): List<Tip> =
        if (category == null) all else all.filter { it.category == category }
}
