package com.harvestglass.harvest.ui.onboarding.steps

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * The shape every onboarding step shares in Harvest/Views/Onboarding/:
 * centred spacer, a 50pt primary-tinted glyph, an h2 title, an optional
 * bodyRegular subtitle, then the step's own content.
 */
@Composable
fun StepScaffold(
    icon: ImageVector,
    title: String,
    subtitle: String? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xl),
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = HarvestTheme.Spacing.md)
    ) {
        Spacer(Modifier.weight(1f))

        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = HarvestTheme.Colors.primary,
            modifier = Modifier.size(50.dp)
        )

        Text(
            text = title,
            style = HarvestTheme.Typography.h2,
            color = HarvestTheme.Colors.textPrimary,
            textAlign = TextAlign.Center
        )

        if (subtitle != null) {
            Text(
                text = subtitle,
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textSecondary,
                textAlign = TextAlign.Center
            )
        }

        content()

        Spacer(Modifier.weight(1f))
    }
}

/**
 * The selectable row used by the gender, interested-in, relationship-status
 * and location-suggestion steps: red fill and white text when selected, a
 * form surface with a hairline when not.
 */
@Composable
fun SelectableRow(
    label: String,
    isSelected: Boolean,
    modifier: Modifier = Modifier,
    leading: ImageVector? = null,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.md)
    val foreground =
        if (isSelected) Color.White else HarvestTheme.Colors.textPrimary

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = modifier
            .fillMaxWidth()
            .background(
                if (isSelected) HarvestTheme.Colors.redSurface else HarvestTheme.Colors.formSurface,
                shape
            )
            .border(
                1.dp,
                if (isSelected) HarvestTheme.Colors.primaryLight else HarvestTheme.Colors.formBorder,
                shape
            )
            .clickable { onClick() }
            .padding(HarvestTheme.Spacing.md)
    ) {
        if (leading != null) {
            Icon(leading, contentDescription = null, tint = foreground, modifier = Modifier.size(24.dp))
        }
        Text(
            text = label,
            style = HarvestTheme.Typography.bodyRegular,
            color = foreground,
            modifier = Modifier.weight(1f)
        )
        if (isSelected) {
            Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = Color.White)
        }
    }
}
