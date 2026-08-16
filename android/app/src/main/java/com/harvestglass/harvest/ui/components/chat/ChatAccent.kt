package com.harvestglass.harvest.ui.components.chat

import androidx.compose.ui.graphics.Color
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Components/Chat/ChatAccent.swift.
 *
 * The three tints one chat surface needs. Field rooms are green, Seed
 * conversations are red; everything else about the two is identical, so
 * components take one of these rather than three loose colors.
 */
data class ChatAccent(
    /** Outgoing bubble fill, send button. */
    val base: Color,
    /** Outgoing gradient end. */
    val deep: Color,
    /** Quotes, mentions, metadata. */
    val light: Color
) {
    companion object {
        val Rose = ChatAccent(
            base = HarvestTheme.Colors.rose,
            deep = HarvestTheme.Colors.roseDeep,
            light = HarvestTheme.Colors.accent
        )

        val Field = ChatAccent(
            base = HarvestTheme.Colors.fieldGreen,
            deep = HarvestTheme.Colors.fieldGreenDeep,
            light = HarvestTheme.Colors.fieldGreenLight
        )
    }
}
