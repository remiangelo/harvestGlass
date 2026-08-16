package com.harvestglass.harvest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.harvestglass.harvest.ui.auth.AuthViewModel
import com.harvestglass.harvest.ui.auth.LoginScreen
import com.harvestglass.harvest.ui.components.GlassButton
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of the root gating in Harvest/HarvestApp.swift:
 *   isLoading → LaunchScreen
 *   !isAuthenticated → Login
 *   needsOnboarding → Onboarding
 *   else → MainTab
 */
@Composable
fun HarvestApp(authViewModel: AuthViewModel = hiltViewModel()) {
    val state by authViewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { authViewModel.checkSession() }

    when {
        state.isLoading -> LaunchScreen()

        !state.isAuthenticated -> LoginScreen(
            state = state,
            onLogin = authViewModel::login,
            onRegister = authViewModel::register
        )

        state.needsOnboarding -> OnboardingPlaceholderScreen(onSignOut = authViewModel::logout)

        else -> MainTabScreen(state = state, onSignOut = authViewModel::logout)
    }
}

/**
 * Deliberate, labelled stub. The real onboarding flow ports in P2 and
 * replaces this wholesale; until then an incomplete profile is directed to
 * the iOS app rather than being silently let through.
 */
@Composable
fun OnboardingPlaceholderScreen(onSignOut: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
            .padding(HarvestTheme.Spacing.lg),
        contentAlignment = Alignment.Center
    ) {
        GlassCard {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)
            ) {
                Text(
                    text = "Finish setting up your profile",
                    style = HarvestTheme.Typography.h4,
                    color = HarvestTheme.Colors.textPrimary
                )
                Text(
                    text = "Onboarding is not on Android yet. Complete your profile in the iOS app and sign back in here.",
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary,
                    textAlign = TextAlign.Center
                )
                GlassButton(
                    title = "Sign Out",
                    style = HarvestButtonKind.SECONDARY,
                    onClick = onSignOut
                )
            }
        }
    }
}
