package com.harvestglass.harvest

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.harvestglass.harvest.ui.HarvestApp
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+ forces edge-to-edge for targetSdk 35 regardless, so this
        // is declared rather than relied upon: it makes the behaviour explicit
        // and lets the light status-bar icons be set for the cream palette.
        // Every screen must therefore apply its own window insets.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { HarvestAppTheme { HarvestApp() } }
    }
}
