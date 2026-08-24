package com.harvestglass.harvest.ui.field

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowCircleUp
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.harvestglass.harvest.data.model.Community
import com.harvestglass.harvest.data.model.CommunityMessage
import com.harvestglass.harvest.data.model.CommunityPrompt
import com.harvestglass.harvest.data.model.CommunityReaction
import com.harvestglass.harvest.ui.components.chat.ChatAccent
import com.harvestglass.harvest.ui.components.chat.ChatBubble
import com.harvestglass.harvest.ui.components.chat.ChatComposer
import com.harvestglass.harvest.ui.components.chat.DateSeparator
import com.harvestglass.harvest.ui.components.chat.MessageGrouping
import com.harvestglass.harvest.ui.components.chat.MessagePosition
import com.harvestglass.harvest.ui.components.chat.SwipeToReply
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * The accent community rooms actually use.
 *
 * `ChatAccent.Field` (green) exists and looks like the obvious pick, but
 * CommunityChatView.swift passes `.rose` to the backdrop, composer and
 * bubbles alike — commit 4e94622 demoted the green to a signal colour used
 * only for Field *list* accents, not the chat surface.
 */
internal val COMMUNITY_CHAT_ACCENT = ChatAccent.Rose

/**
 * Port of Harvest/Views/Field/CommunityChatView.swift.
 */
@Composable
fun CommunityChatScreen(
    community: Community,
    userId: String,
    onBack: () -> Unit,
    onOpenMembers: (String) -> Unit = {},
    viewModel: CommunityChatViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val accent = COMMUNITY_CHAT_ACCENT
    val listState = rememberLazyListState()
    var reactingTo by remember { mutableStateOf<CommunityMessage?>(null) }
    var showPrompts by remember { mutableStateOf(false) }

    LaunchedEffect(community.id) { viewModel.start(community.id, userId) }

    // Follow the newest message as it arrives.
    LaunchedEffect(state.messages.size) {
        if (state.messages.isNotEmpty()) {
            listState.animateScrollToItem(state.messages.lastIndex)
        }
    }

    if (showPrompts) {
        PromptPicker(
            prompts = state.prompts,
            onPick = {
                viewModel.updateDraft(it)
                showPrompts = false
            },
            onDismiss = { showPrompts = false }
        )
        return
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
            // Keeps the composer above the keyboard; commit 0ecd728 fixed the
            // last message being clipped behind it.
            .imePadding()
    ) {
        TopBar(
            title = community.name,
            onBack = onBack,
            onOpenMembers = { onOpenMembers(community.id) }
        )

        Box(Modifier.weight(1f)) {
            ChatBackdrop(accent)

            val positions = state.positions
            LazyColumn(
                state = listState,
                contentPadding = PaddingValues(vertical = HarvestTheme.Spacing.sm),
                modifier = Modifier.fillMaxSize()
            ) {
                if (state.hasMore) {
                    item("loadEarlier") {
                        LoadEarlierRow(
                            isLoading = state.isLoadingOlder,
                            onClick = { viewModel.loadOlder() }
                        )
                    }
                }

                if (state.messages.isEmpty()) {
                    item("empty") { CommunityEmptyState(onUseIcebreaker = { showPrompts = true }) }
                }

                itemsIndexed(state.messages) { message ->
                    val position = positions[message.id] ?: MessagePosition(false, true, true)

                    if (position.showsDateSeparator) {
                        MessageGrouping.date(message.createdAt)?.let { DateSeparator(it) }
                    }

                    val quoted = state.quotedMessage(message)
                    SwipeToReply(onReply = { viewModel.setReplyTarget(message) }) {
                    ChatBubble(
                        message = message,
                        sender = state.senders[message.senderId],
                        isMine = message.senderId == userId,
                        position = position,
                        accent = accent,
                        reactions = state.reactions[message.id].orEmpty(),
                        quoted = quoted,
                        quotedSenderName = quoted?.let { state.senders[it.senderId]?.nickname },
                        // Metadata once per run, matching iOS.
                        timeLabel = if (position.isLastInGroup) timeLabel(message) else "",
                        mentionNicknames = state.mentionedNicknames(message),
                        mentionsMe = message.mentions.orEmpty().contains(userId),
                        onLongPress = { reactingTo = message }
                    )
                    }
                }
            }
        }

        state.error?.let { error ->
            Text(
                text = error,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.error,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = HarvestTheme.Spacing.md, vertical = HarvestTheme.Spacing.xs)
            )
        }

        reactingTo?.let { target ->
            ReactionPicker(
                onPick = { emoji ->
                    viewModel.toggleReaction(target.id, emoji)
                    reactingTo = null
                },
                onDismiss = { reactingTo = null }
            )
        }

        state.replyTarget?.let { target ->
            ReplyBanner(target = target, onCancel = { viewModel.setReplyTarget(null) })
        }

        ChatComposer(
            text = state.draft,
            onTextChange = viewModel::updateDraft,
            accent = accent,
            placeholder = "Message ${community.name}",
            isSending = state.isSending,
            onSend = { viewModel.send() },
            accessory = {
                Icon(
                    imageVector = Icons.Filled.Lightbulb,
                    contentDescription = "Icebreakers",
                    tint = HarvestTheme.Colors.accent,
                    modifier = Modifier
                        .size(36.dp)
                        .clickable { showPrompts = true }
                        .padding(HarvestTheme.Spacing.xs)
                )
            }
        )
    }
}

/**
 * LazyColumn.items with the index available — the plain overload would need
 * the key lambda repeated at every call site.
 */
