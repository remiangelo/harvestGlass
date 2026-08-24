package com.harvestglass.harvest.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Settings
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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.harvestglass.harvest.ui.components.ChipView
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.ValuesRadarCard
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Port of Harvest/Views/Profile/ProfileView.swift. */
@Composable
fun ProfileScreen(
    userId: String,
    onOpenSettings: () -> Unit,
    onOpenEdit: () -> Unit,
    viewModel: ProfileViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(userId) { viewModel.load(userId) }

    val profile = state.profile

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Text(
                text = "Profile",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            Icon(
                Icons.Filled.Settings,
                contentDescription = "Settings",
                tint = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.clickable { onOpenSettings() }
            )
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(bottom = HarvestTheme.Spacing.lg)
        ) {
            val photos = profile?.photos.orEmpty()
            if (photos.isNotEmpty()) {
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                    contentPadding = PaddingValues(horizontal = HarvestTheme.Spacing.md)
                ) {
                    items(photos.size) { index ->
                        AsyncImage(
                            model = photos[index],
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillParentMaxWidth(0.9f)
                                .height(400.dp)
                                .clip(RoundedCornerShape(HarvestTheme.Radius.xl))
                        )
                    }
                }
            }

            GlassCard(modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)) {
                Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            text = profile?.displayName.orEmpty(),
                            style = HarvestTheme.Typography.h2,
                            color = HarvestTheme.Colors.textPrimary
                        )
                        profile?.age?.let {
                            Text(
                                text = ", $it",
                                style = HarvestTheme.Typography.h3,
                                color = HarvestTheme.Colors.textSecondary
                            )
                        }
                    }

                    // Values I Bring — shown directly under name/age.
                    if ((profile?.showValuesBrought ?: true) && state.valuesBrought.isNotEmpty()) {
                        ChipFlow(state.valuesBrought.map { it.name })
                    }

                    profile?.location?.takeIf { it.isNotEmpty() }?.let {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Filled.LocationOn,
                                contentDescription = null,
                                tint = HarvestTheme.Colors.primary,
                                modifier = Modifier.size(14.dp)
                            )
                            Text(
                                text = it,
                                style = HarvestTheme.Typography.bodySmall,
                                color = HarvestTheme.Colors.textSecondary
                            )
                        }
                    }

                    profile?.bio?.takeIf { it.isNotEmpty() }?.let {
                        Text(
                            text = it,
                            style = HarvestTheme.Typography.bodyRegular,
                            color = HarvestTheme.Colors.textSecondary
                        )
                    }

                    if (profile?.showValuesBlurb != false) {
                        profile?.valuesBlurb?.takeIf { it.isNotEmpty() }?.let {
                            LabelledBlock("Values Blurb") {
                                Text(
                                    text = it,
                                    style = HarvestTheme.Typography.bodyRegular,
                                    color = HarvestTheme.Colors.textSecondary
                                )
                            }
                        }
                    }

                    val details = profile?.lifestyleDetails.orEmpty()
                    if (details.isNotEmpty()) {
                        LabelledBlock("Lifestyle & Intentions") {
                            Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)) {
                                details.forEach { (label, value) ->
                                    Row {
                                        Text(
                                            text = "$label: ",
                                            style = HarvestTheme.Typography.bodySmall,
                                            color = HarvestTheme.Colors.textSecondary
                                        )
                                        Text(
                                            text = value,
                                            style = HarvestTheme.Typography.bodySmall,
                                            color = HarvestTheme.Colors.textPrimary
                                        )
                                    }
                                }
                            }
                        }
                    }

                    profile?.hobbies?.takeIf { it.isNotEmpty() }?.let {
                        LabelledBlock("Interests") { ChipFlow(it) }
                    }
                }
            }

            if (profile?.showValuesGraph != false && !state.graphScores.isZero) {
                ValuesRadarCard(
                    primary = state.graphScores,
                    primaryLabel = if (state.graphIsNeed) "I Need" else "I Bring",
                    modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.md)
                )
            }

            val shape = RoundedCornerShape(HarvestTheme.Radius.md)
            Row(
                horizontalArrangement = Arrangement.spacedBy(
                    HarvestTheme.Spacing.sm,
                    Alignment.CenterHorizontally
                ),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .padding(horizontal = HarvestTheme.Spacing.md)
                    .fillMaxWidth()
                    .background(HarvestTheme.Colors.blackSurface, shape)
                    .border(1.dp, HarvestTheme.Colors.border, shape)
                    .clickable { onOpenEdit() }
                    .padding(vertical = 14.dp)
            ) {
                Icon(
                    Icons.Filled.Edit,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.textOnBlack,
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = "Edit Profile",
                    style = HarvestTheme.Typography.buttonText,
                    fontWeight = FontWeight.SemiBold,
                    color = HarvestTheme.Colors.textOnBlack
                )
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
}

@Composable
private fun LabelledBlock(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
        Text(
            text = title,
            style = HarvestTheme.Typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = HarvestTheme.Colors.textPrimary
        )
        content()
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipFlow(labels: List<String>) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)
    ) {
        labels.forEach { ChipView(title = it) }
    }
}
