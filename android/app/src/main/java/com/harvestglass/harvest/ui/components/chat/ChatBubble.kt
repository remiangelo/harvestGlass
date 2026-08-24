package com.harvestglass.harvest.ui.components.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.harvestglass.harvest.data.model.CommunityMessage
import com.harvestglass.harvest.data.model.CommunityReaction
import com.harvestglass.harvest.data.model.CommunitySender
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of ChatBubbleShape.swift: a bubble outline that tightens the corners
 * facing its neighbours, so a run of messages reads as one column instead of
 * a stack of separate pills.
 */
fun chatBubbleShape(isMine: Boolean, isFirstInGroup: Boolean, isLastInGroup: Boolean): Shape {
    val round = 20.dp
    val tight = 6.dp

    // The "tail" side is the one nearest the sender: trailing for mine,
    // leading for theirs. Only that side tightens.
    val top = if (isFirstInGroup) round else tight
    val bottom = if (isLastInGroup) round else tight

    return RoundedCornerShape(
        topStart = if (isMine) round else top,
        bottomStart = if (isMine) round else bottom,
        bottomEnd = if (isMine) bottom else round,
        topEnd = if (isMine) top else round
    )
}

/**
 * Port of the community bubble in CommunityChatView.swift plus
 * ChatBubbleBackground.swift.
 *
 * Deliberately not a translucent material: on the cream page a light blur is
 * almost indistinguishable from the background, so incoming bubbles rely on a
 * solid surface, a hairline, and a soft shadow to separate instead.
 */
@Composable
fun ChatBubble(
    message: CommunityMessage,
    sender: CommunitySender?,
    isMine: Boolean,
    position: MessagePosition,
    accent: ChatAccent,
    reactions: List<CommunityReaction>,
    quoted: CommunityMessage?,
    quotedSenderName: String?,
    timeLabel: String = "",
    mentionNicknames: List<String> = emptyList(),
    mentionsMe: Boolean = false,
    onLongPress: () -> Unit,
    /** Tapping the avatar or name opens the sender's profile, as on iOS. */
    onSenderTap: (() -> Unit)? = null
) {
    val shape = chatBubbleShape(isMine, position.isFirstInGroup, position.isLastInGroup)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                top = if (position.isFirstInGroup) HarvestTheme.Spacing.sm else HarvestTheme.Spacing.xxs,
                start = HarvestTheme.Spacing.md,
                end = HarvestTheme.Spacing.md
            ),
        horizontalArrangement = if (isMine) Arrangement.End else Arrangement.Start,
        verticalAlignment = Alignment.Bottom
    ) {
        if (!isMine) {
            Avatar(
                sender,
                visible = position.isLastInGroup,
                modifier = if (onSenderTap != null) {
                    Modifier.clickable { onSenderTap() }
                } else {
                    Modifier
                }
            )
            Box(Modifier.size(HarvestTheme.Spacing.sm))
        }

        Column(horizontalAlignment = if (isMine) Alignment.End else Alignment.Start) {
            if (!isMine && position.isFirstInGroup) {
                Text(
                    text = sender?.nickname ?: "Member",
                    style = HarvestTheme.Typography.caption,
                    fontWeight = FontWeight.SemiBold,
                    color = accent.light,
                    modifier = Modifier
                        .then(
                            if (onSenderTap != null) {
                                Modifier.clickable { onSenderTap() }
                            } else {
                                Modifier
                            }
                        )
                        .padding(
                            start = HarvestTheme.Spacing.sm,
                            bottom = HarvestTheme.Spacing.xxs
                        )
                )
            }

            Column(
                modifier = Modifier
                    .widthIn(max = 280.dp)
                    .clip(shape)
                    .then(
                        if (isMine) {
                            Modifier.background(
                                Brush.linearGradient(listOf(accent.base, accent.deep)),
                                shape
                            ).border(1.dp, Color.White.copy(alpha = 0.16f), shape)
                        } else {
                            Modifier.background(HarvestTheme.Colors.wineCard, shape)
                                .border(
                                    if (mentionsMe) 2.dp else 1.dp,
                                    if (mentionsMe) accent.light else HarvestTheme.Colors.border,
                                    shape
                                )
                        }
                    )
                    .padding(horizontal = HarvestTheme.Spacing.md, vertical = 10.dp)
            ) {
                if (quoted != null) {
                    QuotedPreview(
                        quoted = quoted,
                        senderName = quotedSenderName,
                        isMine = isMine,
                        accent = accent
                    )
                }

                Text(
                    text = highlightMentions(
                        content = message.content,
                        nicknames = mentionNicknames,
                        highlight = if (isMine) {
                            HarvestTheme.Colors.textInverse
                        } else {
                            accent.light
                        }
                    ),
                    style = HarvestTheme.Typography.bodyRegular,
                    color = if (isMine) {
                        HarvestTheme.Colors.textInverse
                    } else {
                        HarvestTheme.Colors.textPrimary
                    }
                )
            }

            if (reactions.isNotEmpty()) {
                ReactionRow(reactions)
            }

            // Metadata once per run, not once per bubble.
            if (timeLabel.isNotEmpty()) {
                Text(
                    text = timeLabel,
                    fontSize = 10.sp,
                    color = HarvestTheme.Colors.textTertiary,
                    modifier = Modifier.padding(horizontal = 4.dp)
                )
            }
        }
    }
}

