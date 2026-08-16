package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Port of Harvest/Views/Components/ChipView.swift. */
@Composable
fun ChipView(
    title: String,
    isSelected: Boolean = false,
    lightStyle: Boolean = false,
    onTap: (() -> Unit)? = null
) {
    if (!lightStyle) {
        HarvestButton(
            text = title,
            kind = if (isSelected) HarvestButtonKind.CHIP_SELECTED else HarvestButtonKind.CHIP_UNSELECTED,
            onClick = { onTap?.invoke() }
        )
        return
    }

    // Light chips live on cream/white form surfaces, so they keep the
    // solid-capsule treatment for contrast rather than translucent glass.
    val shape = RoundedCornerShape(percent = 50)
    Text(
        text = title,
        style = HarvestTheme.Typography.bodySmall,
        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
        color = if (isSelected) HarvestTheme.Colors.textOnRedPrimary else HarvestTheme.Colors.textPrimary,
        modifier = Modifier
            .background(
                if (isSelected) HarvestTheme.Colors.formAccent else HarvestTheme.Colors.formSurface,
                shape
            )
            .then(
                if (!isSelected) Modifier.border(1.dp, HarvestTheme.Colors.formBorder, shape)
                else Modifier
            )
            .clickable { onTap?.invoke() }
            .padding(horizontal = HarvestTheme.Spacing.md, vertical = HarvestTheme.Spacing.sm)
    )
}
