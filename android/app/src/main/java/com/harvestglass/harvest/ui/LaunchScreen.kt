package com.harvestglass.harvest.ui

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.R

/**
 * Port of LaunchScreenView in Harvest/HarvestApp.swift: the splash gradient
 * behind a 240pt wordmark, with a 2.4s ease-in-out 1.0→1.02 pulse that
 * reverses and repeats forever.
 */
@Composable
fun LaunchScreen() {
    val transition = rememberInfiniteTransition(label = "splashGlow")
    val scale by transition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.02f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2400),
            repeatMode = RepeatMode.Reverse
        ),
        label = "splashScale"
    )

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Image(
            painter = painterResource(R.drawable.splash_page_gradient),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .scale(scale)
        )
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.06f))
        )
        Image(
            painter = painterResource(R.drawable.harvest_wordmark_black),
            contentDescription = "Harvest",
            contentScale = ContentScale.Fit,
            modifier = Modifier.width(240.dp)
        )
    }
}
