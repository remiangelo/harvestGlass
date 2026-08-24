package com.harvestglass.harvest.ui.field

import com.harvestglass.harvest.ui.components.chat.ChatAccent
import com.harvestglass.harvest.ui.theme.HarvestTheme
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Locks down a genuinely counter-intuitive choice.
 *
 * `ChatAccent.Field` (green) exists and looks like the obvious accent for a
 * Field community room — but `CommunityChatView.swift` passes `.rose` to the
 * backdrop (line 197), the composer (307) and the bubbles (473). Commit
 * 4e94622 "rose becomes the primary accent, green demoted to a signal" is
 * where that changed.
 *
 * The first Android port picked Field green by reading the component and not
 * the call site, which made every bubble the wrong colour.
 */
class CommunityChatAccentTest {

    @Test
    fun `community rooms use the rose accent, not the field green`() {
        assertEquals(ChatAccent.Rose, COMMUNITY_CHAT_ACCENT)
    }

    @Test
    fun `the rose accent carries the brand reds`() {
        assertEquals(HarvestTheme.Colors.rose, COMMUNITY_CHAT_ACCENT.base)
        assertEquals(HarvestTheme.Colors.roseDeep, COMMUNITY_CHAT_ACCENT.deep)
        assertEquals(HarvestTheme.Colors.accent, COMMUNITY_CHAT_ACCENT.light)
    }

    @Test
    fun `the field green variant still exists for anything that wants it`() {
        // Kept because the Swift enum defines it; nothing uses it today.
        assertEquals(HarvestTheme.Colors.fieldGreen, ChatAccent.Field.base)
    }
}
