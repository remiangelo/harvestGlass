package com.harvestglass.harvest.util

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.util.Locale
import kotlin.coroutines.resume

/**
 * Stands in for `MKGeocodingRequest` in
 * Harvest/ViewModels/OnboardingViewModel.swift `validateLocation()`.
 *
 * Same behaviour as iOS: up to [DEFAULT_LIMIT] unique human-readable
 * suggestions, and an empty list on any failure — the Swift version clears
 * `resolvedLocation` and `locationSuggestions` rather than surfacing a
 * geocoding error to the user.
 */
class Geocoding(context: Context) {

    private val geocoder = Geocoder(context, Locale.getDefault())

    suspend fun suggestions(query: String, limit: Int = DEFAULT_LIMIT): List<String> {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return emptyList()
        if (!Geocoder.isPresent()) return emptyList()

        val addresses = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                lookupAsync(trimmed, limit)
            } else {
                // Deprecated blocking overload; minSdk is 26, so it still has
                // to exist. Kept off the main thread so it cannot ANR.
                withContext(Dispatchers.IO) {
                    @Suppress("DEPRECATION")
                    geocoder.getFromLocationName(trimmed, limit).orEmpty()
                }
            }
        }.getOrDefault(emptyList())

        return addresses
            .mapNotNull { describe(it) }
            .distinct()
            .take(limit)
    }

    private suspend fun lookupAsync(query: String, limit: Int): List<Address> =
        suspendCancellableCoroutine { continuation ->
            geocoder.getFromLocationName(
                query,
                limit,
                object : Geocoder.GeocodeListener {
                    override fun onGeocode(addresses: MutableList<Address>) {
                        if (continuation.isActive) continuation.resume(addresses)
                    }

                    override fun onError(errorMessage: String?) {
                        // Treated as "no matches", matching the iOS catch block.
                        if (continuation.isActive) continuation.resume(emptyList())
                    }
                }
            )
        }

    /** "City, Region, Country", skipping whatever the provider left null. */
    private fun describe(address: Address): String? {
        val parts = listOfNotNull(
            address.locality ?: address.subAdminArea,
            address.adminArea,
            address.countryName
        ).filter { it.isNotBlank() }

        return if (parts.isEmpty()) {
            address.getAddressLine(0)?.takeIf { it.isNotBlank() }
        } else {
            parts.joinToString(", ")
        }
    }

    companion object {
        const val DEFAULT_LIMIT = 5
    }
}
