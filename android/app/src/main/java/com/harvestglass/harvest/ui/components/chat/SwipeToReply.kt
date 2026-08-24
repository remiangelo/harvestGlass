package com.harvestglass.harvest.ui.components.chat

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/**
 * Drag-right-to-reply. Port of SwipeToReply in CommunityChatView.swift:
 * the row follows at half speed up to a 60pt cap, fires past 40pt, and
 * springs back either way.
 */
@Composable
fun SwipeToReply(
    onReply: () -> Unit,
    content: @Composable () -> Unit
) {
    var dragged by remember { mutableFloatStateOf(0f) }
    var settled by remember { mutableStateOf(true) }
    val density = LocalDensity.current
    val capPx = with(density) { MAX_OFFSET_DP.dp.toPx() }
    val triggerPx = with(density) { TRIGGER_DP.dp.toPx() }

    val offset by animateFloatAsState(
        targetValue = if (settled) 0f else dragged,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "swipeReply"
    )

    Box(
        Modifier
            .offset { IntOffset(offset.roundToInt(), 0) }
            .pointerInput(Unit) {
                detectHorizontalDragGestures(
                    onDragStart = { settled = false },
                    onDragEnd = {
                        if (dragged > triggerPx) onReply()
                        dragged = 0f
                        settled = true
                    },
                    onDragCancel = {
                        dragged = 0f
                        settled = true
                    }
                ) { _, delta ->
                    // Rightward only, at half speed, capped.
                    if (delta > 0 || dragged > 0f) {
                        dragged = (dragged + delta * 0.5f).coerceIn(0f, capPx)
                    }
                }
            }
    ) { content() }
}

private const val MAX_OFFSET_DP = 60
private const val TRIGGER_DP = 40
