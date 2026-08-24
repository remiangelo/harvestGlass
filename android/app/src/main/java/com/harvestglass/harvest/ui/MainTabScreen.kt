package com.harvestglass.harvest.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import com.harvestglass.harvest.data.model.Community
import com.harvestglass.harvest.ui.auth.AuthUiState
import com.harvestglass.harvest.ui.components.GlassButton
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.field.CommunityChatScreen
import com.harvestglass.harvest.ui.field.FieldScreen
import com.harvestglass.harvest.ui.chat.ChatDetailScreen
import com.harvestglass.harvest.ui.seeds.SeedsScreen
import com.harvestglass.harvest.ui.values.ValuesScreen
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/MainTabView.swift. Order and landing tab match iOS.
 * Icons are the nearest material-icons-extended equivalents to the SF Symbols
 * the Swift file names.
 */
enum class HarvestTab(val title: String, val icon: ImageVector) {
    SOIL("Soil", Icons.Filled.Favorite),          // heart.text.square.fill
    FIELD("The Field", Icons.Filled.Eco),         // leaf.circle.fill
    GARDENER("Gardener", Icons.Filled.Spa),       // leaf.fill
    SEEDS("Seeds", Icons.Filled.Chat),            // bubble.left.fill
    PROFILE("Profile", Icons.Filled.Person)       // person.fill
}

/** Port of MainTabView.handleDeepLink. Returns null when nothing should change. */
fun deepLinkTab(link: String): HarvestTab? = when {
    link.startsWith("chat:") -> HarvestTab.SEEDS
    // All connection events open the Seeds tab.
    link.startsWith("seed:") || link == "seeds" || link.startsWith("match:") -> HarvestTab.SEEDS
    link == "gardener" -> HarvestTab.GARDENER
    link.startsWith("community:") -> HarvestTab.FIELD
    else -> null
}

@Composable
fun MainTabScreen(state: AuthUiState, onSignOut: () -> Unit) {
    // iOS lands on The Field (selection = 1).
    var selected by remember { mutableStateOf(HarvestTab.FIELD) }
    var openRoom by remember { mutableStateOf<Community?>(null) }
    var openChat by remember { mutableStateOf<Pair<String, String>?>(null) }

    val chat = openChat
    if (chat != null) {
        ChatDetailScreen(
            conversationId = chat.first,
            userId = state.currentUserId.orEmpty(),
            partnerUserId = chat.second,
            onBack = { openChat = null }
        )
        return
    }

    val room = openRoom
    if (room != null) {
        CommunityChatScreen(
            community = room,
            userId = state.currentUserId.orEmpty(),
            onBack = { openRoom = null }
        )
        return
    }

    Scaffold(
        containerColor = HarvestTheme.Colors.background,
        bottomBar = {
            NavigationBar(containerColor = HarvestTheme.Colors.tabBarBackground) {
                HarvestTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selected == tab,
                        onClick = { selected = tab },
                        icon = { Icon(tab.icon, contentDescription = tab.title) },
                        label = { Text(tab.title, style = HarvestTheme.Typography.caption) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = HarvestTheme.Colors.rose,
                            selectedTextColor = HarvestTheme.Colors.rose,
                            unselectedIconColor = HarvestTheme.Colors.textTertiary,
                            unselectedTextColor = HarvestTheme.Colors.textTertiary,
                            indicatorColor = HarvestTheme.Colors.tabBarBackground
                        )
                    )
                }
            }
        }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (selected) {
                HarvestTab.FIELD -> FieldScreen(
                    userId = state.currentUserId.orEmpty(),
                    onOpenRoom = { openRoom = it }
                )
                HarvestTab.SOIL -> ValuesScreen(userId = state.currentUserId.orEmpty())
                HarvestTab.SEEDS -> SeedsScreen(
                    userId = state.currentUserId.orEmpty(),
                    onOpenConversation = { conversationId, partnerId ->
                        openChat = conversationId to partnerId
                    }
                )
                HarvestTab.PROFILE -> ComingLaterScreen(tab = selected, onSignOut = onSignOut)
                else -> ComingLaterScreen(tab = selected, onSignOut = null)
            }
        }
    }
}

/** Placeholder for the tabs that port in P2. */
@Composable
private fun ComingLaterScreen(tab: HarvestTab, onSignOut: (() -> Unit)?) {
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
                    text = tab.title,
                    style = HarvestTheme.Typography.h4,
                    color = HarvestTheme.Colors.textPrimary
                )
                Text(
                    text = "Coming in a later phase of the Android port.",
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary,
                    textAlign = TextAlign.Center
                )
                if (onSignOut != null) {
                    GlassButton(
                        title = "Sign Out",
                        style = HarvestButtonKind.SECONDARY,
                        onClick = onSignOut
                    )
                }
            }
        }
    }
}
