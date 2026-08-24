package com.harvestglass.harvest.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.GlassCardStyle
import com.harvestglass.harvest.ui.components.SectionHeader
import com.harvestglass.harvest.ui.safety.SafetyDashboardScreen
import com.harvestglass.harvest.ui.subscription.SubscriptionScreen
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Which sub-screen Settings has pushed, if any. */
enum class SettingsRoute { SUBSCRIPTION, PRIVACY_POLICY, TERMS, GUIDELINES, HELP, SAFETY }

/**
 * Port of Harvest/Views/Settings/SettingsView.swift.
 */
@Composable
fun SettingsScreen(
    userId: String,
    onBack: () -> Unit,
    onSignOut: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var route by remember { mutableStateOf<SettingsRoute?>(null) }
    var showLogoutDialog by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }

    LaunchedEffect(userId) { viewModel.load(userId) }

    route?.let { current ->
        when (current) {
            SettingsRoute.SUBSCRIPTION -> SubscriptionScreen(userId, onBack = { route = null })
            SettingsRoute.PRIVACY_POLICY -> LegalScreen(LegalDocument.PrivacyPolicy) { route = null }
            SettingsRoute.TERMS -> LegalScreen(LegalDocument.Terms) { route = null }
            SettingsRoute.GUIDELINES -> LegalScreen(LegalDocument.Guidelines) { route = null }
            SettingsRoute.HELP -> HelpCenterScreen { route = null }
            SettingsRoute.SAFETY -> SafetyDashboardScreen(userId, onBack = { route = null })
        }
        return
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
    ) {
        SettingsTopBar(title = "Settings", onBack = onBack)

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            SectionHeader("Account")
            GlassCard(style = GlassCardStyle.LIGHT) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { route = SettingsRoute.SUBSCRIPTION }
                ) {
                    Text(
                        text = "Subscription",
                        style = HarvestTheme.Typography.bodyRegular,
                        color = HarvestTheme.Colors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = HarvestTheme.Colors.textTertiary
                    )
                }
            }

            SectionHeader("Notifications")
            GlassCard(style = GlassCardStyle.LIGHT) {
                ToggleRow("Enable Notifications", state.notificationsEnabled) {
                    viewModel.setNotificationsEnabled(userId, it)
                }
                if (state.notificationsEnabled) {
                    ToggleRow("New Matches", state.matchesEnabled) {
                        viewModel.setPref(userId, NotificationPref.MATCHES, it)
                    }
                    ToggleRow("Messages", state.messagesEnabled) {
                        viewModel.setPref(userId, NotificationPref.MESSAGES, it)
                    }
                    ToggleRow("Inbound Likes (Gold)", state.likesEnabled) {
                        viewModel.setPref(userId, NotificationPref.LIKES, it)
                    }
                    ToggleRow("Gardener Daily Reminder", state.gardenerEnabled) {
                        viewModel.setPref(userId, NotificationPref.GARDENER, it)
                    }
                }
                state.error?.let {
                    Text(
                        text = it,
                        style = HarvestTheme.Typography.caption,
                        color = HarvestTheme.Colors.warning
                    )
                }
            }

            SectionHeader("Legal")
            GlassCard(style = GlassCardStyle.LIGHT) {
                NavRow("Privacy Policy") { route = SettingsRoute.PRIVACY_POLICY }
                NavRow("Terms of Service") { route = SettingsRoute.TERMS }
                NavRow("Community Guidelines") { route = SettingsRoute.GUIDELINES }
            }

            SectionHeader("Safety")
            GlassCard(style = GlassCardStyle.LIGHT) {
                NavRow("Safety Dashboard") { route = SettingsRoute.SAFETY }
                ToggleRow("Mindful Messaging", state.mindfulMessagingEnabled) {
                    viewModel.setMindfulMessagingEnabled(it)
                }
            }

            SectionHeader("Support")
            GlassCard(style = GlassCardStyle.LIGHT) {
                NavRow("Help Center") { route = SettingsRoute.HELP }
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "Version",
                        style = HarvestTheme.Typography.bodyRegular,
                        color = HarvestTheme.Colors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        text = "1.0.0",
                        style = HarvestTheme.Typography.bodySmall,
                        color = HarvestTheme.Colors.textSecondary
                    )
                }
            }

            GlassCard(style = GlassCardStyle.LIGHT) {
                DestructiveRow("Log Out") { showLogoutDialog = true }
                DestructiveRow("Delete Account") { showDeleteDialog = true }
            }
        }
    }

    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text("Log Out") },
            text = { Text("Are you sure you want to log out?") },
            confirmButton = {
                TextButton(onClick = { showLogoutDialog = false; onSignOut() }) {
                    Text("Log Out", color = HarvestTheme.Colors.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutDialog = false }) { Text("Cancel") }
            }
        )
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete Account") },
            text = {
                Text(
                    "This will permanently delete your account, profile, matches, " +
                        "and all messages. This action cannot be undone."
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        viewModel.deleteAccount(userId, onDeleted = onSignOut)
                    }
                ) { Text("Delete", color = HarvestTheme.Colors.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
fun SettingsTopBar(title: String, onBack: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineBlack)
            .statusBarsPadding()
            .padding(HarvestTheme.Spacing.md)
    ) {
        Icon(
            Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Back",
            tint = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.clickable { onBack() }
        )
        Text(
            text = title,
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary
        )
    }
}

@Composable
private fun ToggleRow(label: String, isOn: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = HarvestTheme.Spacing.xs)
    ) {
        Text(
            text = label,
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.weight(1f)
        )
        Switch(
            checked = isOn,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = HarvestTheme.Colors.pureWhite,
                checkedTrackColor = HarvestTheme.Colors.primary,
                uncheckedThumbColor = HarvestTheme.Colors.pureWhite,
                uncheckedTrackColor = HarvestTheme.Colors.textTertiary.copy(alpha = 0.5f)
            )
        )
    }
}

@Composable
private fun NavRow(label: String, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = HarvestTheme.Spacing.sm)
    ) {
        Text(
            text = label,
            style = HarvestTheme.Typography.bodyRegular,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.weight(1f)
        )
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = HarvestTheme.Colors.textTertiary
        )
    }
}

@Composable
private fun DestructiveRow(label: String, onClick: () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = HarvestTheme.Spacing.sm),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            style = HarvestTheme.Typography.bodyRegular,
            fontWeight = FontWeight.SemiBold,
            color = HarvestTheme.Colors.formAccent
        )
    }
}
