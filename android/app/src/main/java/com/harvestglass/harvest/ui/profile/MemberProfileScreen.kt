package com.harvestglass.harvest.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.QueryStats
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.harvestglass.harvest.ui.components.ChipView
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.ReportSheet
import com.harvestglass.harvest.ui.components.ValuesRadarCard
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Discover/ProfileDetailView.swift — someone else's
 * profile, and the only place a Seed is sent from.
 *
 * `showSeedAction` is iOS's `showSwipeActions`: it hides the Send a Seed
 * button when you already have a thread with this person.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MemberProfileScreen(
    profileId: String,
    viewerId: String,
    onClose: () -> Unit,
    showSeedAction: Boolean = true,
    onOpenCompatibility: ((String) -> Unit)? = null,
    viewModel: MemberProfileViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var showReport by remember { mutableStateOf(false) }
    var showBlockConfirm by remember { mutableStateOf(false) }
    var showSendSeed by remember { mutableStateOf(false) }

    LaunchedEffect(profileId) { viewModel.load(profileId, viewerId) }

    // Blocking removes them from every feed, so there is nothing left to show.
    LaunchedEffect(state.blocked) { if (state.blocked) onClose() }

    val profile = state.profile

    if (showReport && profile != null) {
        ReportSheet(
            onSubmit = { category, description, target ->
                viewModel.report(viewerId, profile.id, category, description, target)
            },
            onDismiss = { showReport = false }
        )
        return
    }

    if (showSendSeed && profile != null) {
        SendSeedSheet(
            recipientName = profile.nickname ?: profile.displayName,
            sentToday = state.seedsSentToday,
            limit = state.seedLimit,
            isSending = state.isSending,
            error = state.error,
            onSend = { message -> viewModel.sendSeed(viewerId, profile.id, message) },
            onDismiss = { showSendSeed = false }
        )

        // The sheet closes itself once the Seed lands.
        LaunchedEffect(state.seedSent) {
            if (state.seedSent) {
                showSendSeed = false
                viewModel.clearSeedSent()
            }
        }
        return
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) {
            val photos = profile?.photos.orEmpty()
            if (photos.isNotEmpty()) {
                val pagerState = rememberPagerState(pageCount = { photos.size })
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(450.dp)
                ) { page ->
                    AsyncImage(
                        model = photos[page],
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )
                }

                if (photos.size > 1) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = HarvestTheme.Spacing.sm)
                    ) {
                        repeat(photos.size) { index ->
                            Box(
                                Modifier
                                    .size(6.dp)
                                    .background(
                                        if (index == pagerState.currentPage) {
                                            HarvestTheme.Colors.primary
                                        } else {
                                            HarvestTheme.Colors.textTertiary.copy(alpha = 0.4f)
                                        },
                                        CircleShape
                                    )
                            )
                        }
                    }
                }
            } else {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(450.dp)
                        .background(HarvestTheme.Colors.divider),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Filled.Person,
                        contentDescription = null,
                        tint = HarvestTheme.Colors.textTertiary,
                        modifier = Modifier.size(60.dp)
                    )
                }
            }

            Column(
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
                modifier = Modifier.padding(
                    start = HarvestTheme.Spacing.md,
                    end = HarvestTheme.Spacing.md,
                    top = HarvestTheme.Spacing.lg
                )
            ) {
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
                ) {
                    Text(
                        text = profile?.displayName.orEmpty(),
                        style = HarvestTheme.Typography.h1,
                        color = HarvestTheme.Colors.textPrimary
                    )
                    profile?.age?.let {
                        Text(
                            text = "$it",
                            style = HarvestTheme.Typography.h2,
                            color = HarvestTheme.Colors.textSecondary
                        )
                    }
                }

                if (profile?.showValuesBrought != false && state.valuesBrought.isNotEmpty()) {
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)
                    ) {
                        state.valuesBrought.forEach { ChipView(title = it.name) }
                    }
                }

                profile?.location?.takeIf { it.isNotEmpty() }?.let { location ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            Icons.Filled.LocationOn,
                            contentDescription = null,
                            tint = HarvestTheme.Colors.primary,
                            modifier = Modifier.size(14.dp)
                        )
                        Text(
                            text = location,
                            style = HarvestTheme.Typography.bodySmall,
                            color = HarvestTheme.Colors.textSecondary
                        )
                    }
                }

                profile?.bio?.takeIf { it.isNotEmpty() }?.let { bio ->
                    LabelledCard("About", bio)
                }

                if (profile != null && onOpenCompatibility != null) {
                    SecondaryAction("See Compatibility", Icons.Filled.QueryStats) {
                        onOpenCompatibility(profile.id)
                    }
                }

                if (profile?.showValuesBlurb != false) {
                    profile?.valuesBlurb?.takeIf { it.isNotEmpty() }?.let { blurb ->
                        LabelledCard("Values Blurb", blurb)
                    }
                }

                profile?.goalsList?.takeIf { it.isNotEmpty() }?.let { goals ->
                    ChipCard("Looking For", goals)
                }

                profile?.hobbies?.takeIf { it.isNotEmpty() }?.let { hobbies ->
                    ChipCard("Interests", hobbies)
                }

                if (profile?.showValuesGraph != false && !state.graphScores.isZero) {
                    ValuesRadarCard(
                        primary = state.graphScores,
                        primaryLabel = state.graphLabel,
                        title = "${profile?.displayName.orEmpty()}'s Values Map"
                    )
                }
            }

            // Room for the floating action button.
            Spacer(Modifier.height(100.dp))
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(HarvestTheme.Spacing.md)
        ) {
            if (profile != null && profile.id != viewerId) {
                ModerationMenu(
                    onReport = { showReport = true },
                    onBlock = { showBlockConfirm = true }
                )
            }
            Spacer(Modifier.weight(1f))
            CircleAction(Icons.Filled.Close, "Close", onClose)
        }

        if (showSeedAction && profile != null && profile.id != viewerId) {
            Box(
                Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
                    .padding(bottom = HarvestTheme.Spacing.lg)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                    modifier = Modifier
                        .background(HarvestTheme.Colors.primary, CircleShape)
                        .clickable { showSendSeed = true }
                        .padding(
                            horizontal = HarvestTheme.Spacing.xl,
                            vertical = HarvestTheme.Spacing.md
                        )
                ) {
                    Icon(
                        Icons.Filled.Spa,
                        contentDescription = null,
                        tint = HarvestTheme.Colors.textOnBlack,
                        modifier = Modifier.size(20.dp)
                    )
                    Text(
                        text = "Send a Seed",
                        style = HarvestTheme.Typography.buttonText,
                        color = HarvestTheme.Colors.textOnBlack
                    )
                }
            }
        }
    }

    if (showBlockConfirm && profile != null) {
        AlertDialog(
            onDismissRequest = { showBlockConfirm = false },
            title = { Text("Block ${profile.displayName}?") },
            text = {
                Text(
                    "They won't be able to see you or contact you, their content is " +
                        "removed from your feed, and we'll review this report within 24 hours."
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showBlockConfirm = false
                    viewModel.block(viewerId, profile.id)
                }) {
                    Text("Block & Report", color = HarvestTheme.Colors.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showBlockConfirm = false }) { Text("Cancel") }
            },
            containerColor = HarvestTheme.Colors.formSurface,
            titleContentColor = HarvestTheme.Colors.textPrimary,
            textContentColor = HarvestTheme.Colors.textSecondary
        )
    }
}

