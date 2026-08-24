package com.harvestglass.harvest.ui.field

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.harvestglass.harvest.data.model.ProfileFilterOptions
import com.harvestglass.harvest.data.model.RoomMemberFilter
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.GlassCardStyle
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.profile.MemberProfileScreen
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Field/RoomMembersView.swift and its filter sheet.
 *
 * Filter gating mirrors Discover's exactly — basic is free, advanced needs
 * Grow, full needs Gold — so the two screens never disagree about what a tier
 * buys. The tier lookup itself lands with the Subscription subsystem, so both
 * paid blocks currently render locked.
 */
@Composable
fun RoomMembersScreen(
    communityId: String,
    userId: String,
    onBack: () -> Unit,
    viewModel: RoomMembersViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var showFilters by remember { mutableStateOf(false) }
    var openProfileId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(communityId) { viewModel.load(communityId, userId) }

    openProfileId?.let { id ->
        MemberProfileScreen(
            profileId = id,
            viewerId = userId,
            onClose = { openProfileId = null }
        )
        return
    }

    if (showFilters) {
        RoomMemberFiltersSheet(
            filter = state.filter,
            canAccessAdvanced = state.canAccessAdvanced,
            canAccessFull = state.canAccessFull,
            onChange = viewModel::updateFilter,
            onReset = viewModel::resetFilter,
            onDone = { showFilters = false }
        )
        return
    }

    val visible = state.visibleMembers(userId)

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier
                .fillMaxWidth()
                .background(HarvestTheme.Colors.wineBlack)
                .statusBarsPadding()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.clickable { onBack() }
            )
            Text(
                text = "Members",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            Icon(
                Icons.Filled.FilterList,
                contentDescription = "Filter members",
                tint = if (state.filter.activeAttributeCount > 0) {
                    HarvestTheme.Colors.accent
                } else {
                    HarvestTheme.Colors.textPrimary
                },
                modifier = Modifier.clickable { showFilters = true }
            )
        }

        SearchField(
            value = state.filter.search,
            onValueChange = viewModel::setSearch,
            modifier = Modifier.padding(HarvestTheme.Spacing.md)
        )

        if (visible.isEmpty()) {
            MembersEmptyState(
                isFiltered = state.filter.activeAttributeCount > 0 || state.filter.search.isNotEmpty(),
                onClearFilters = viewModel::resetFilter
            )
            return@Column
        }

        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            contentPadding = PaddingValues(HarvestTheme.Spacing.md),
            modifier = Modifier.navigationBarsPadding()
        ) {
            item("count") {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = HarvestTheme.Spacing.xs)
                ) {
                    Text(
                        text = "${visible.size} member" + if (visible.size == 1) "" else "s",
                        style = HarvestTheme.Typography.caption,
                        color = HarvestTheme.Colors.textSecondary,
                        modifier = Modifier.weight(1f)
                    )
                    if (state.filter.activeAttributeCount > 0) {
                        Text(
                            text = "Clear filters",
                            style = HarvestTheme.Typography.caption,
                            color = HarvestTheme.Colors.accent,
                            modifier = Modifier.clickable { viewModel.resetFilter() }
                        )
                    }
                }
            }

            items(visible, key = { it.id }) { profile ->
                MemberRow(profile) { openProfileId = profile.id }
            }
        }
    }
}

