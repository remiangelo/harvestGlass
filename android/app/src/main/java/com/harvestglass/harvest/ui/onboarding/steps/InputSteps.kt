package com.harvestglass.harvest.ui.onboarding.steps

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.harvestglass.harvest.ui.onboarding.OnboardingUiState
import com.harvestglass.harvest.ui.theme.HarvestTheme
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** Ports of AgeStepView, NicknameStepView, PhotosStepView and LocationStepView. */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AgeStep(state: OnboardingUiState, onBirthDateChange: (LocalDate) -> Unit) {
    val pickerState = rememberDatePickerState(
        initialSelectedDateMillis = state.birthDate
            .atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    )

    LaunchedEffect(pickerState.selectedDateMillis) {
        pickerState.selectedDateMillis?.let { millis ->
            val picked = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
            if (picked != state.birthDate) onBirthDateChange(picked)
        }
    }

    StepScaffold(
        icon = Icons.Filled.CalendarMonth,
        title = "How old are you?",
        subtitle = "You must be at least 18 years old"
    ) {
        val shape = RoundedCornerShape(HarvestTheme.Radius.xl)
        Box(
            Modifier
                .padding(horizontal = HarvestTheme.Spacing.lg)
                .background(HarvestTheme.Colors.formSurface, shape)
                .border(1.dp, HarvestTheme.Colors.formBorder, shape)
        ) {
            // Material3 defaults paint the picker on surfaceVariant (a
            // lavender grey), which clashes with the cream page. Every
            // surface and accent is pinned to the Harvest palette instead.
            DatePicker(
                state = pickerState,
                title = null,
                headline = null,
                showModeToggle = false,
                colors = DatePickerDefaults.colors(
                    containerColor = HarvestTheme.Colors.formSurface,
                    titleContentColor = HarvestTheme.Colors.textPrimary,
                    headlineContentColor = HarvestTheme.Colors.textPrimary,
                    weekdayContentColor = HarvestTheme.Colors.textSecondary,
                    subheadContentColor = HarvestTheme.Colors.textSecondary,
                    navigationContentColor = HarvestTheme.Colors.textPrimary,
                    yearContentColor = HarvestTheme.Colors.textPrimary,
                    currentYearContentColor = HarvestTheme.Colors.primary,
                    selectedYearContentColor = HarvestTheme.Colors.textOnRedPrimary,
                    selectedYearContainerColor = HarvestTheme.Colors.primary,
                    dayContentColor = HarvestTheme.Colors.textPrimary,
                    selectedDayContentColor = HarvestTheme.Colors.textOnRedPrimary,
                    selectedDayContainerColor = HarvestTheme.Colors.primary,
                    todayContentColor = HarvestTheme.Colors.primary,
                    todayDateBorderColor = HarvestTheme.Colors.primary,
                    dividerColor = HarvestTheme.Colors.divider
                )
            )
        }

        if (state.age > 0) {
            Text(
                text = "Age: ${state.age}",
                style = HarvestTheme.Typography.h3,
                color = HarvestTheme.Colors.textPrimary
            )
        }

        if (!state.isAgeValid && state.age > 0) {
            Text(
                text = "You must be 18 or older to use Harvest",
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.error
            )
        }
    }
}

@Composable
fun NicknameStep(state: OnboardingUiState, onNicknameChange: (String) -> Unit) {
    StepScaffold(
        icon = Icons.Filled.PhotoCamera,
        title = "What should we call you?",
        subtitle = "This is how other users will see you"
    ) {
        CenteredField(
            value = state.nickname,
            onValueChange = onNicknameChange,
            placeholder = "Your nickname",
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.xl)
        )
    }
}

