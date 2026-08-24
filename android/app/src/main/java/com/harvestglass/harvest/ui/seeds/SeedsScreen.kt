package com.harvestglass.harvest.ui.seeds

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.harvestglass.harvest.data.model.ConversationWithProfile
import com.harvestglass.harvest.data.model.Seed
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme
import com.harvestglass.harvest.util.ObjectionableContent

/**
 * Port of Harvest/Views/Seeds/SeedsView.swift plus the conversation list from
 * MindfulMessagesView. All copy is verbatim.
 */
@Composable
fun SeedsScreen(
    userId: String,
    onOpenConversation: (conversationId: String, partnerUserId: String) -> Unit,
    viewModel: SeedsViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(userId) { viewModel.load(userId) }

    // Accepting a Seed routes straight into the new conversation.
    LaunchedEffect(state.openedConversationId) {
        val id = state.openedConversationId
        val partner = state.openedPartnerUserId
        if (id != null && partner != null) {
            onOpenConversation(id, partner)
            viewModel.clearOpenedConversation()
        }
    }

    SeedsContent(
        state = state,
        currentUserId = userId,
        onSegmentChange = viewModel::setSegment,
        onRequestKindChange = viewModel::setRequestKind,
        onAccept = { viewModel.accept(it, userId) },
        onDecline = { viewModel.decline(it, userId) },
        onOpenConversation = onOpenConversation
    )
}

@Composable
fun SeedsContent(
    state: SeedsUiState,
    currentUserId: String,
    onSegmentChange: (SeedsSegment) -> Unit,
    onRequestKindChange: (RequestKind) -> Unit,
    onAccept: (Seed) -> Unit,
    onDecline: (Seed) -> Unit,
    onOpenConversation: (String, String) -> Unit
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        Text(
            text = "Seeds",
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.padding(HarvestTheme.Spacing.md)
        )

        // iOS pads this picker on all sides; the gap below it separates the
        // two segment rows when Requests is selected.
        Box(Modifier.padding(bottom = HarvestTheme.Spacing.md)) {
            SegmentedPair(
                leftLabel = "Requests",
                rightLabel = "Conversations",
                leftSelected = state.segment == SeedsSegment.REQUESTS,
                onLeft = { onSegmentChange(SeedsSegment.REQUESTS) },
                onRight = { onSegmentChange(SeedsSegment.CONVERSATIONS) }
            )
        }

        when (state.segment) {
            SeedsSegment.REQUESTS -> RequestsList(
                state = state,
                onRequestKindChange = onRequestKindChange,
                onAccept = onAccept,
                onDecline = onDecline
            )

            SeedsSegment.CONVERSATIONS -> ConversationsList(
                conversations = state.conversations,
                currentUserId = currentUserId,
                onOpenConversation = onOpenConversation
            )
        }
    }
}

@Composable
private fun RequestsList(
    state: SeedsUiState,
    onRequestKindChange: (RequestKind) -> Unit,
    onAccept: (Seed) -> Unit,
    onDecline: (Seed) -> Unit
) {
    Column {
        Box(Modifier.padding(bottom = HarvestTheme.Spacing.sm)) {
            SegmentedPair(
                leftLabel = "Received",
                rightLabel = "Sent",
                leftSelected = state.requestKind == RequestKind.RECEIVED,
                onLeft = { onRequestKindChange(RequestKind.RECEIVED) },
                onRight = { onRequestKindChange(RequestKind.SENT) }
            )
        }

        val items = state.visibleRequests
        if (items.isEmpty()) {
            RequestsEmptyState(state.requestKind)
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
                contentPadding = PaddingValues(HarvestTheme.Spacing.md)
            ) {
                items(items, key = { it.id }) { seed ->
                    SeedRow(
                        seed = seed,
                        isReceived = state.requestKind == RequestKind.RECEIVED,
                        onAccept = { onAccept(seed) },
                        onDecline = { onDecline(seed) }
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
    }
}

@Composable
private fun SeedRow(
    seed: Seed,
    isReceived: Boolean,
    onAccept: () -> Unit,
    onDecline: () -> Unit
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
            Text(
                text = seed.openingMessage,
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textPrimary
            )

            if (isReceived) {
                Row(horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                    HarvestButton(
                        text = "Let It Grow",
                        kind = HarvestButtonKind.PRIMARY,
                        onClick = onAccept
                    )
                    HarvestButton(
                        text = "No Thanks",
                        kind = HarvestButtonKind.SECONDARY,
                        onClick = onDecline
                    )
                }
            } else {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Filled.Schedule,
                        contentDescription = null,
                        tint = HarvestTheme.Colors.textSecondary,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = "Pending",
                        style = HarvestTheme.Typography.caption,
                        color = HarvestTheme.Colors.textSecondary
                    )
                }
            }
        }
    }
}

