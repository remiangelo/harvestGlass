package com.harvestglass.harvest.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.GppMaybe
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Onboarding/DifferentiationView.swift — the one-time
 * intro shown after onboarding, before the app lands on The Field.
 */
@Composable
fun DifferentiationScreen(onDismiss: () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = HarvestTheme.Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.xl,
            Alignment.CenterVertically
        ),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                Icons.Filled.Spa,
                contentDescription = null,
                tint = HarvestTheme.Colors.accent,
                modifier = Modifier.size(48.dp)
            )
            Text(
                text = "Dating, done differently",
                style = HarvestTheme.Typography.h1,
                color = HarvestTheme.Colors.textPrimary,
                textAlign = TextAlign.Center
            )
            Text(
                text = "Three things you won't find on other apps",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textSecondary,
                textAlign = TextAlign.Center
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)) {
            Differentiator(
                icon = Icons.Filled.AutoAwesome,
                title = "AI Coach",
                body = "The Gardener helps you reflect, communicate better, and grow."
            )
            Differentiator(
                icon = Icons.Filled.Favorite,
                title = "Values Matching",
                body = "Connect with people whose values line up with yours — " +
                    "not just their photos."
            )
            Differentiator(
                icon = Icons.Filled.GppMaybe,
                title = "Red-Flag Detection",
                body = "Safety analysis flags manipulative or unsafe behaviour in your chats."
            )
        }

        HarvestButton(
            text = "Meet your Gardener",
            icon = Icons.Filled.Spa,
            kind = HarvestButtonKind.PRIMARY,
            modifier = Modifier.fillMaxWidth(),
            onClick = onDismiss
        )
    }
}

@Composable
private fun Differentiator(icon: ImageVector, title: String, body: String) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.lg)
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.glassFill, shape)
            .border(1.dp, HarvestTheme.Colors.border, shape)
            .padding(HarvestTheme.Spacing.md)
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = HarvestTheme.Colors.accent,
            modifier = Modifier.size(24.dp)
        )
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = title,
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary
            )
            Text(
                text = body,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary
            )
        }
        Spacer(Modifier.weight(1f))
    }
}