@Composable
private fun LabelledCard(title: String, body: String) {
    GlassCard {
        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
            Text(
                text = title,
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary
            )
            Text(
                text = body,
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textSecondary
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipCard(title: String, items: List<String>) {
    GlassCard {
        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
            Text(
                text = title,
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary
            )
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)
            ) {
                items.forEach { ChipView(title = it) }
            }
        }
    }
}

@Composable
private fun SecondaryAction(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.md)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.sm,
            Alignment.CenterHorizontally
        ),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.glassFillStrong, shape)
            .clickable { onClick() }
            .padding(vertical = 14.dp)
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.size(18.dp)
        )
        Text(
            text = label,
            style = HarvestTheme.Typography.buttonText,
            color = HarvestTheme.Colors.textPrimary
        )
    }
}

@Composable
private fun ModerationMenu(onReport: () -> Unit, onBlock: () -> Unit) {
    var open by remember { mutableStateOf(false) }

    Box {
        CircleAction(Icons.Filled.MoreHoriz, "More") { open = true }
        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
            containerColor = HarvestTheme.Colors.formSurface
        ) {
            DropdownMenuItem(
                text = { Text("Report", color = HarvestTheme.Colors.textPrimary) },
                onClick = { open = false; onReport() }
            )
            DropdownMenuItem(
                text = { Text("Block", color = HarvestTheme.Colors.error) },
                onClick = { open = false; onBlock() }
            )
        }
    }
}

@Composable
private fun CircleAction(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit
) {
    Box(
        Modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(HarvestTheme.Colors.blackSurface)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            icon,
            contentDescription = label,
            tint = HarvestTheme.Colors.textOnBlack,
            modifier = Modifier.size(16.dp)
        )
    }
}
