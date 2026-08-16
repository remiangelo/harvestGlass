package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Port of Harvest/Views/Components/GlassCard.swift. */
enum class GlassCardStyle { DARK, LIGHT }

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = HarvestTheme.Radius.xl,
    padding: Dp = HarvestTheme.Spacing.md,
    style: GlassCardStyle = GlassCardStyle.DARK,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)
    val fill = when (style) {
        GlassCardStyle.DARK -> HarvestTheme.Colors.glassFill
        GlassCardStyle.LIGHT -> HarvestTheme.Colors.formSurface
    }
    val stroke = when (style) {
        GlassCardStyle.DARK -> HarvestTheme.Colors.border
        GlassCardStyle.LIGHT -> HarvestTheme.Colors.formBorder
    }

    Column(
        modifier = modifier
            .background(fill, shape)
            .border(1.dp, stroke, shape)
            .padding(padding),
        content = content
    )
}