@Composable
private fun RequestsEmptyState(kind: RequestKind) {
    val received = kind == RequestKind.RECEIVED
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = HarvestTheme.Spacing.xxl)
    ) {
        Text(text = "🌱", fontSize = 40.sp)
        Text(
            text = if (received) "No new Seeds yet" else "No pending sent Seeds",
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary
        )
        Text(
            text = if (received) {
                "When someone sends you a Seed, it'll appear here."
            } else {
                "Seeds you send will wait here until they're accepted."
            },
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun ConversationsList(
    conversations: List<ConversationWithProfile>,
    currentUserId: String,
    onOpenConversation: (String, String) -> Unit
) {
    if (conversations.isEmpty()) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = HarvestTheme.Spacing.xxl)
        ) {
            Text(text = "🌱", fontSize = 40.sp)
            Text(
                text = "No conversations yet",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary
            )
        }
        return
    }

    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        contentPadding = PaddingValues(HarvestTheme.Spacing.md)
    ) {
        items(conversations, key = { it.id }) { item ->
            ConversationRow(item, currentUserId, onOpenConversation)
        }
    }
}

@Composable
private fun ConversationRow(
    item: ConversationWithProfile,
    currentUserId: String,
    onOpenConversation: (String, String) -> Unit
) {
    val partnerId = item.conversation.otherUserId(currentUserId) ?: item.profile.id
    val preview = item.conversation.lastMessagePreview.orEmpty()

    // Masks a preview that trips the local mindful-messaging keyword check,
    // mirroring the in-chat blur-on-receive.
    val masked = preview.isNotEmpty() && ObjectionableContent.contains(preview)

    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onOpenConversation(item.conversation.id, partnerId) }
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val photo = item.profile.photos?.firstOrNull()
            if (photo != null) {
                AsyncImage(
                    model = photo,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.size(48.dp).clip(CircleShape)
                )
            } else {
                Box(
                    Modifier
                        .size(48.dp)
                        .background(HarvestTheme.Colors.wineRaised, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = item.profile.nickname?.firstOrNull()?.uppercase() ?: "?",
                        style = HarvestTheme.Typography.h4,
                        color = HarvestTheme.Colors.textSecondary
                    )
                }
            }

            Column(Modifier.weight(1f)) {
                Text(
                    text = item.profile.nickname ?: "Member",
                    style = HarvestTheme.Typography.cardTitle,
                    fontWeight = FontWeight.SemiBold,
                    color = HarvestTheme.Colors.textPrimary
                )
                Text(
                    text = if (masked) "Message hidden — tap to view" else preview,
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary,
                    maxLines = 1
                )
            }

            if (item.hasReplyHighlight) {
                Box(
                    Modifier
                        .size(10.dp)
                        .background(HarvestTheme.Colors.rose, CircleShape)
                )
            }
        }
    }
}

/** Stands in for the iOS segmented Picker. */
@Composable
private fun SegmentedPair(
    leftLabel: String,
    rightLabel: String,
    leftSelected: Boolean,
    onLeft: () -> Unit,
    onRight: () -> Unit
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = HarvestTheme.Spacing.md)
    ) {
        Segment(leftLabel, leftSelected, Modifier.weight(1f), onLeft)
        Segment(rightLabel, !leftSelected, Modifier.weight(1f), onRight)
    }
}

@Composable
private fun Segment(label: String, isSelected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.sm)
    Text(
        text = label,
        style = HarvestTheme.Typography.bodySmall,
        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
        color = if (isSelected) HarvestTheme.Colors.textOnRedPrimary else HarvestTheme.Colors.textPrimary,
        textAlign = TextAlign.Center,
        modifier = modifier
            .background(
                if (isSelected) HarvestTheme.Colors.primary else HarvestTheme.Colors.formSurface,
                shape
            )
            .border(1.dp, HarvestTheme.Colors.formBorder, shape)
            .clickable { onClick() }
            .padding(vertical = HarvestTheme.Spacing.sm)
    )
}
