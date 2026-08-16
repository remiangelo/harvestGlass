package com.harvestglass.harvest.ui.field

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.Forum
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.SubcomposeAsyncImage
import com.harvestglass.harvest.data.model.Community
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Field/FieldView.swift. All copy is verbatim.
 *
 * Split stateful/stateless so FieldContent is testable without Hilt.
 */
@Composable
fun FieldScreen(
    userId: String,
    onOpenRoom: (Community) -> Unit,
    viewModel: FieldViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(userId) { viewModel.load(userId) }

    FieldContent(
        state = state,
        onToggle = { viewModel.toggleJoin(it, userId) },
        onOpenRoom = onOpenRoom
    )
}

@Composable
fun FieldContent(
    state: FieldUiState,
    onToggle: (Community) -> Unit,
    onOpenRoom: (Community) -> Unit
) {
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        contentPadding = PaddingValues(HarvestTheme.Spacing.md),
        modifier = Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        item { EventsComingSoonBanner() }

        item {
            Text(
                text = "Join the spaces where you're hoping to grow connection.",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textSecondary,
                modifier = Modifier.fillMaxWidth()
            )
        }

        if (state.available.isEmpty() && !state.isLoading) {
            item { EmptyState() }
        }

        items(state.available, key = { it.id }) { community ->
            CommunityCard(
                community = community,
                isJoined = state.isJoined(community),
                onToggle = { onToggle(community) },
                onOpen = { onOpenRoom(community) }
            )
        }
    }
}

@Composable
private fun EmptyState() {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = HarvestTheme.Spacing.sm)
        ) {
            Icon(
                Icons.Filled.Eco,
                contentDescription = null,
                tint = HarvestTheme.Colors.rose,
                modifier = Modifier.size(36.dp)
            )
            Text(
                text = "No spaces yet",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary
            )
            Text(
                text = "Update your relationship status in Profile to unlock connection spaces.",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun CommunityCard(
    community: Community,
    isJoined: Boolean,
    onToggle: () -> Unit,
    onOpen: () -> Unit
) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.xl)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(HarvestTheme.Colors.wineCard, shape)
            .border(
                1.dp,
                if (isJoined) HarvestTheme.Colors.fieldGreenBorder else HarvestTheme.Colors.border,
                shape
            )
            .then(if (isJoined) Modifier.clickable { onOpen() } else Modifier)
    ) {
        Banner(community)
        Details(community, isJoined, onToggle)
    }
}

@Composable
private fun Banner(community: Community) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(110.dp)
    ) {
        if (community.imageUrl != null) {
            SubcomposeAsyncImage(
                model = community.imageUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                loading = { BannerPlaceholder() },
                error = { BannerPlaceholder() },
                modifier = Modifier.fillMaxSize()
            )
        } else {
            BannerPlaceholder()
        }

        // Note: 0.85, deliberately stronger than the shared overlayGradient's 0.65.
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Transparent, HarvestTheme.Colors.photoScrim.copy(alpha = 0.85f))
                    )
                )
        )

        Text(
            text = community.name,
            style = HarvestTheme.Typography.h4,
            // Sits on the photo scrim, not the page — stays white.
            color = HarvestTheme.Colors.textInverse,
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(HarvestTheme.Spacing.md)
        )
    }
}

@Composable
private fun BannerPlaceholder() {
    Box(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.wineRaised),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            Icons.Filled.Eco,
            contentDescription = null,
            tint = HarvestTheme.Colors.fieldGreen.copy(alpha = 0.4f),
            modifier = Modifier.size(30.dp)
        )
    }
}

@Composable
private fun Details(community: Community, isJoined: Boolean, onToggle: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        modifier = Modifier
            .fillMaxWidth()
            .padding(HarvestTheme.Spacing.md)
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
            modifier = Modifier.weight(1f)
        ) {
            community.description?.let {
                Text(
                    text = it,
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary
                )
            }

            community.memberCount?.takeIf { it > 0 }?.let { count ->
                LabelRow(
                    icon = Icons.Filled.Eco,
                    text = "$count member" + if (count == 1) "" else "s"
                )
            }

            if (isJoined) {
                Box(Modifier.padding(top = HarvestTheme.Spacing.xxs)) {
                    LabelRow(icon = Icons.Filled.Forum, text = "Tap to open room")
                }
            }
        }

        if (isJoined) {
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = HarvestTheme.Colors.textTertiary,
                modifier = Modifier.padding(top = HarvestTheme.Spacing.xxs)
            )
        } else {
            val pill = RoundedCornerShape(percent = 50)
            Text(
                text = "Join",
                style = HarvestTheme.Typography.bodySmall,
                fontWeight = FontWeight.SemiBold,
                // White on the red capsule — textPrimary is dark now.
                color = HarvestTheme.Colors.textOnRedPrimary,
                modifier = Modifier
                    .clip(pill)
                    .background(HarvestTheme.Colors.rose, pill)
                    .clickable { onToggle() }
                    .padding(
                        horizontal = HarvestTheme.Spacing.md,
                        vertical = HarvestTheme.Spacing.sm
                    )
            )
        }
    }
}

@Composable
private fun LabelRow(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = HarvestTheme.Colors.accent,
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = text,
            style = HarvestTheme.Typography.caption,
            color = HarvestTheme.Colors.accent
        )
    }
}
