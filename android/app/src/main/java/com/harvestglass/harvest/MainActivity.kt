package com.harvestglass.harvest

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.harvestglass.harvest.ui.HarvestApp
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { HarvestAppTheme { HarvestApp() } }
    }
}
