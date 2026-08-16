package com.harvestglass.harvest.ui.theme

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * Port of Harvest/Theme/HarvestButtonStyle.swift.
 *
 * iOS routes every button through the iOS 26 Liquid Glass material
 * (`.glassEffect(...interactive())`). Android has no equivalent, so this
 * reproduces everything else the style defines — capsule geometry, per-kind
 * tint and foreground, paddings, and the spring tap-and-hold press — and
 * accepts the loss of the translucent material itself.
 */
enum class HarvestButtonKind { PRIMARY, SECONDARY, DESTRUCTIVE, CHIP_SELECTED, CHIP_UNSELECTED }

internal val HarvestButtonKind.isChip: Boolean
    get() = this == HarvestButtonKind.CHIP_SELECTED || this == HarvestButtonKind.CHIP_UNSELECTED

private val HarvestButtonKind.fill: Color
    get() = when (this) {
        HarvestButtonKind.PRIMARY, HarvestButtonKind.CHIP_SELECTED -> HarvestTheme.Colors.rose
        HarvestButtonKind.DESTRUCTIVE -> HarvestTheme.Colors.error
        HarvestButtonKind.SECONDARY -> HarvestTheme.Colors.glassFillStrong
        HarvestButtonKind.CHIP_UNSELECTED -> Color.Transparent
    }

private val HarvestButtonKind.foreground: Color
    get() = when (this) {
        HarvestButtonKind.PRIMARY, HarvestButtonKind.DESTRUCTIVE, HarvestButtonKind.CHIP_SELECTED ->
            HarvestTheme.Colors.textOnRedPrimary
        else -> HarvestTheme.Colors.textPrimary
    }

@Composable
fun HarvestButton(
    text: String,
    kind: HarvestButtonKind = HarvestButtonKind.PRIMARY,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()

    // iOS: .scaleEffect(pressed ? 0.96 : 1)
    //      .animation(.spring(response: 0.3, dampingFraction: 0.65))
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.96f else 1f,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = Spring.StiffnessMediumLow),
        label = "pressScale"
    )

    val shape = RoundedCornerShape(percent = 50)
    val hPad = if (kind.isChip) HarvestTheme.Spacing.md else HarvestTheme.Spacing.lg
    val vPad = if (kind.isChip) HarvestTheme.Spacing.sm else 14.dp

    Row(
        horizontalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.sm,
            Alignment.CenterHorizontally
        ),
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .scale(scale)
            .clip(shape)
            .background(kind.fill, shape)
            .then(
                if (kind == HarvestButtonKind.CHIP_UNSELECTED) {
                    Modifier.border(
                        BorderStroke(1.dp, HarvestTheme.Colors.rose.copy(alpha = 0.3f)),
                        shape
                    )
                } else Modifier
            )
            // Make the whole padded pill tappable, not just the text/icon glyphs.
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(horizontal = hPad, vertical = vPad)
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = kind.foreground)
        Text(
            text = text,
            style = if (kind.isChip) HarvestTheme.Typography.bodySmall else HarvestTheme.Typography.buttonText,
            fontWeight = if (kind == HarvestButtonKind.CHIP_UNSELECTED) FontWeight.Normal else FontWeight.SemiBold,
            color = kind.foreground
        )
    }
}