@Composable
private fun MemberRow(profile: UserProfile, onOpen: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.lg)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineCard, shape)
            .border(1.dp, HarvestTheme.Colors.border, shape)
            .clickable { onOpen() }
            .padding(HarvestTheme.Spacing.md)
    ) {
        val photo = profile.primaryPhoto
        if (photo != null) {
            AsyncImage(
                model = photo,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(52.dp).clip(CircleShape)
            )
        } else {
            Box(
                Modifier
                    .size(52.dp)
                    .background(HarvestTheme.Colors.wineRaised, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.Person,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.textTertiary
                )
            }
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(2.dp),
            modifier = Modifier.weight(1f)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = profile.displayName,
                    style = HarvestTheme.Typography.cardTitle,
                    color = HarvestTheme.Colors.textPrimary
                )
                profile.age?.let {
                    Text(
                        text = "$it",
                        style = HarvestTheme.Typography.bodySmall,
                        color = HarvestTheme.Colors.textSecondary
                    )
                }
            }
            profile.location?.takeIf { it.isNotEmpty() }?.let {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Filled.LocationOn,
                        contentDescription = null,
                        tint = HarvestTheme.Colors.textTertiary,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = it,
                        style = HarvestTheme.Typography.caption,
                        color = HarvestTheme.Colors.textTertiary
                    )
                }
            }
            profile.lookingFor?.takeIf { it.isNotEmpty() }?.let {
                Text(
                    text = it,
                    style = HarvestTheme.Typography.caption,
                    color = HarvestTheme.Colors.accent
                )
            }
        }

        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = HarvestTheme.Colors.textTertiary
        )
    }
}

@Composable
private fun MembersEmptyState(isFiltered: Boolean, onClearFilters: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.sm,
            Alignment.CenterVertically
        ),
        modifier = Modifier
            .fillMaxSize()
            .padding(HarvestTheme.Spacing.xl)
    ) {
        Icon(
            Icons.Filled.Person,
            contentDescription = null,
            tint = HarvestTheme.Colors.rose,
            modifier = Modifier.size(32.dp)
        )
        Text(
            text = if (isFiltered) {
                "No one here matches those filters."
            } else {
                "No other members yet."
            },
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary,
            textAlign = TextAlign.Center
        )
        if (isFiltered) {
            HarvestButton(
                text = "Clear filters",
                kind = HarvestButtonKind.SECONDARY,
                onClick = onClearFilters
            )
        }
    }
}

@Composable
private fun SearchField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val shape = RoundedCornerShape(percent = 50)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        textStyle = LocalTextStyle.current.merge(
            TextStyle(color = HarvestTheme.Colors.textPrimary)
        ),
        cursorBrush = SolidColor(HarvestTheme.Colors.rose),
        modifier = modifier.fillMaxWidth(),
        decorationBox = { inner ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HarvestTheme.Colors.formSurface, shape)
                    .border(1.dp, HarvestTheme.Colors.formBorder, shape)
                    .padding(horizontal = HarvestTheme.Spacing.md, vertical = 10.dp)
            ) {
                Icon(
                    Icons.Filled.Search,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.textTertiary,
                    modifier = Modifier.size(18.dp)
                )
                Box(Modifier.weight(1f)) {
                    if (value.isEmpty()) {
                        Text(
                            text = "Search members",
                            style = HarvestTheme.Typography.bodyRegular,
                            color = HarvestTheme.Colors.textTertiary
                        )
                    }
                    inner()
                }
            }
        }
    )
}

// MARK: - Filters sheet

