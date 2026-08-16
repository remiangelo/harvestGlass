package com.harvestglass.harvest.ui.field

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.harvestglass.harvest.data.model.Community
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** Copy asserted here is verbatim from Harvest/Views/Field/FieldView.swift. */
class FieldScreenTest {
    @get:Rule val rule = createComposeRule()

    private val joined = Community(
        id = "c1", slug = "s1", name = "Single Parents", kind = "status", memberCount = 1
    )
    private val notJoined = Community(
        id = "c2", slug = "s2", name = "New Here", kind = "status", memberCount = 4
    )

    @Test
    fun emptyStateShowsWhenThereAreNoRooms() {
        rule.setContent {
            HarvestAppTheme { FieldContent(FieldUiState(isLoading = false), {}, {}) }
        }
        rule.onNodeWithText("No spaces yet").assertIsDisplayed()
    }

    @Test
    fun headerCopyMatchesIos() {
        rule.setContent {
            HarvestAppTheme { FieldContent(FieldUiState(isLoading = false), {}, {}) }
        }
        rule.onNodeWithText("Join the spaces where you're hoping to grow connection.")
            .assertIsDisplayed()
    }

    @Test
    fun memberCountIsSingularForOne() {
        rule.setContent {
            HarvestAppTheme {
                FieldContent(
                    FieldUiState(available = listOf(joined), joinedIds = setOf("c1")), {}, {}
                )
            }
        }
        rule.onNodeWithText("1 member").assertIsDisplayed()
    }

    @Test
    fun memberCountIsPluralForMany() {
        rule.setContent {
            HarvestAppTheme { FieldContent(FieldUiState(available = listOf(notJoined)), {}, {}) }
        }
        rule.onNodeWithText("4 members").assertIsDisplayed()
    }

    @Test
    fun joiningAnUnjoinedRoomInvokesToggle() {
        var toggled: Community? = null
        rule.setContent {
            HarvestAppTheme {
                FieldContent(
                    state = FieldUiState(available = listOf(notJoined)),
                    onToggle = { toggled = it },
                    onOpenRoom = {}
                )
            }
        }
        rule.onNodeWithText("Join").performClick()
        assertEquals(notJoined, toggled)
    }

    @Test
    fun tappingAJoinedRoomOpensIt() {
        var opened: Community? = null
        rule.setContent {
            HarvestAppTheme {
                FieldContent(
                    state = FieldUiState(available = listOf(joined), joinedIds = setOf("c1")),
                    onToggle = {},
                    onOpenRoom = { opened = it }
                )
            }
        }
        rule.onNodeWithText("Single Parents").performClick()
        assertEquals(joined, opened)
    }

    @Test
    fun joinedRoomsShowTheOpenAffordanceAndUnjoinedDoNot() {
        rule.setContent {
            HarvestAppTheme {
                FieldContent(
                    FieldUiState(
                        available = listOf(joined, notJoined),
                        joinedIds = setOf("c1")
                    ), {}, {}
                )
            }
        }
        rule.onNodeWithText("Tap to open room").assertIsDisplayed()
        rule.onNodeWithText("Join").assertIsDisplayed()
    }
}