/** iOS pins the avatar gutter at 36pt so grouped rows stay flush. */
private val AVATAR_SIZE = 36.dp

@Composable
private fun Avatar(
    sender: CommunitySender?,
    visible: Boolean,
    modifier: Modifier = Modifier
) {
    Box(
        modifier
            .size(AVATAR_SIZE)
            .clip(CircleShape)
            .background(
                if (visible) HarvestTheme.Colors.wineRaised else Color.Transparent,
                CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        if (!visible) return@Box
        val url = sender?.photoUrl
        if (url != null) {
            AsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(AVATAR_SIZE).clip(CircleShape)
            )
        } else {
            Text(
                text = sender?.nickname?.firstOrNull()?.uppercase() ?: "?",
                style = HarvestTheme.Typography.caption,
                color = HarvestTheme.Colors.textSecondary
            )
        }
    }
}

@Composable
private fun QuotedPreview(
    quoted: CommunityMessage,
    senderName: String?,
    isMine: Boolean,
    accent: ChatAccent
) {
    val tint = if (isMine) {
        HarvestTheme.Colors.textInverse.copy(alpha = 0.75f)
    } else {
        accent.light
    }
    Column(
        Modifier
            .padding(bottom = HarvestTheme.Spacing.xs)
            .background(
                if (isMine) Color.White.copy(alpha = 0.14f) else accent.base.copy(alpha = 0.08f),
                RoundedCornerShape(HarvestTheme.Radius.sm)
            )
            .padding(HarvestTheme.Spacing.sm)
    ) {
        Text(
            text = senderName ?: "Member",
            style = HarvestTheme.Typography.caption,
            fontWeight = FontWeight.SemiBold,
            color = tint
        )
        Text(
            // Removed originals still render, so the quote reads honestly.
            text = if (quoted.isRemoved) "Message removed" else quoted.content,
            style = HarvestTheme.Typography.caption,
            color = tint,
            maxLines = 2
        )
    }
}

@Composable
private fun ReactionRow(reactions: List<CommunityReaction>) {
    val shape = RoundedCornerShape(percent = 50)
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
        modifier = Modifier.padding(top = HarvestTheme.Spacing.xxs)
    ) {
        reactions.groupBy { it.emoji }.forEach { (emoji, list) ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .background(HarvestTheme.Colors.wineRaised, shape)
                    .border(1.dp, HarvestTheme.Colors.border, shape)
                    .padding(horizontal = HarvestTheme.Spacing.sm, vertical = 2.dp)
            ) {
                Text(text = emoji, style = HarvestTheme.Typography.caption)
                if (list.size > 1) {
                    Text(
                        text = " ${list.size}",
                        style = HarvestTheme.Typography.caption,
                        color = HarvestTheme.Colors.textSecondary
                    )
                }
            }
        }
    }
}


/**
 * Bolds and tints any "@nickname" the message actually mentions.
 *
 * Only nicknames resolved from the message's `mentions` id array are
 * highlighted, so a literal "@someone" that was never a real mention stays
 * plain text — matching iOS.
 */
internal fun highlightMentions(
    content: String,
    nicknames: List<String>,
    highlight: Color
): AnnotatedString {
    if (nicknames.isEmpty()) return AnnotatedString(content)

    return buildAnnotatedString {
        var index = 0
        while (index < content.length) {
            val next = nicknames
                .mapNotNull { nick ->
                    val at = content.indexOf("@$nick", index, ignoreCase = true)
                    if (at >= 0) at to nick else null
                }
                .minByOrNull { it.first }

            if (next == null) {
                append(content.substring(index))
                return@buildAnnotatedString
            }

            val (at, nick) = next
            append(content.substring(index, at))
            withStyle(SpanStyle(color = highlight, fontWeight = FontWeight.SemiBold)) {
                append(content.substring(at, at + nick.length + 1))
            }
            index = at + nick.length + 1
        }
    }
}
