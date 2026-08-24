package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * What is being reported. Mirrors ReportTarget in
 * Harvest/Views/Chat/ReportUserView.swift — the type and id go straight into
 * `user_reports`, so moderators can find the message, not just the account.
 */
sealed class ReportTarget(val typeString: String, val targetId: String?) {
    data object Profile : ReportTarget("profile", null)
    data class CommunityMessage(val id: String) : ReportTarget("community_message", id)
    data class SeedMessage(val id: String) : ReportTarget("seed_message", id)
}

/** The categories iOS offers, in the same order. */
private val CATEGORIES = listOf("General", "Harassment", "Spam", "Safety", "Catfishing")

/**
 * Port of Harvest/Views/Chat/ReportUserView.swift.
 *
 * A description is required — a bare category tells a moderator nothing about
 * what happened, which is why iOS disables Submit until one is written.
 */
@Composable
fun ReportSheet(
    target: ReportTarget = ReportTarget.Profile,
    onSubmit: (category: String, description: String, target: ReportTarget) -> Unit,
    onDismiss: () -> Unit
) {
    var selectedCategory by remember { mutableStateOf(CATEGORIES.first()) }
    var description by remember { mutableStateOf("") }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
            .imePadding()
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
                text = "Report User",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier
                    .weight(1f)
                    .padding(start = HarvestTheme.Spacing.md)
            )
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            SectionHeader("Category")
            Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                CATEGORIES.forEach { category ->
                    CategoryRow(
                        label = category,
                        isSelected = selectedCategory == category,
                        onClick = { selectedCategory = category }
                    )
                }
            }

            SectionHeader("Description")
            val shape = RoundedCornerShape(HarvestTheme.Radius.md)
            BasicTextField(
                value = description,
                onValueChange = { description = it },
                textStyle = LocalTextStyle.current.merge(
                    TextStyle(color = HarvestTheme.Colors.textPrimary)
                ),
                cursorBrush = SolidColor(HarvestTheme.Colors.accent),
                modifier = Modifier.fillMaxWidth(),
                decorationBox = { innerTextField ->
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .heightIn(min = 120.dp)
                            .background(HarvestTheme.Colors.formSurface, shape)
                            .border(1.dp, HarvestTheme.Colors.formBorder, shape)
                            .padding(HarvestTheme.Spacing.md),
                        contentAlignment = Alignment.TopStart
                    ) {
                        if (description.isEmpty()) {
                            Text(
                                text = "What happened?",
                                style = HarvestTheme.Typography.bodyRegular,
                                color = HarvestTheme.Colors.textTertiary
                            )
                        }
                        innerTextField()
                    }
                }
            )

            HarvestButton(
                text = "Submit Report",
                icon = Icons.Filled.Warning,
                kind = HarvestButtonKind.DESTRUCTIVE,
                modifier = Modifier.fillMaxWidth()
            ) {
                // A category with no account of what happened is not a report a
                // moderator can act on, so Submit stays inert until one exists.
                if (description.isBlank()) return@HarvestButton
                onSubmit(selectedCategory, description.trim(), target)
                onDismiss()
            }
        }
    }
}

@Composable
private fun CategoryRow(label: String, isSelected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.md)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (isSelected) HarvestTheme.Colors.accentSoft else HarvestTheme.Colors.formSurface,
                shape
            )
            .border(
                1.dp,
                if (isSelected) HarvestTheme.Colors.accent else HarvestTheme.Colors.formBorder,
                shape
            )
            .clickable { onClick() }
            .padding(HarvestTheme.Spacing.md)
    ) {
        Text(
            text = label,
            style = HarvestTheme.Typography.bodyRegular,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            color = HarvestTheme.Colors.textPrimary
        )
    }
}
