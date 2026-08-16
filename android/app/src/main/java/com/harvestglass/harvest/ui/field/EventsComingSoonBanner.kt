package com.harvestglass.harvest.ui.field

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Field/EventsComingSoonBanner.swift.
 * Announcement only — there is no events feature yet. Deliberately
 * stateless: no dismiss, no persistence, nothing to fetch.
 */
@Composable
fun EventsComingSoonBanner() {
    val shape = RoundedCornerShape(HarvestTheme.Radius.xl)

    Box(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(
                Brush.linearGradient(
                    listOf(
                        HarvestTheme.Colors.rose.copy(alpha = 0.14f),
                        HarvestTheme.Colors.wineCard
                    )
                ),
                shape
            )
            .border(1.dp, HarvestTheme.Colors.rose.copy(alpha = 0.28f), shape)
    ) {
        // Oversized leaf, clipped by the card — a watermark, not an icon.
        Icon(
            imageVector = Icons.Filled.Eco,
            contentDescription = null,
            tint = HarvestTheme.Colors.fieldGreen.copy(alpha = 0.10f),
            modifier = Modifier
                .align(Alignment.TopEnd)
                .size(96.dp)
                .rotate(-18f)
                .offset(x = 22.dp, y = (-18).dp)
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier
                .fillMaxWidth()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Filled.AutoAwesome,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.accent,
                    modifier = Modifier.size(11.dp)
                )
                Text(
                    text = "COMING SOON",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.8.sp,
                    color = HarvestTheme.Colors.accent
                )
            }

            Text(
                text = "Community events",
                style = HarvestTheme.Typography.h3,
                color = HarvestTheme.Colors.textPrimary
            )

            Text(
                text = "Online and in person. Gather with members near you — and everywhere.",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary
            )

            Row(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                modifier = Modifier.padding(top = HarvestTheme.Spacing.xxs)
            ) {
                ModePill("Online", Icons.Filled.Videocam)
                ModePill("In person", Icons.Filled.LocationOn)
            }
        }
    }
}

@Composable
private fun ModePill(title: String, icon: ImageVector) {
    val shape = RoundedCornerShape(percent = 50)
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(HarvestTheme.Colors.primarySoft, shape)
            .border(1.dp, HarvestTheme.Colors.rose.copy(alpha = 0.22f), shape)
            .padding(horizontal = HarvestTheme.Spacing.sm, vertical = HarvestTheme.Spacing.xs)
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = HarvestTheme.Colors.accent,
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = title,
            style = HarvestTheme.Typography.caption,
            color = HarvestTheme.Colors.accent
        )
    }
}
