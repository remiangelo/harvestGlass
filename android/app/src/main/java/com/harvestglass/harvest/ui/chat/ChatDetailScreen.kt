package com.harvestglass.harvest.ui.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.harvestglass.harvest.data.model.Message
import com.harvestglass.harvest.ui.components.chat.ChatAccent
import com.harvestglass.harvest.ui.components.chat.DateSeparator
import com.harvestglass.harvest.ui.components.chat.MessageGrouping
import com.harvestglass.harvest.ui.components.chat.MessagePosition
import com.harvestglass.harvest.ui.theme.HarvestTheme
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Port of Harvest/Views/Chat/ChatDetailView.swift.
 *
 * Seed conversations use the ROSE accent; community rooms use green. The
 * transcript machinery (grouping, date separators, composer) is shared with
 * the community room built in P1.
 *
 * Not wired here, and deliberately: the mindful pre-send warning and the
 * safety "ready to move" gate, both OpenAI-backed and owned by the AI
 * subsystem. Blur-on-receive IS present — it runs on the local keyword path.
 */
@Composable
fun ChatDetailScreen(
    conversationId: String,
    userId: String,
    partnerUserId: String,
    onBack: () -> Unit,
    viewModel: ChatViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val accent = ChatAccent.Rose

    LaunchedEffect(conversationId) { viewModel.start(conversationId, userId, partnerUserId) }

    // Follow the newest message as it arrives.
    LaunchedEffect(state.messages.size) {
        if (state.messages.isNotEmpty()) {
            listState.animateScrollToItem(state.messages.lastIndex)
        }
    }

    // Mark incoming messages read once they are on screen.
    LaunchedEffect(state.messages.size) {
        state.messages
            .filter { !it.isSentBy(userId) && !it.isRead }
            .forEach { viewModel.markRead(it.id) }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
            .imePadding()
    ) {
        ChatTopBar(
            title = state.partner?.nickname ?: "Chat",
            photoUrl = state.partner?.photos?.firstOrNull(),
            onBack = onBack,
            onReport = {
                viewModel.report(partnerUserId, "Reported from chat", "Reported from the chat menu.")
            },
            onBlock = { viewModel.block(partnerUserId) }
        )

        Box(Modifier.weight(1f)) {
            ChatBackdrop(accent)

            val dates = state.messages.map { MessageGrouping.date(it.createdAt) }
            LazyColumn(
                state = listState,
                contentPadding = PaddingValues(vertical = HarvestTheme.Spacing.sm),
                modifier = Modifier.fillMaxSize()
            ) {
                items(state.messages.size, key = { state.messages[it].id }) { index ->
                    val message = state.messages[index]
                    val position = MessageGrouping.position(
                        previousSender = state.messages.getOrNull(index - 1)?.senderId,
                        previousDate = dates.getOrNull(index - 1),
                        currentSender = message.senderId,
                        currentDate = dates[index],
                        nextSender = state.messages.getOrNull(index + 1)?.senderId,
                        nextDate = dates.getOrNull(index + 1)
                    )

                    if (position.showsDateSeparator) {
                        dates[index]?.let { DateSeparator(it) }
                    }

                    MessageBubble(
                        message = message,
                        isSent = message.isSentBy(userId),
                        position = position,
                        // Metadata once per run, matching iOS.
                        timeLabel = if (position.isLastInGroup) timeLabel(message) else "",
                        accent = accent
                    )
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
                    .padding(
                        horizontal = HarvestTheme.Spacing.md,
                        vertical = HarvestTheme.Spacing.xs
                    )
            )
        }

        com.harvestglass.harvest.ui.components.chat.ChatComposer(
            text = state.draft,
            onTextChange = viewModel::onDraftChange,
            accent = accent,
            placeholder = "Message ${state.partner?.nickname ?: ""}".trim(),
            isSending = state.isSending,
            onSend = { viewModel.send() }
        )
    }
}

private fun timeLabel(message: Message): String {
    val instant = MessageGrouping.date(message.createdAt) ?: return ""
    return DateTimeFormatter
        .ofLocalizedTime(FormatStyle.SHORT)
        .withZone(ZoneId.systemDefault())
        .format(instant)
}

@Composable
private fun ChatTopBar(
    title: String,
    photoUrl: String?,
    onBack: () -> Unit,
    onReport: () -> Unit,
    onBlock: () -> Unit
) {
    var menuOpen by remember { mutableStateOf(false) }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineBlack)
            .padding(HarvestTheme.Spacing.md)
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Back",
            tint = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.clickable { onBack() }
        )

        if (photoUrl != null) {
            AsyncImage(
                model = photoUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(28.dp).clip(CircleShape)
            )
        }

        Text(
            text = title,
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.weight(1f)
        )

        Box {
            Icon(
                imageVector = Icons.Filled.MoreVert,
                contentDescription = "More",
                tint = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.clickable { menuOpen = true }
            )
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text("Report") },
                    onClick = { menuOpen = false; onReport() }
                )
                DropdownMenuItem(
                    text = { Text("Block") },
                    onClick = { menuOpen = false; onBlock() }
                )
            }
        }
    }
}

/** Port of ChatBackdrop.swift with the rose accent. Static — costs nothing per frame. */
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
