package com.harvestglass.harvest.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import com.harvestglass.harvest.ui.components.ChipView
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.GlassCardStyle
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * The catalogue offered in the picker. Copied verbatim from
 * InterestPickerView.swift — the strings are stored on the profile, so a
 * reworded entry here would orphan everyone who picked the old one.
 */
val CATEGORIZED_INTERESTS: List<Pair<String, List<String>>> = listOf(
    "Sports & Fitness" to listOf(
        "Running", "Yoga", "Hiking", "Gym", "Swimming", "Basketball", "Soccer",
        "Tennis", "Cycling", "Rock Climbing", "Martial Arts", "Surfing",
        "Skiing", "Snowboarding", "Golf", "Volleyball", "Pilates", "CrossFit",
        "Skateboarding", "Boxing"
    ),
    "Music & Arts" to listOf(
        "Live Music", "Playing Guitar", "Singing", "DJing", "Piano",
        "Painting", "Drawing", "Photography", "Pottery", "Graphic Design",
        "Film Making", "Dance", "Theater", "Poetry", "Creative Writing"
    ),
    "Food & Drink" to listOf(
        "Cooking", "Baking", "Coffee", "Wine Tasting", "Craft Beer",
        "Foodie", "BBQ & Grilling", "Sushi", "Brunch", "Cocktails",
        "Vegan Cooking", "Food Trucks"
    ),
    "Travel & Outdoors" to listOf(
        "Traveling", "Camping", "Road Trips", "Beach", "Backpacking",
        "Fishing", "Gardening", "Bird Watching", "Kayaking", "Sailing",
        "National Parks", "Stargazing"
    ),
    "Entertainment" to listOf(
        "Movies", "TV Shows", "Anime", "Gaming", "Board Games",
        "Concerts", "Podcasts", "Stand-Up Comedy", "Trivia", "Karaoke",
        "Reading", "Book Club", "True Crime"
    ),
    "Tech & Learning" to listOf(
        "Technology", "Coding", "AI & Machine Learning", "Investing",
        "Entrepreneurship", "Science", "History", "Languages", "Philosophy"
    ),
    "Lifestyle" to listOf(
        "Meditation", "Thrifting", "Fashion", "Interior Design", "Volunteering",
        "Dogs", "Cats", "Astrology", "Tattoos", "Journaling",
        "Skincare", "Wellness", "Festivals", "Brunch", "Night Life"
    ),
    "Social" to listOf(
        "Dinner Parties", "Game Nights", "Wine Nights", "Sports Watching",
        "Networking", "Community Service", "Mentoring"
    )
)

/**
 * Port of Harvest/Views/Profile/InterestPickerView.swift.
 *
 * Edits a local draft and only hands it back on Save, so backing out leaves
 * the profile untouched.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun InterestPicker(
    selected: List<String>,
    onSave: (List<String>) -> Unit,
    onDismiss: () -> Unit
) {
    val draft = remember(selected) { mutableStateListOf(*selected.toTypedArray()) }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(HarvestTheme.Colors.wineBlack)
                .statusBarsPadding()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Text(
                text = "Cancel",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.accent,
                modifier = Modifier.clickable { onDismiss() }
            )
            Text(
                text = "Interests",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = HarvestTheme.Spacing.md)
            )
            Text(
                text = "Save",
                style = HarvestTheme.Typography.bodyRegular,
                fontWeight = FontWeight.SemiBold,
                color = HarvestTheme.Colors.accent,
                modifier = Modifier.clickable {
                    onSave(draft.toList())
                    onDismiss()
                }
            )
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            GlassCard(style = GlassCardStyle.LIGHT) {
                Text(
                    text = "Pick your interests (${draft.size} selected)",
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary
                )
            }

            CATEGORIZED_INTERESTS.forEach { (category, interests) ->
                Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                    Text(
                        text = category,
                        style = HarvestTheme.Typography.h4,
                        color = HarvestTheme.Colors.textPrimary
                    )
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)
                    ) {
                        interests.forEach { interest ->
                            ChipView(
                                title = interest,
                                isSelected = draft.contains(interest),
                                lightStyle = true,
                                onTap = {
                                    if (!draft.remove(interest)) draft.add(interest)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}