private inline fun androidx.compose.foundation.lazy.LazyListScope.itemsIndexed(
    messages: List<CommunityMessage>,
    crossinline content: @Composable (CommunityMessage) -> Unit
) {
    items(messages.size, key = { messages[it].id }) { index -> content(messages[index]) }
}

@Composable
private fun TopBar(title: String, onBack: () -> Unit, onOpenMembers: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineBlack)
            // Background reaches behind the status bar; the row sits below it.
            .statusBarsPadding()
            .padding(HarvestTheme.Spacing.md)
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Back",
            tint = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.clickable { onBack() }
        )
        Text(
            text = title,
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.weight(1f)
        )
        Icon(
            imageVector = Icons.Filled.Group,
            contentDescription = "Members",
            tint = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.clickable { onOpenMembers() }
        )
    }
}

/**
 * Port of ChatBackdrop.swift: the cream page warmed by two faint accent
 * glows. Deliberately static — no animation, so it costs nothing per frame.
 */
@Composable
private fun ChatBackdrop(accent: ChatAccent) {
    Box(Modifier.fillMaxSize().background(HarvestTheme.Colors.background)) {
        Box(
            Modifier.fillMaxSize().background(
                Brush.radialGradient(
                    colors = listOf(accent.base.copy(alpha = 0.07f), Color.Transparent),
                    radius = 340f
                )
            )
        )
        Box(
            Modifier.fillMaxSize().background(
                Brush.radialGradient(
                    colors = listOf(accent.deep.copy(alpha = 0.06f), Color.Transparent),
                    radius = 400f
                )
            )
        )
    }
}

@Composable
private fun ReactionPicker(onPick: (String) -> Unit, onDismiss: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineRaised)
            .padding(HarvestTheme.Spacing.md)
    ) {
        CommunityReaction.CURATED_EMOJI.forEach { emoji ->
            Text(
                text = emoji,
                style = HarvestTheme.Typography.bodyLarge,
                modifier = Modifier.clickable { onPick(emoji) }
            )
        }
        Spacer(Modifier.weight(1f))
        Text(
            text = "Cancel",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary,
            modifier = Modifier.clickable { onDismiss() }
        )
    }
}

@Composable
private fun ReplyBanner(target: CommunityMessage, onCancel: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(
                HarvestTheme.Colors.fieldGreenSoft,
                RoundedCornerShape(HarvestTheme.Radius.sm)
            )
            .padding(HarvestTheme.Spacing.sm)
    ) {
        Text(
            text = "Replying to: ${target.content.take(40)}",
            style = HarvestTheme.Typography.caption,
            color = HarvestTheme.Colors.fieldGreenLight,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = "Cancel",
            style = HarvestTheme.Typography.caption,
            fontWeight = FontWeight.SemiBold,
            color = HarvestTheme.Colors.fieldGreenLight,
            modifier = Modifier.clickable { onCancel() }
        )
    }
}

@Composable
private fun LoadEarlierRow(isLoading: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth()
            .padding(vertical = HarvestTheme.Spacing.xs),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                color = HarvestTheme.Colors.rose,
                strokeWidth = 2.dp,
                modifier = Modifier.size(18.dp)
            )
        } else {
            Row(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.clickable { onClick() }
            ) {
                Icon(
                    Icons.Filled.ArrowCircleUp,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.accent,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = "Load earlier messages",
                    style = HarvestTheme.Typography.caption,
                    color = HarvestTheme.Colors.accent
                )
            }
        }
    }
}

@Composable
private fun CommunityEmptyState(onUseIcebreaker: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = HarvestTheme.Spacing.xxl)
    ) {
        Icon(
            Icons.Filled.Forum,
            contentDescription = null,
            tint = HarvestTheme.Colors.rose,
            modifier = Modifier.size(32.dp)
        )
        Text(
            text = "Be the first to share something.",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary
        )
        HarvestButton(
            text = "Use an icebreaker",
            kind = HarvestButtonKind.SECONDARY,
            icon = Icons.Filled.Lightbulb,
            onClick = onUseIcebreaker
        )
    }
}

/** Port of PromptPicker in CommunityChatView.swift. */
@Composable
private fun PromptPicker(
    prompts: List<CommunityPrompt>,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(HarvestTheme.Colors.wineBlack)
                .statusBarsPadding()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Text(
                text = "Icebreakers",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = "Cancel",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.clickable { onDismiss() }
            )
        }

        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            contentPadding = PaddingValues(HarvestTheme.Spacing.md),
            modifier = Modifier.navigationBarsPadding()
        ) {
            items(prompts.size, key = { prompts[it].id }) { index ->
                val prompt = prompts[index]
                val shape = RoundedCornerShape(HarvestTheme.Radius.lg)
                Text(
                    text = prompt.text,
                    style = HarvestTheme.Typography.bodyRegular,
                    color = HarvestTheme.Colors.textPrimary,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(HarvestTheme.Colors.glassFill, shape)
                        .border(1.dp, HarvestTheme.Colors.border, shape)
                        .clickable { onPick(prompt.text) }
                        .padding(HarvestTheme.Spacing.md)
                )
            }
        }
    }
}

private fun timeLabel(message: CommunityMessage): String {
    val instant = MessageGrouping.date(message.createdAt) ?: return ""
    return DateTimeFormatter
        .ofLocalizedTime(FormatStyle.SHORT)
        .withZone(ZoneId.systemDefault())
        .format(instant)
}
