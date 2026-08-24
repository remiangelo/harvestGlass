package com.harvestglass.harvest.ui.values

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of the embedded `tipsSection` in Harvest/Views/Values/ValuesView.swift.
 *
 * Gold-only; the caller decides whether this or the gate renders.
 */
@Composable
fun TipsSection() {
    var selectedCategory by remember { mutableStateOf<TipCategory?>(null) }
    var expandedFaq by remember { mutableStateOf<String?>(null) }

    Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
        Text(
            text = "Values-Based Dating Tips",
            style = HarvestTheme.Typography.h3,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = HarvestTheme.Spacing.md)
        ) {
            TipsChip("All", selectedCategory == null) { selectedCategory = null }
            TipCategory.entries.forEach { category ->
                TipsChip(category.label, selectedCategory == category) {
                    selectedCategory = category
                }
            }
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)
        ) {
            Tips.filtered(selectedCategory).forEach { tip -> TipCard(tip) }
        }

        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
            Text(
                text = "Quick Advice",
                style = HarvestTheme.Typography.h3,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)
            )
            Column(
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
                modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)
            ) {
                Tips.faqs.forEach { faq ->
                    FaqCard(
                        faq = faq,
                        isExpanded = expandedFaq == faq.question,
                        onToggle = {
                            expandedFaq = if (expandedFaq == faq.question) null else faq.question
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun TipCard(tip: Tip) {
    TipsCard {
        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
            ) {
                Icon(
                    imageVector = tip.icon,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.accent,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = tip.title,
                    style = HarvestTheme.Typography.h4,
                    color = HarvestTheme.Colors.textPrimary,
                    modifier = Modifier.weight(1f)
                )
                CategoryPill(tip.category.label)
            }
            Text(
                text = tip.body,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary.copy(alpha = 0.92f)
            )
        }
    }
}

@Composable
private fun FaqCard(faq: TipFaq, isExpanded: Boolean, onToggle: () -> Unit) {
    // Stands in for the iOS DisclosureGroup.
    TipsCard(padding = HarvestTheme.Spacing.sm) {
        Column {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onToggle() }
                    .padding(HarvestTheme.Spacing.sm)
            ) {
                Text(
                    text = faq.question,
                    style = HarvestTheme.Typography.bodyRegular,
                    fontWeight = FontWeight.Medium,
                    color = HarvestTheme.Colors.textPrimary,
                    modifier = Modifier.weight(1f)
                )
                Icon(
                    imageVector = if (isExpanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                    contentDescription = if (isExpanded) "Collapse" else "Expand",
                    tint = HarvestTheme.Colors.primary
                )
            }
            AnimatedVisibility(visible = isExpanded) {
                Text(
                    text = faq.answer,
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary,
                    modifier = Modifier.padding(
                        start = HarvestTheme.Spacing.sm,
                        end = HarvestTheme.Spacing.sm,
                        bottom = HarvestTheme.Spacing.sm
                    )
                )
            }
        }
    }
}

@Composable
private fun CategoryPill(label: String) {
    Text(
        text = label,
        style = HarvestTheme.Typography.caption,
        fontWeight = FontWeight.SemiBold,
        color = HarvestTheme.Colors.accent,
        modifier = Modifier
            .background(
                HarvestTheme.Colors.accentSoft,
                RoundedCornerShape(HarvestTheme.Radius.full)
            )
            .padding(horizontal = HarvestTheme.Spacing.sm, vertical = 6.dp)
    )
}

@Composable
private fun TipsChip(title: String, isSelected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.full)
    Text(
        text = title,
        style = HarvestTheme.Typography.bodySmall,
        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
        color = if (isSelected) {
            HarvestTheme.Colors.textOnRedPrimary
        } else {
            HarvestTheme.Colors.textPrimary
        },
        modifier = Modifier
            .background(
                if (isSelected) HarvestTheme.Colors.primary else HarvestTheme.Colors.wineCard,
                shape
            )
            .border(1.dp, HarvestTheme.Colors.rose.copy(alpha = 0.22f), shape)
            .clickable { onClick() }
            .padding(horizontal = HarvestTheme.Spacing.md, vertical = HarvestTheme.Spacing.sm)
    )
}

/** The `tipsCard` helper: wineCard fill, rose hairline, lg radius. */
@Composable
private fun TipsCard(
    padding: androidx.compose.ui.unit.Dp = HarvestTheme.Spacing.md,
    content: @Composable () -> Unit
) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.lg)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineCard, shape)
            .border(1.dp, HarvestTheme.Colors.rose.copy(alpha = 0.22f), shape)
            .padding(padding)
    ) {
        content()
    }
}
