package com.harvestglass.harvest.ui.onboarding.steps

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import java.io.ByteArrayOutputStream

/**
 * Reads a picked image and re-encodes it as JPEG at quality 80, matching the
 * iOS `uiImage.jpegData(compressionQuality: 0.8)` in OnboardingViewModel.swift.
 * Returns null when the URI can't be read or decoded — the caller treats that
 * the same way the Swift version treats a nil UIImage.
 */
internal fun readAsJpeg(context: Context, uri: Uri): ByteArray? = runCatching {
    val bitmap = context.contentResolver.openInputStream(uri).use { stream ->
        BitmapFactory.decodeStream(stream)
    } ?: return null

    ByteArrayOutputStream().use { out ->
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
        out.toByteArray()
    }
}.getOrNull()

/**
 * Attaches the placeholder as a content description so a hand-rolled
 * BasicTextField is addressable by name in Compose tests and to accessibility
 * services, which a bare decorationBox placeholder is not.
 */
internal fun Modifier.semanticsPlaceholder(placeholder: String): Modifier =
    semantics { contentDescription = placeholder }
