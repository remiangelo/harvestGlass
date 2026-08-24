package com.harvestglass.harvest.ui.gardener

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.harvestglass.harvest.ui.components.chat.ChatAccent
import com.harvestglass.harvest.ui.components.chat.ChatComposer
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Gardener/GardenerChatView.swift.
 *
 * A plain two-party transcript: no reactions, replies or realtime, because
 * the other party is the model. The daily quiz and the screenshot review
 * are not ported — see the checklist.
 */
@Composable
fun GardenerScreen(
    userId: String,
    viewModel: GardenerViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val accent = ChatAccent.Rose

    LaunchedEffect(userId) { viewModel.load(userId) }

    LaunchedEffect(state.messages.size) {
        if (state.messages.isNotEmpty()) {
            listState.animateScrollToItem(state.messages.lastIndex)
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
            .imePadding()
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier
                .fillMaxWidth()
                .background(HarvestTheme.Colors.wineBlack)
                .padding(HarvestTheme.Spacing.md)
        ) {
            Box(
                Modifier
                    .size(32.dp)
                    .background(HarvestTheme.Colors.primaryGradient, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.Spa,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.pureWhite,
                    modifier = Modifier.size(18.dp)
                )
            }
            Text(
                text = "The Gardener",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary
            )
        }

        LazyColumn(
            state = listState,
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            contentPadding = PaddingValues(HarvestTheme.Spacing.md),
            modifier = Modifier.weight(1f)
        ) {
            items(state.messages.size, key = { state.messages[it].id }) { index ->
                val message = state.messages[index]
                GardenerBubble(
                    text = message.content,
                    isMine = message.role != "assistant",
                    accent = accent
                )
            }

            if (state.isThinking) {
                item("thinking") {
                    Text(
                        text = "The Gardener is thinking…",
                        style = HarvestTheme.Typography.caption,
                        color = HarvestTheme.Colors.textTertiary,
                        modifier = Modifier.padding(start = HarvestTheme.Spacing.sm)
                    )
                }
            }
        }

        state.error?.let {
            Text(
                text = it,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.error,
                modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)
            )
        }

        ChatComposer(
            text = state.draft,
            onTextChange = viewModel::updateDraft,
            accent = accent,
            placeholder = "Ask The Gardener…",
            isSending = state.isThinking,
            onSend = { viewModel.send(userId) }
        )
    }
}

@Composable
private fun GardenerBubble(text: String, isMine: Boolean, accent: ChatAccent) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.lg)
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = if (isMine) Arrangement.End else Arrangement.Start
    ) {
        Text(
            text = text,
            style = HarvestTheme.Typography.bodyRegular,
            color = if (isMine) HarvestTheme.Colors.textInverse else HarvestTheme.Colors.textPrimary,
            textAlign = TextAlign.Start,
            modifier = Modifier
                .widthIn(max = 300.dp)
                .clip(shape)
                .then(
                    if (isMine) {
                        Modifier.background(
                            Brush.linearGradient(listOf(accent.base, accent.deep)),
                            shape
                        ).border(1.dp, Color.White.copy(alpha = 0.16f), shape)
                    } else {
                        Modifier.background(HarvestTheme.Colors.wineCard, shape)
                            .border(1.dp, HarvestTheme.Colors.border, shape)
                    }
                )
                .padding(horizontal = HarvestTheme.Spacing.md, vertical = 10.dp)
        )
    }
}
