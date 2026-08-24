package com.harvestglass.harvest.ui.gardener

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PhotoLibrary
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.harvestglass.harvest.ui.components.chat.ChatAccent
import com.harvestglass.harvest.ui.components.chat.ChatComposer
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** iOS turns the character counter amber below this many characters left. */
private const val LOW_BUDGET_WARNING = 500

/**
 * Port of Harvest/Views/Gardener/GardenerChatView.swift.
 *
 * A plain two-party transcript: no reactions, replies or realtime, because the
 * other party is the model. Chat characters and screenshot reviews are separate
 * daily budgets, so the composer only locks outright once both are spent.
 */
@Composable
fun GardenerScreen(
    userId: String,
    viewModel: GardenerViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val accent = ChatAccent.Rose
    val context = LocalContext.current

    // ImageOnly, not a screenshots-only filter: a screenshot someone was *sent*
    // isn't tagged as one, and the refusal path has to stay reachable for
    // images that genuinely aren't conversations.
    val pickImage = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? -> if (uri != null) viewModel.stageScreenshot(uri) }

    LaunchedEffect(userId) {
        viewModel.load(userId)
        viewModel.checkDailyQuiz(userId)
    }

    LaunchedEffect(state.messages.size) {
        if (state.messages.isNotEmpty()) {
            listState.animateScrollToItem(state.messages.lastIndex)
        }
    }

    val quiz = state.dailyQuiz
    if (quiz != null && state.showDailyQuiz) {
        DailyQuizSheet(
            quiz = quiz,
            isSubmitting = state.isSubmittingQuiz,
            onAnswer = { viewModel.submitQuizAnswer(userId, it) },
            onDismiss = { viewModel.dismissDailyQuiz() }
        )
        return
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

        if (state.isFullyLocked) {
            AllowanceSpentBar()
        } else {
            state.pendingScreenshot?.let { uri ->
                ScreenshotPreview(uri) { viewModel.clearScreenshot() }
            }

            ChatComposer(
                text = state.draft,
                onTextChange = viewModel::updateDraft,
                accent = accent,
                placeholder = if (state.hasPendingScreenshot) {
                    "Add a note (optional)…"
                } else {
                    "Ask The Gardener…"
                },
                isSending = state.isThinking,
                // Out of characters still leaves a staged screenshot sendable
                // — a different budget pays for it.
                sendsWithoutText = state.hasPendingScreenshot,
                onSend = {
                    if (state.hasPendingScreenshot) {
                        viewModel.sendScreenshot(context, userId)
                    } else if (!state.isAtCharacterLimit) {
                        viewModel.send(userId)
                    }
                },
                accessory = {
                    Icon(
                        Icons.Filled.PhotoLibrary,
                        contentDescription = "Send a screenshot for review",
                        tint = if (state.isAtScreenshotLimit) {
                            HarvestTheme.Colors.textTertiary
                        } else {
                            HarvestTheme.Colors.accent
                        },
                        modifier = Modifier
                            .padding(bottom = 8.dp)
                            .size(24.dp)
                            .clickable(
                                enabled = !state.isThinking && !state.isAtScreenshotLimit
                            ) {
                                pickImage.launch(
                                    PickVisualMediaRequest(
                                        ActivityResultContracts.PickVisualMedia.ImageOnly
                                    )
                                )
                            }
                    )
                },
                sendFooter = {
                    Text(
                        text = if (state.hasPendingScreenshot) {
                            "${state.remainingScreenshots}📷"
                        } else {
                            "${state.remainingCharacters}"
                        },
                        style = HarvestTheme.Typography.caption.copy(fontSize = 9.sp),
                        color = if (state.remainingCharacters < LOW_BUDGET_WARNING) {
                            HarvestTheme.Colors.warning
                        } else {
                            HarvestTheme.Colors.textTertiary
                        }
                    )
                }
            )
        }
    }
}

/** Both budgets spent: iOS swaps the whole composer for this row. */
@Composable
private fun AllowanceSpentBar() {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineBlack)
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Bottom))
            .padding(horizontal = HarvestTheme.Spacing.md, vertical = HarvestTheme.Spacing.sm)
    ) {
        Icon(
            Icons.Filled.Lock,
            contentDescription = null,
            tint = HarvestTheme.Colors.textTertiary,
            modifier = Modifier.size(18.dp)
        )
        Text(
            text = "You've used today's Gardener allowance. Upgrade for more!",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary
        )
    }
}

/** The staged screenshot, captionable or removable before it's sent. */
@Composable
private fun ScreenshotPreview(uri: Uri, onRemove: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineBlack)
            .padding(horizontal = HarvestTheme.Spacing.md, vertical = HarvestTheme.Spacing.xs)
    ) {
        AsyncImage(
            model = uri,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(HarvestTheme.Radius.sm))
        )
        Column(
            verticalArrangement = Arrangement.spacedBy(1.dp),
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = "Screenshot ready",
                style = HarvestTheme.Typography.caption,
                fontWeight = FontWeight.SemiBold,
                color = HarvestTheme.Colors.textPrimary
            )
            Text(
                text = "Not saved — reviewed once, then discarded.",
                style = HarvestTheme.Typography.caption,
                color = HarvestTheme.Colors.textSecondary
            )
        }
        Icon(
            Icons.Filled.Cancel,
            contentDescription = "Remove screenshot",
            tint = HarvestTheme.Colors.textTertiary,
            modifier = Modifier
                .size(20.dp)
                .clickable { onRemove() }
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
