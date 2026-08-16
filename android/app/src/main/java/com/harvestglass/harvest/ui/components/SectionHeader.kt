package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.harvestglass.harvest.ui.theme.HarvestTheme
import java.util.Locale

/**
 * Port of Harvest/Views/Components/SectionHeader.swift.
 * iOS applies .textCase(.uppercase) and .tracking(0.8).
 */
@Composable
fun SectionHeader(title: String) {
    Text(
        text = title.uppercase(Locale.getDefault()),
        style = HarvestTheme.Typography.caption.copy(letterSpacing = 0.8.sp),
        fontWeight = FontWeight.Medium,
        color = HarvestTheme.Colors.textSecondary,
        modifier = Modifier.padding(start = HarvestTheme.Spacing.xs)
    )
}