@Composable
private fun RoomMemberFiltersSheet(
    filter: RoomMemberFilter,
    canAccessAdvanced: Boolean,
    canAccessFull: Boolean,
    onChange: (RoomMemberFilter) -> Unit,
    onReset: () -> Unit,
    onDone: () -> Unit
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
                text = "Filter members",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = "Done",
                style = HarvestTheme.Typography.bodyRegular,
                fontWeight = FontWeight.SemiBold,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.clickable { onDone() }
            )
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            SectionTitle("Age")
            GlassCard(style = GlassCardStyle.LIGHT) {
                StepperRow("Minimum: ${filter.ageMin}", filter.ageMin) {
                    onChange(filter.copy(ageMin = it.coerceIn(18, filter.ageMax)))
                }
                StepperRow("Maximum: ${filter.ageMax}", filter.ageMax) {
                    onChange(filter.copy(ageMax = it.coerceIn(filter.ageMin, 99)))
                }
            }

            SectionTitle("Gender")
            GlassCard(style = GlassCardStyle.LIGHT) {
                PickerRow("Gender", filter.gender, ProfileFilterOptions.genderIdentity) {
                    onChange(filter.copy(gender = it))
                }
            }

            SectionTitle("Advanced")
            if (canAccessAdvanced) {
                GlassCard(style = GlassCardStyle.LIGHT) {
                    PickerRow("Looking for", filter.lookingFor, ProfileFilterOptions.lookingFor) {
                        onChange(filter.copy(lookingFor = it))
                    }
                    PickerRow("Smoking", filter.smoking, ProfileFilterOptions.smoking) {
                        onChange(filter.copy(smoking = it))
                    }
                    PickerRow("Drinking", filter.drinking, ProfileFilterOptions.drinking) {
                        onChange(filter.copy(drinking = it))
                    }
                    PickerRow("Cannabis", filter.cannabis, ProfileFilterOptions.cannabis) {
                        onChange(filter.copy(cannabis = it))
                    }
                }
            } else {
                LockedBlock("Grow")
            }

            SectionTitle("Full")
            if (canAccessFull) {
                GlassCard(style = GlassCardStyle.LIGHT) {
                    PickerRow("Faith", filter.faith, ProfileFilterOptions.faith) {
                        onChange(filter.copy(faith = it))
                    }
                    PickerRow("Children", filter.childrenStatus, ProfileFilterOptions.children) {
                        onChange(filter.copy(childrenStatus = it))
                    }
                }
            } else {
                LockedBlock("Gold")
            }

            HarvestButton(
                text = "Reset filters",
                kind = HarvestButtonKind.SECONDARY,
                modifier = Modifier.fillMaxWidth(),
                onClick = onReset
            )
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        style = HarvestTheme.Typography.h4,
        color = HarvestTheme.Colors.textPrimary
    )
}

@Composable
private fun StepperRow(title: String, value: Int, onChange: (Int) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = HarvestTheme.Spacing.sm)
    ) {
        Text(
            text = title,
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.weight(1f)
        )
        StepperButton("−") { onChange(value - 1) }
        Spacer(Modifier.width(HarvestTheme.Spacing.sm))
        StepperButton("+") { onChange(value + 1) }
    }
}

@Composable
private fun StepperButton(label: String, onClick: () -> Unit) {
    Text(
        text = label,
        style = HarvestTheme.Typography.h4,
        color = HarvestTheme.Colors.textOnRedPrimary,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .size(32.dp)
            .background(HarvestTheme.Colors.primary, CircleShape)
            .clickable { onClick() }
            .padding(top = 2.dp)
    )
}

@Composable
private fun PickerRow(
    title: String,
    selected: String?,
    options: List<String>,
    onSelect: (String?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxWidth()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = !expanded }
                .padding(vertical = HarvestTheme.Spacing.sm)
        ) {
            Text(
                text = title,
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = selected ?: ProfileFilterOptions.ANY,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary
            )
        }

        if (expanded) {
            (listOf(ProfileFilterOptions.ANY) + options).forEach { option ->
                Text(
                    text = option,
                    style = HarvestTheme.Typography.bodySmall,
                    color = if (option == (selected ?: ProfileFilterOptions.ANY)) {
                        HarvestTheme.Colors.accent
                    } else {
                        HarvestTheme.Colors.textPrimary
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            onSelect(if (option == ProfileFilterOptions.ANY) null else option)
                            expanded = false
                        }
                        .padding(
                            start = HarvestTheme.Spacing.md,
                            top = HarvestTheme.Spacing.xs,
                            bottom = HarvestTheme.Spacing.xs
                        )
                )
            }
        }
    }
}

@Composable
private fun LockedBlock(tier: String) {
    GlassCard(style = GlassCardStyle.LIGHT) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
        ) {
            Icon(
                Icons.Filled.Lock,
                contentDescription = null,
                tint = HarvestTheme.Colors.primary,
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = "Unlock with $tier",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary
            )
        }
    }
}
