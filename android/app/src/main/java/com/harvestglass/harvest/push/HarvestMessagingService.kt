package com.harvestglass.harvest.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.harvestglass.harvest.MainActivity
import com.harvestglass.harvest.R
import com.harvestglass.harvest.data.service.AuthService
import com.harvestglass.harvest.data.service.NotificationService
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Receives FCM tokens and messages.
 *
 * The server sends `deepLink` in the data payload — the same key the iOS
 * payload uses — so both clients route through identical logic.
 */
@AndroidEntryPoint
class HarvestMessagingService : FirebaseMessagingService() {

    @Inject lateinit var notificationService: NotificationService
    @Inject lateinit var authService: AuthService

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * Fires on install, on token rotation, and on app data clear. Registration
     * needs a signed-in user; if nobody is signed in the token is dropped and
     * picked up again by [registerCurrentToken] after the next sign-in.
     */
    override fun onNewToken(token: String) {
        val userId = authService.currentUserIdOrNull() ?: return
        scope.launch { runCatching { notificationService.registerDevice(userId, token) } }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.notification?.title ?: message.data["title"] ?: return
        val body = message.notification?.body ?: message.data["body"].orEmpty()
        val deepLink = message.data[EXTRA_DEEP_LINK]

        showNotification(this, title, body, deepLink)
    }

    companion object {
        const val EXTRA_DEEP_LINK = "deepLink"
        private const val CHANNEL_ID = "harvest_default"

        /**
         * A notification the user can tap to land on the right tab.
         *
         * Posting is a no-op without the POST_NOTIFICATIONS permission on
         * Android 13+, which is why the prompt is requested at the root.
         */
        fun showNotification(context: Context, title: String, body: String, deepLink: String?) {
            ensureChannel(context)

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                if (deepLink != null) putExtra(EXTRA_DEEP_LINK, deepLink)
            }
            val pending = PendingIntent.getActivity(
                context,
                deepLink?.hashCode() ?: 0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pending)
                .build()

            runCatching {
                NotificationManagerCompat.from(context)
                    .notify(deepLink?.hashCode() ?: title.hashCode(), notification)
            }
        }

        private fun ensureChannel(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Harvest",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Seeds, messages and daily reflections"
                }
            )
        }
    }
}
