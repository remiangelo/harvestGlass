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
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import com.harvestglass.harvest.data.model.InboundLikeWithProfile
import com.harvestglass.harvest.data.model.SwipeAction
import com.harvestglass.harvest.ui.components.GlassBadge
import com.harvestglass.harvest.ui.profile.MemberProfileScreen
import com.harvestglass.harvest.ui.theme.HarvestTheme
import com.harvestglass.harvest.util.ObjectionableContent

/**
 * Port of Harvest/Views/Seeds/SeedsView.swift plus the whole inbox from
 * MindfulMessagesView — search, Likes You, New Matches and the merged message
 * list. All copy is verbatim.
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

    var openProfileId by remember { mutableStateOf<String?>(null) }

    openProfileId?.let { id ->
        MemberProfileScreen(
            profileId = id,
            viewerId = userId,
            onClose = {
                openProfileId = null
                // A Seed sent from here changes the sent list.
                viewModel.load(userId)
            }
        )
        return
    }

    SeedsContent(
        state = state,
        currentUserId = userId,
        onSegmentChange = viewModel::setSegment,
        onRequestKindChange = viewModel::setRequestKind,
        onSearchChange = viewModel::setSearch,
        onAccept = { viewModel.accept(it, userId) },
        onDecline = { viewModel.decline(it, userId) },
        onOpenConversation = onOpenConversation,
        onOpenProfile = { openProfileId = it },
        onAnswerLike = { like, action -> viewModel.answerInboundLike(like, userId, action) }
    )
}

@Composable
fun SeedsContent(
    state: SeedsUiState,
    currentUserId: String,
    onSegmentChange: (SeedsSegment) -> Unit,
    onRequestKindChange: (RequestKind) -> Unit,
    onSearchChange: (String) -> Unit = {},
    onAccept: (Seed) -> Unit,
    onDecline: (Seed) -> Unit,
    onOpenConversation: (String, String) -> Unit,
    onOpenProfile: (String) -> Unit = {},
    onAnswerLike: (InboundLikeWithProfile, SwipeAction) -> Unit = { _, _ -> }
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

            SeedsSegment.CONVERSATIONS -> Inbox(
                state = state,
                currentUserId = currentUserId,
                onSearchChange = onSearchChange,
                onOpenConversation = onOpenConversation,
                onOpenProfile = onOpenProfile,
                onAnswerLike = onAnswerLike
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

/**
 * The Conversations segment: iOS's MindfulMessagesView body, minus its own
 * navigation chrome — search, Likes You, New Matches, then Messages.
 */
@Composable
private fun Inbox(
    state: SeedsUiState,
    currentUserId: String,
    onSearchChange: (String) -> Unit,
    onOpenConversation: (String, String) -> Unit,
    onOpenProfile: (String) -> Unit,
    onAnswerLike: (InboundLikeWithProfile, SwipeAction) -> Unit
) {
    val rows = state.unifiedMessages

    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        contentPadding = PaddingValues(vertical = HarvestTheme.Spacing.sm)
    ) {
        item("search") {
            SearchBar(state.search, onSearchChange)
        }

        if (state.inboundLikes.isNotEmpty()) {
            item("likes-header") {
                InboxSectionTitle("Likes You (${state.inboundLikes.size})")
            }

            if (state.canSeeLikes) {
                items(state.inboundLikes, key = { "like-${it.id}" }) { like ->
                    InboundLikeRow(
                        like = like,
                        onOpen = { onOpenProfile(like.profile.id) },
                        onLikeBack = { onAnswerLike(like, SwipeAction.LIKE) },
                        onPass = { onAnswerLike(like, SwipeAction.NOPE) }
                    )
                }
            } else {
                item("likes-gate") { LikesGate() }
            }
        }

        if (state.newMatches.isNotEmpty()) {
            item("matches-header") { InboxSectionTitle("New Matches") }
            item("matches") {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
                    modifier = Modifier
                        .horizontalScroll(rememberScrollState())
                        .padding(horizontal = HarvestTheme.Spacing.md)
                ) {
                    state.newMatches.forEach { thread ->
                        NewMatchBubble(thread) { onOpenProfile(thread.match.profile.id) }
                    }
                }
            }
        }

        item("messages-header") { InboxSectionTitle("Messages") }

        if (rows.isEmpty()) {
            item("empty") {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = HarvestTheme.Spacing.xxl)
                ) {
                    Text(text = "\uD83C\uDF31", fontSize = 40.sp)
                    Text(
                        text = "No conversations yet",
                        style = HarvestTheme.Typography.h4,
                        color = HarvestTheme.Colors.textPrimary
                    )
                }
            }
        } else {
            items(rows, key = { it.conversationId }) { row ->
                Box(Modifier.padding(horizontal = HarvestTheme.Spacing.md)) {
                    InboxRowView(row) {
                        onOpenConversation(row.conversationId, row.profile.id)
                    }
                }
            }
        }
    }
}

@Composable
private fun InboxSectionTitle(title: String) {
    Text(
        text = title,
        style = HarvestTheme.Typography.h4,
        color = HarvestTheme.Colors.textPrimary,
        modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)
    )
}

