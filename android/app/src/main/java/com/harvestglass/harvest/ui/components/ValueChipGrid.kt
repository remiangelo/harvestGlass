package com.harvestglass.harvest.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.data.model.Value
import com.harvestglass.harvest.ui.theme.HarvestTheme
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Port of Harvest/Views/Components/ValueChipGrid.swift.
 *
 * Tapping a chip past [maxSelection] shakes it rather than silently doing
 * nothing, so the cap is visible instead of feeling broken.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ValueChipGrid(
    values: List<Value>,
    selectedIds: Set<String>,
    maxSelection: Int,
    onToggle: (Value) -> Unit,
    modifier: Modifier = Modifier
) {
    var shakingId by remember { mutableStateOf<String?>(null) }
    val view = LocalView.current

    LaunchedEffect(shakingId) {
        if (shakingId != null) {
            delay(SHAKE_MILLIS.toLong())
            shakingId = null
        }
    }

    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = modifier.fillMaxWidth()
    ) {
        values.forEach { value ->
            val isSelected = selectedIds.contains(value.id)
            val shakeProgress by animateFloatAsState(
                targetValue = if (shakingId == value.id) 1f else 0f,
                animationSpec = tween(durationMillis = SHAKE_MILLIS),
                label = "chipShake"
            )

            ChipViewShakeWrapper(progress = shakeProgress) {
                ChipView(
                    title = value.name,
                    isSelected = isSelected,
                    onTap = {
                        if (!isSelected && selectedIds.size >= maxSelection) {
                            view.performHapticFeedbackCompat()
                            shakingId = value.id
                        } else {
                            onToggle(value)
                        }
                    }
                )
            }
        }
    }
}

@Composable
private fun ChipViewShakeWrapper(progress: Float, content: @Composable () -> Unit) {
    // Matches the Swift ShakeEffect: 6pt amplitude, two full cycles.
    val translation = (SHAKE_AMPLITUDE_DP * sin(progress * PI * 4)).roundToInt()
    androidx.compose.foundation.layout.Box(
        Modifier.offset { IntOffset(translation, 0) }
    ) { content() }
}

private const val SHAKE_MILLIS = 350
private const val SHAKE_AMPLITUDE_DP = 6.0

private fun android.view.View.performHapticFeedbackCompat() {
    performHapticFeedback(android.view.HapticFeedbackConstants.LONG_PRESS)
}
