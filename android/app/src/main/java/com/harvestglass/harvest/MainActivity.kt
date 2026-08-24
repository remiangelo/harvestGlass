package com.harvestglass.harvest

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import android.content.Intent
import com.harvestglass.harvest.push.HarvestMessagingService
import com.harvestglass.harvest.ui.HarvestApp
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    /**
     * The deep link from a tapped notification, if the app was opened by one.
     * Read once by the composition and then cleared, so rotating the device
     * doesn't re-navigate.
     */
    private var pendingDeepLink by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+ forces edge-to-edge for targetSdk 35 regardless, so this
        // is declared rather than relied upon: it makes the behaviour explicit
        // and lets the light status-bar icons be set for the cream palette.
        // Every screen must therefore apply its own window insets.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        pendingDeepLink = intent?.getStringExtra(HarvestMessagingService.EXTRA_DEEP_LINK)

        setContent {
            HarvestAppTheme {
                HarvestApp(
                    pendingDeepLink = pendingDeepLink,
                    onDeepLinkHandled = { pendingDeepLink = null }
                )
            }
        }
    }

    /** The activity is singleTop, so a second tap arrives here, not in onCreate. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingDeepLink = intent.getStringExtra(HarvestMessagingService.EXTRA_DEEP_LINK)
    }
}
