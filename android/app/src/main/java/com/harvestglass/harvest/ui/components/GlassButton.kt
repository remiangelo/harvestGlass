package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind

/**
 * Port of Harvest/Views/Components/GlassButton.swift — a full-width button
 * routed through the shared HarvestButton style.
 */
@Composable
fun GlassButton(
    title: String,
    icon: ImageVector? = null,
    style: HarvestButtonKind = HarvestButtonKind.PRIMARY,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    HarvestButton(
        text = title,
        kind = style,
        icon = icon,
        modifier = modifier.fillMaxWidth(),
        onClick = onClick
    )
}
