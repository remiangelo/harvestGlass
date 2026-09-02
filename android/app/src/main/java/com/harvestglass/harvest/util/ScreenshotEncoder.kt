package com.harvestglass.harvest.util

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Turns a picked image into the inline `data:` URL the Gardener sends to
 * OpenAI. Android counterpart to ScreenshotEncoder.swift.
 *
 * Nothing touches disk and nothing is uploaded to storage — the bytes live in
 * memory for one request and are dropped.
 */
object ScreenshotEncoder {

    /** Long edge cap. Chat text stays legible well below a full-res screenshot. */
    const val MAX_DIMENSION = 1400

    /** JPEG quality; enough for text, small enough to keep the request sane. */
    private const val QUALITY = 80

    class EncodingException(message: String) : Exception(message)

    /**
     * Longest-edge target for a send of [imageCount] images. Text in a phone
     * screenshot stays legible at 900px, which is what makes the top of the
     * ladder affordable.
     */
    fun targetDimension(imageCount: Int): Int = when {
        imageCount <= 2 -> MAX_DIMENSION
        imageCount <= 5 -> 1100
        else -> 900
    }

    /**
     * Reads [uri], downscales it, and returns a `data:image/jpeg;base64,…` URL.
     *
     * @throws EncodingException when the image can't be read or encoded — the
     *   caller shows that message rather than blaming the picture's content.
     */
    fun dataUrl(context: Context, uri: Uri, maxDimension: Int = MAX_DIMENSION): String {
        val bitmap = decodeDownsampled(context, uri, maxDimension)
            ?: throw EncodingException("That image couldn't be read. Try a different screenshot.")

        val scaled = downscale(bitmap, maxDimension)

        val bytes = ByteArrayOutputStream().use { stream ->
            if (!scaled.compress(Bitmap.CompressFormat.JPEG, QUALITY, stream)) {
                throw EncodingException("That image couldn't be read. Try a different screenshot.")
            }
            stream.toByteArray()
        }

        val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
        return "data:image/jpeg;base64,$base64"
    }

    /**
     * Decodes with `inSampleSize` so a 12MP photo never lands in memory at full
     * size just to be shrunk afterwards.
     */
    private fun decodeDownsampled(context: Context, uri: Uri, maxDimension: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, bounds)
        } ?: return null

        val longest = max(bounds.outWidth, bounds.outHeight)
        if (longest <= 0) return null

        var sample = 1
        while (longest / sample > maxDimension * 2) sample *= 2

        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        }
    }

    /**
     * downscale returns the original when no scaling is needed, so it can't be
     * recycled here.
     */
    private fun downscale(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val longest = max(bitmap.width, bitmap.height)
        if (longest <= maxDimension) return bitmap

        val ratio = maxDimension.toDouble() / longest
        return Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * ratio).roundToInt().coerceAtLeast(1),
            (bitmap.height * ratio).roundToInt().coerceAtLeast(1),
            true
        )
    }
}
