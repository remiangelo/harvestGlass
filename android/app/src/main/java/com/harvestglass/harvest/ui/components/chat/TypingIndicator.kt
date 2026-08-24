package com.harvestglass.harvest.ui.components.chat

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Per-dot stagger, matching iOS's 0.15s delay between dots. */
private const val DOT_STAGGER_MS = 150

/** One up-and-back bounce, matching iOS's 0.5s autoreversing ease. */
private const val BOUNCE_MS = 500

/**
 * Port of Harvest/Views/Components/TypingIndicatorView.swift.
 *
 * Sits on the same surface as an incoming bubble so it reads as one, and is
 * always first-and-last in its group — it never joins a run of messages.
 */
@Composable
fun TypingIndicator(modifier: Modifier = Modifier) {
    val shape = chatBubbleShape(isMine = false, isFirstInGroup = true, isLastInGroup = true)
    val transition = rememberInfiniteTransition(label = "typing")

    Row(
        modifier
            .fillMaxWidth()
            .padding(horizontal = HarvestTheme.Spacing.md, vertical = HarvestTheme.Spacing.xs),
        horizontalArrangement = Arrangement.Start
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            modifier = Modifier
                .clip(shape)
                .background(HarvestTheme.Colors.wineCard, shape)
                .border(1.dp, HarvestTheme.Colors.border, shape)
                .padding(
                    horizontal = HarvestTheme.Spacing.md,
                    vertical = HarvestTheme.Spacing.sm + 4.dp
                )
        ) {
            repeat(3) { index ->
                val offset by transition.animateFloat(
                    initialValue = 0f,
                    targetValue = 0f,
                    animationSpec = infiniteRepeatable(
                        animation = keyframes {
                            durationMillis = BOUNCE_MS * 2 + DOT_STAGGER_MS * 2
                            0f at (index * DOT_STAGGER_MS)
                            -6f at (index * DOT_STAGGER_MS + BOUNCE_MS)
                            0f at (index * DOT_STAGGER_MS + BOUNCE_MS * 2)
                        },
                        repeatMode = RepeatMode.Restart
                    ),
                    label = "dot$index"
                )

                Box(
                    Modifier
                        .offset(y = offset.dp)
                        .size(8.dp)
                        .background(HarvestTheme.Colors.textTertiary, CircleShape)
                )
            }
        }
    }
}