@Composable
fun PhotosStep(
    state: OnboardingUiState,
    onPickPhoto: (ByteArray) -> Unit,
    onRemovePhoto: (Int) -> Unit
) {
    val context = LocalContext.current
    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        // Re-encode to JPEG q80 to match iOS jpegData(compressionQuality: 0.8).
        val bytes = readAsJpeg(context, uri)
        if (bytes != null) onPickPhoto(bytes)
    }

    StepScaffold(
        icon = Icons.Filled.PhotoCamera,
        title = "Add your photos",
        subtitle = "Add at least 1 photo (up to 6)"
    ) {
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier
                .padding(horizontal = HarvestTheme.Spacing.lg)
                .height(240.dp)
        ) {
            items(state.photoUrls.size) { index ->
                PhotoCell(url = state.photoUrls[index], onRemove = { onRemovePhoto(index) })
            }
            if (state.photoUrls.size < MAX_PHOTOS) {
                items(1) {
                    AddPhotoCell(isBusy = state.isLoading) {
                        picker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    }
                }
            }
        }

        state.error?.let {
            Text(
                text = it,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.error,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
fun LocationStep(
    state: OnboardingUiState,
    onQueryChange: (String) -> Unit,
    onValidate: () -> Unit,
    onSelectSuggestion: (String) -> Unit
) {
    // iOS debounces 800ms after the text changes before geocoding.
    LaunchedEffect(state.location) {
        if (state.location.isBlank() || state.location == state.resolvedLocation) {
            return@LaunchedEffect
        }
        delay(800)
        onValidate()
    }

    StepScaffold(
        icon = Icons.Filled.LocationOn,
        title = "Where are you located?",
        subtitle = "Enter your city name"
    ) {
        CenteredField(
            value = state.location,
            onValueChange = onQueryChange,
            placeholder = "City name",
            modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.xl)
        )

        when {
            state.isValidatingLocation ->
                CircularProgressIndicator(color = HarvestTheme.Colors.primary)

            state.locationSuggestions.isNotEmpty() ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
                    modifier = Modifier.padding(horizontal = HarvestTheme.Spacing.xl)
                ) {
                    state.locationSuggestions.forEach { suggestion ->
                        SelectableRow(
                            label = suggestion,
                            isSelected = state.resolvedLocation == suggestion,
                            onClick = { onSelectSuggestion(suggestion) }
                        )
                    }
                }
        }
    }
}

// MARK: - Shared pieces

private const val MAX_PHOTOS = 6

@Composable
private fun CenteredField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier
) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.xl)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        textStyle = LocalTextStyle.current.merge(
            TextStyle(
                color = HarvestTheme.Colors.textPrimary,
                textAlign = TextAlign.Center,
                fontSize = HarvestTheme.Typography.bodyLarge.fontSize
            )
        ),
        cursorBrush = SolidColor(HarvestTheme.Colors.primary),
        modifier = modifier
            .fillMaxWidth()
            .semanticsPlaceholder(placeholder),
        decorationBox = { inner ->
            Box(
                Modifier
                    .fillMaxWidth()
                    .background(HarvestTheme.Colors.formSurface, shape)
                    .border(1.dp, HarvestTheme.Colors.formBorder, shape)
                    .padding(HarvestTheme.Spacing.md),
                contentAlignment = Alignment.Center
            ) {
                if (value.isEmpty()) {
                    Text(
                        text = placeholder,
                        style = HarvestTheme.Typography.bodyLarge,
                        color = HarvestTheme.Colors.textTertiary
                    )
                }
                inner()
            }
        }
    )
}

@Composable
private fun PhotoCell(url: String, onRemove: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.md)
    Box(Modifier.aspectRatio(1f)) {
        AsyncImage(
            model = url,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .background(HarvestTheme.Colors.formSurfaceStrong, shape)
                .border(1.dp, HarvestTheme.Colors.formBorder, shape)
        )
        Icon(
            imageVector = Icons.Filled.Close,
            contentDescription = "Remove photo",
            tint = Color.White,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(4.dp)
                .size(20.dp)
                .background(HarvestTheme.Colors.photoScrim.copy(alpha = 0.7f), CircleShape)
                .clickable { onRemove() }
        )
    }
}

@Composable
private fun AddPhotoCell(isBusy: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.md)
    Box(
        Modifier
            .aspectRatio(1f)
            .background(HarvestTheme.Colors.formSurface, shape)
            .border(1.dp, HarvestTheme.Colors.formBorder, shape)
            .clickable(enabled = !isBusy, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        if (isBusy) {
            CircularProgressIndicator(
                color = HarvestTheme.Colors.primary,
                modifier = Modifier.size(24.dp),
                strokeWidth = 2.dp
            )
        } else {
            Icon(Icons.Filled.Add, contentDescription = "Add photo", tint = HarvestTheme.Colors.primary)
        }
    }
}
