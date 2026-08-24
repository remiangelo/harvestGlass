package com.harvestglass.harvest.ui.profile

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.harvestglass.harvest.data.model.ProfileFilterOptions
import com.harvestglass.harvest.ui.components.ChipView
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.GlassCardStyle
import com.harvestglass.harvest.ui.components.SectionHeader
import com.harvestglass.harvest.ui.onboarding.steps.readAsJpeg
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme
import kotlinx.coroutines.launch

private const val MAX_PHOTOS = 6

/** Port of Harvest/Views/Profile/ProfileEditView.swift. */
@Composable
fun ProfileEditScreen(
    userId: String,
    onBack: () -> Unit,
    viewModel: ProfileViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val draft = state.draft

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        readAsJpeg(context, uri)?.let { viewModel.uploadPhoto(userId, it) }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
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
                contentDescription = "Cancel",
                tint = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.clickable {
                    viewModel.cancelEditing()
                    onBack()
                }
            )
            Text(
                text = "Edit Profile",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = if (state.isSaving) "Saving…" else "Save",
                style = HarvestTheme.Typography.bodyRegular,
                fontWeight = FontWeight.SemiBold,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.clickable(enabled = !state.isSaving) {
                    scope.launch { if (viewModel.save(userId)) onBack() }
                }
            )
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            SectionHeader("Photos")
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                modifier = Modifier.height(240.dp)
            ) {
                items(draft.photoUrls.size) { index ->
                    Box(Modifier.aspectRatio(1f)) {
                        AsyncImage(
                            model = draft.photoUrls[index],
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxSize()
                                .clip(RoundedCornerShape(HarvestTheme.Radius.md))
                        )
                        Icon(
                            Icons.Filled.Close,
                            contentDescription = "Remove photo",
                            tint = Color.White,
                            modifier = Modifier
                                .align(Alignment.TopEnd)
                                .padding(4.dp)
                                .size(20.dp)
                                .background(
                                    HarvestTheme.Colors.photoScrim.copy(alpha = 0.7f),
                                    CircleShape
                                )
                                .clickable { viewModel.removePhoto(userId, index) }
                        )
                    }
                }
                if (draft.photoUrls.size < MAX_PHOTOS) {
                    items(1) {
                        val shape = RoundedCornerShape(HarvestTheme.Radius.md)
                        Box(
                            Modifier
                                .aspectRatio(1f)
                                .background(HarvestTheme.Colors.formSurface, shape)
                                .border(1.dp, HarvestTheme.Colors.formBorder, shape)
                                .clickable {
                                    picker.launch(
                                        PickVisualMediaRequest(
                                            ActivityResultContracts.PickVisualMedia.ImageOnly
                                        )
                                    )
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Filled.Add,
                                contentDescription = "Add photo",
                                tint = HarvestTheme.Colors.primary
                            )
                        }
                    }
                }
            }

            SectionHeader("About you")
            GlassCard(style = GlassCardStyle.LIGHT) {
                EditField("Nickname", draft.nickname) {
                    viewModel.updateDraft(draft.copy(nickname = it))
                }
                EditField("Bio", draft.bio, singleLine = false) {
                    viewModel.updateDraft(draft.copy(bio = it))
                }
                EditField("Location", draft.location) {
                    viewModel.updateDraft(draft.copy(location = it))
                }
            }

            SectionHeader("Lifestyle & Intentions")
            GlassCard(style = GlassCardStyle.LIGHT) {
                OptionRow("Looking for", draft.lookingFor, ProfileFilterOptions.lookingFor) {
                    viewModel.updateDraft(draft.copy(lookingFor = it))
                }
                OptionRow("Smoking", draft.smoking, ProfileFilterOptions.smoking) {
                    viewModel.updateDraft(draft.copy(smoking = it))
                }
                OptionRow("Drinking", draft.drinking, ProfileFilterOptions.drinking) {
                    viewModel.updateDraft(draft.copy(drinking = it))
                }
                OptionRow("Cannabis", draft.cannabis, ProfileFilterOptions.cannabis) {
                    viewModel.updateDraft(draft.copy(cannabis = it))
                }
                OptionRow("Faith", draft.spiritualOrientation, ProfileFilterOptions.faith) {
                    viewModel.updateDraft(draft.copy(spiritualOrientation = it))
                }
                OptionRow("Children", draft.childrenStatus, ProfileFilterOptions.children) {
                    viewModel.updateDraft(draft.copy(childrenStatus = it))
                }
            }

            state.error?.let {
                Text(
                    text = it,
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.error
                )
            }

            HarvestButton(
                text = "Save changes",
                kind = HarvestButtonKind.PRIMARY,
                modifier = Modifier.fillMaxWidth()
            ) { scope.launch { if (viewModel.save(userId)) onBack() } }
        }
    }
}

@Composable
private fun EditField(
    label: String,
    value: String,
    singleLine: Boolean = true,
    onValueChange: (String) -> Unit
) {
    Column(Modifier.padding(vertical = HarvestTheme.Spacing.xs)) {
        Text(
            text = label,
            style = HarvestTheme.Typography.caption,
            color = HarvestTheme.Colors.textSecondary
        )
        val shape = RoundedCornerShape(HarvestTheme.Radius.sm)
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = singleLine,
            maxLines = if (singleLine) 1 else 5,
            textStyle = LocalTextStyle.current.merge(
                TextStyle(color = HarvestTheme.Colors.textPrimary)
            ),
            cursorBrush = SolidColor(HarvestTheme.Colors.primary),
            modifier = Modifier.fillMaxWidth(),
            decorationBox = { inner ->
                Box(
                    Modifier
                        .fillMaxWidth()
                        .background(HarvestTheme.Colors.whiteFormSurface, shape)
                        .border(1.dp, HarvestTheme.Colors.formBorder, shape)
                        .padding(HarvestTheme.Spacing.sm)
                ) { inner() }
            }
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun OptionRow(
    label: String,
    selected: String,
    options: List<String>,
    onSelect: (String) -> Unit
) {
    Column(Modifier.padding(vertical = HarvestTheme.Spacing.xs)) {
        Text(
            text = label,
            style = HarvestTheme.Typography.caption,
            color = HarvestTheme.Colors.textSecondary
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)
        ) {
            options.forEach { option ->
                ChipView(
                    title = option,
                    isSelected = selected.equals(option, ignoreCase = true),
                    lightStyle = true,
                    // Tapping the selected chip clears it.
                    onTap = { onSelect(if (selected.equals(option, ignoreCase = true)) "" else option) }
                )
            }
        }
    }
}
