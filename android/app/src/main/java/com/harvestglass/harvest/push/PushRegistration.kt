package com.harvestglass.harvest.push

import android.Manifest
import android.content.Context
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import com.google.firebase.messaging.FirebaseMessaging
import androidx.hilt.navigation.compose.hiltViewModel
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Asks for notification permission and registers the FCM token, once, after
 * sign-in.
 *
 * Everything here degrades quietly: without `google-services.json` Firebase
 * never initialises and [currentToken] throws, which is caught and ignored.
 * The app is fully usable in that state — it just won't receive pushes.
 */
@Composable
fun RegisterForPush(userId: String, viewModel: PushViewModel = hiltViewModel()) {
    val context = LocalContext.current

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { /* Declining is fine; registration below still stores the token. */ }

    LaunchedEffect(userId) {
        if (userId.isEmpty()) return@LaunchedEffect

        // POST_NOTIFICATIONS only exists on Android 13+; below that the
        // permission is granted at install time.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        viewModel.register(userId, context)
    }
}

/**
 * The device's FCM registration token.
 *
 * Throws when Firebase is not configured, which is the expected state until
 * google-services.json is added.
 */
suspend fun currentToken(context: Context): String =
    suspendCancellableCoroutine { continuation ->
        runCatching {
            FirebaseMessaging.getInstance().token
                .addOnSuccessListener { token ->
                    if (continuation.isActive) continuation.resume(token)
                }
                .addOnFailureListener { error ->
                    if (continuation.isActive) continuation.resumeWithException(error)
                }
        }.onFailure { error ->
            if (continuation.isActive) continuation.resumeWithException(error)
        }
    }