@Composable
private fun SearchBar(query: String, onChange: (String) -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.md)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .padding(horizontal = HarvestTheme.Spacing.md)
            .fillMaxWidth()
            .background(HarvestTheme.Colors.blackSurface, shape)
            .border(1.dp, HarvestTheme.Colors.border, shape)
            .padding(HarvestTheme.Spacing.sm)
    ) {
        Icon(
            Icons.Filled.Search,
            contentDescription = null,
            tint = HarvestTheme.Colors.textOnBlack,
            modifier = Modifier.size(18.dp)
        )
        BasicTextField(
            value = query,
            onValueChange = onChange,
            singleLine = true,
            textStyle = LocalTextStyle.current.merge(
                TextStyle(color = HarvestTheme.Colors.textOnBlack)
            ),
            cursorBrush = SolidColor(HarvestTheme.Colors.textOnBlack),
            modifier = Modifier.weight(1f),
            decorationBox = { innerTextField ->
                Box(contentAlignment = Alignment.CenterStart) {
                    if (query.isEmpty()) {
                        Text(
                            text = "Search conversations",
                            style = HarvestTheme.Typography.bodyRegular,
                            color = HarvestTheme.Colors.textTertiary
                        )
                    }
                    innerTextField()
                }
            }
        )
    }
}

/**
 * "Likes You" predates Seeds and has no gate of its own now that
 * `can_see_likes` is gone — any paid plan sees it, which is what the old
 * column encoded.
 */
@Composable
private fun LikesGate() {
    val shape = RoundedCornerShape(HarvestTheme.Radius.xl)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.md,
            Alignment.CenterVertically
        ),
        modifier = Modifier
            .padding(horizontal = HarvestTheme.Spacing.md)
            .fillMaxWidth()
            .height(220.dp)
            .background(HarvestTheme.Colors.blackSurface, shape)
            .border(1.dp, HarvestTheme.Colors.border, shape)
            .padding(HarvestTheme.Spacing.lg)
    ) {
        Icon(
            Icons.Filled.Lock,
            contentDescription = null,
            tint = HarvestTheme.Colors.primary,
            modifier = Modifier.size(32.dp)
        )
        Text(
            text = "See who likes you",
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            textAlign = TextAlign.Center
        )
        Text(
            text = "Unlock with Gold",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary
        )
    }
}

@Composable
private fun InboundLikeRow(
    like: InboundLikeWithProfile,
    onOpen: () -> Unit,
    onLikeBack: () -> Unit,
    onPass: () -> Unit
) {
    Box(Modifier.padding(horizontal = HarvestTheme.Spacing.md)) {
        GlassCard(
            padding = HarvestTheme.Spacing.sm,
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onOpen() }
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
            ) {
                RoundPhoto(like.profile.primaryPhoto, like.profile.displayName, 50.dp)

                Column(Modifier.weight(1f)) {
                    Text(
                        text = like.profile.displayName,
                        style = HarvestTheme.Typography.bodyRegular,
                        fontWeight = FontWeight.SemiBold,
                        color = HarvestTheme.Colors.textPrimary
                    )
                    Text(
                        text = if (like.swipe.action == SwipeAction.SUPER_LIKE) {
                            "Super liked you"
                        } else {
                            "Liked you"
                        },
                        style = HarvestTheme.Typography.bodySmall,
                        color = HarvestTheme.Colors.textSecondary,
                        maxLines = 1
                    )
                }

                if (like.swipe.action == SwipeAction.SUPER_LIKE) {
                    GlassBadge(text = "Super Like", color = HarvestTheme.Colors.accent)
                }

                // iOS answers from the profile sheet; the row carries the two
                // actions directly so a reply is one tap, not three.
                Text(
                    text = "Pass",
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textTertiary,
                    modifier = Modifier
                        .clickable { onPass() }
                        .padding(HarvestTheme.Spacing.xs)
                )
                Text(
                    text = "Like back",
                    style = HarvestTheme.Typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = HarvestTheme.Colors.accent,
                    modifier = Modifier
                        .clickable { onLikeBack() }
                        .padding(HarvestTheme.Spacing.xs)
                )
            }
        }
    }
}

@Composable
private fun NewMatchBubble(thread: MatchThread, onOpen: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier
            .width(80.dp)
            .clickable { onOpen() }
    ) {
        Box(
            Modifier
                .size(68.dp)
                .clip(CircleShape)
                .border(2.dp, HarvestTheme.Colors.accent, CircleShape)
        ) {
            RoundPhoto(thread.match.profile.primaryPhoto, thread.match.profile.displayName, 68.dp)
        }
        Text(
            text = thread.match.profile.displayName,
            style = HarvestTheme.Typography.caption,
            color = HarvestTheme.Colors.textPrimary,
            maxLines = 1,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun InboxRowView(row: InboxRow, onOpen: () -> Unit) {
    val preview = row.lastMessagePreview.orEmpty()

    // Masks a preview that trips the local mindful-messaging keyword check,
    // mirroring the in-chat blur-on-receive.
    val masked = preview.isNotEmpty() && ObjectionableContent.contains(preview)

    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onOpen() }
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            RoundPhoto(row.profile.primaryPhoto, row.profile.displayName, 55.dp)

            Column(Modifier.weight(1f)) {
                Text(
                    text = row.profile.displayName,
                    style = HarvestTheme.Typography.cardTitle,
                    fontWeight = FontWeight.SemiBold,
                    color = HarvestTheme.Colors.textPrimary
                )
                Text(
                    text = if (masked) "Message hidden \u2014 tap to view" else preview,
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary,
                    maxLines = 1
                )
            }

            if (row.hasReplyHighlight) {
                Box(
                    Modifier
                        .size(10.dp)
                        .background(HarvestTheme.Colors.rose, CircleShape)
                )
            }
        }
    }
}

@Composable
private fun RoundPhoto(url: String?, name: String, size: androidx.compose.ui.unit.Dp) {
    if (url != null) {
        AsyncImage(
            model = url,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(size).clip(CircleShape)
        )
    } else {
        Box(
            Modifier
                .size(size)
                .background(HarvestTheme.Colors.wineRaised, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = name.firstOrNull()?.uppercase() ?: "?",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textSecondary
            )
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
