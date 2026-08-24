package com.harvestglass.harvest.ui.chat

import androidx.compose.animation.core.tween
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CheckCircleOutline
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.harvestglass.harvest.data.model.Message
import com.harvestglass.harvest.ui.components.chat.ChatAccent
import com.harvestglass.harvest.ui.components.chat.MessagePosition
import com.harvestglass.harvest.ui.components.chat.chatBubbleShape
import com.harvestglass.harvest.ui.theme.HarvestTheme
import com.harvestglass.harvest.util.ObjectionableContent

/**
 * Port of Harvest/Views/Chat/MessageBubbleView.swift.
 *
 * A separate composable from the community-room `ChatBubble` because iOS has
 * two bubble views too: this one carries blur-on-receive, read receipts and a
 * per-run time label, and has no reactions or quoted replies. The bubble
 * geometry itself is shared via [chatBubbleShape].
 */
@Composable
fun MessageBubble(
    message: Message,
    isSent: Boolean,
    position: MessagePosition,
    timeLabel: String = "",
    accent: ChatAccent = ChatAccent.Rose
) {
    var revealed by remember(message.id) { mutableStateOf(false) }

    // Incoming messages only: the sender is not warned about their own text
    // here, that is the (deferred) pre-send check's job.
    val flaggedCategory = if (isSent) null else ObjectionableContent.category(message.content.orEmpty())
    val isBlurred = flaggedCategory != null && !revealed

    val blurRadius by animateFloatAsState(
        targetValue = if (isBlurred) 7f else 0f,
        animationSpec = tween(durationMillis = 200),
        label = "revealBlur"
    )

    val shape = chatBubbleShape(
        isMine = isSent,
        isFirstInGroup = position.isFirstInGroup,
        isLastInGroup = position.isLastInGroup
    )

    Row(
        Modifier
            .fillMaxWidth()
            .padding(
                horizontal = HarvestTheme.Spacing.md,
                vertical = if (position.isFirstInGroup) HarvestTheme.Spacing.xs else 1.dp
            ),
        horizontalArrangement = if (isSent) Arrangement.End else Arrangement.Start
    ) {
        Column(horizontalAlignment = if (isSent) Alignment.End else Alignment.Start) {
            Box(
                Modifier
                    .widthIn(max = 280.dp)
                    .clip(shape)
                    .then(
                        if (isSent) {
                            Modifier
                                .background(Brush.linearGradient(listOf(accent.base, accent.deep)), shape)
                                .border(1.dp, Color.White.copy(alpha = 0.16f), shape)
                        } else {
                            Modifier
                                .background(HarvestTheme.Colors.wineCard, shape)
                                .border(1.dp, HarvestTheme.Colors.border, shape)
                        }
                    )
                    .clickable(enabled = isBlurred) { revealed = true }
                    .defaultMinSize(
                        minWidth = if (isBlurred) 150.dp else 0.dp,
                        minHeight = if (isBlurred) 44.dp else 0.dp
                    )
            ) {
                Text(
                    text = message.content.orEmpty(),
                    style = HarvestTheme.Typography.bodyRegular,
                    color = if (isSent) {
                        HarvestTheme.Colors.textOnRedPrimary
                    } else {
                        HarvestTheme.Colors.textPrimary
                    },
                    modifier = Modifier
                        .padding(
                            horizontal = HarvestTheme.Spacing.md,
                            vertical = HarvestTheme.Spacing.sm
                        )
                        .blur(blurRadius.dp)
                )

                if (isBlurred) {
                    BlurOverlay(
                        hint = hintFor(flaggedCategory),
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
            }

            // Metadata once per run, not once per bubble.
            if (timeLabel.isNotEmpty()) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(horizontal = 4.dp)
                ) {
                    Text(
                        text = timeLabel,
                        fontSize = 10.sp,
                        color = HarvestTheme.Colors.textTertiary
                    )
                    if (isSent) {
                        Icon(
                            imageVector = if (message.isRead) {
                                Icons.Filled.CheckCircle
                            } else {
                                Icons.Filled.CheckCircleOutline
                            },
                            contentDescription = if (message.isRead) "Read" else "Sent",
                            tint = if (message.isRead) {
                                HarvestTheme.Colors.primary
                            } else {
                                HarvestTheme.Colors.textTertiary
                            },
                            modifier = Modifier.size(10.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BlurOverlay(hint: String, modifier: Modifier = Modifier) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
        modifier = modifier.padding(horizontal = HarvestTheme.Spacing.sm)
    ) {
        Icon(
            Icons.Filled.VisibilityOff,
            contentDescription = null,
            tint = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = hint,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = HarvestTheme.Colors.textPrimary,
            textAlign = TextAlign.Center
        )
        Text(
            text = "Tap to reveal",
            fontSize = 10.sp,
            color = HarvestTheme.Colors.textSecondary
        )
    }
}

/**
 * Recipient-facing hint about why a message is hidden. Strings are verbatim
 * from MessageBubbleView.swift; only the two categories whose lexicons are
 * ported can currently be reported, and anything else falls to the default.
 */
internal fun hintFor(category: String?): String = when (category) {
    "aggressive" -> "May contain hostile language"
    "sexual_pressure" -> "May contain explicit content"
    "manipulative" -> "May contain manipulative language"
    "possessive" -> "May contain controlling language"
    "pressuring" -> "May contain pressuring language"
    "excessive_intensity" -> "Very intense message"
    "personal_info", "phone_number" -> "May contain personal info"
    else -> "Possibly sensitive content"
}
