package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Port of Harvest/Views/Components/GlassBadge.swift. */
@Composable
fun GlassBadge(text: String, color: Color = HarvestTheme.Colors.textOnBlack) {
    val shape = RoundedCornerShape(percent = 50)
    Text(
        text = text,
        style = HarvestTheme.Typography.caption,
        fontWeight = FontWeight.SemiBold,
        color = color,
        modifier = Modifier
            .background(HarvestTheme.Colors.formSurfaceStrong, shape)
            .border(1.dp, HarvestTheme.Colors.formBorder, shape)
            .padding(horizontal = HarvestTheme.Spacing.sm, vertical = HarvestTheme.Spacing.xs)
    )
}
