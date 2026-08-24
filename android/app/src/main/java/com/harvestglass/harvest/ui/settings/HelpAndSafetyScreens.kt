package com.harvestglass.harvest.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.components.GlassCardStyle
import com.harvestglass.harvest.ui.components.SectionHeader
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of the FAQ half of Harvest/Views/Help/HelpCenterView.swift.
 *
 * The contact-support form is not ported: it writes to the support table
 * through a flow that belongs with the Safety subsystem, and a form that
 * silently goes nowhere would be worse than none.
 */
@Composable
fun HelpCenterScreen(onBack: () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
    ) {
        SettingsTopBar(title = "Help Center", onBack = onBack)

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            SectionHeader("Frequently Asked Questions")
            FAQS.forEach { (question, answer) -> FaqRow(question, answer) }

            SectionHeader("Contact")
            GlassCard(style = GlassCardStyle.LIGHT) {
                Text(
                    text = "Need a hand? Email support@harvestglass.com and we'll get back to you.",
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textSecondary
                )
            }
        }
    }
}

@Composable
private fun FaqRow(question: String, answer: String) {
    var expanded by remember { mutableStateOf(false) }

    GlassCard(style = GlassCardStyle.LIGHT) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = !expanded }
        ) {
            Text(
                text = question,
                style = HarvestTheme.Typography.bodyRegular,
                fontWeight = FontWeight.SemiBold,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            Icon(
                imageVector = if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                contentDescription = null,
                tint = HarvestTheme.Colors.textTertiary
            )
        }
        if (expanded) {
            Text(
                text = answer,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.textSecondary,
                modifier = Modifier.padding(top = HarvestTheme.Spacing.sm)
            )
        }
    }
}

private val FAQS = listOf(
    "How do Seeds work?" to
        "A Seed is an opening message. Send one to someone you'd like to talk to; if they " +
        "accept it, the two of you get a private conversation.",
    "What is The Field?" to
        "The Field is where community rooms live. Join the spaces that match your season " +
        "and talk with everyone in them.",
    "What is my values map?" to
        "Answering the reflection questions builds a five-axis picture of what you bring to " +
        "a relationship and what you need from one. It's what Harvest matches on.",
    "Who can see my profile?" to
        "Other members can see the profile fields you've chosen to show. You control each " +
        "of those from the Soil tab.",
    "How do I report someone?" to
        "Open the conversation, tap the menu in the top right, and choose Report or Block. " +
        "Reports are reviewed within 24 hours."
)

/**
 * Port of the read-only half of Harvest/Views/Safety/SafetyDashboardView.swift.
 *
 * The per-conversation safety analysis is OpenAI-backed and lands with the AI
 * subsystem; what remains here is the guidance and the blocking controls the
 * user can act on without it.
 */
@Composable
fun SafetyDashboardScreen(onBack: () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.formBackground)
    ) {
        SettingsTopBar(title = "Safety", onBack = onBack)

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            GlassCard(style = GlassCardStyle.LIGHT) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)
                ) {
                    Icon(
                        Icons.Filled.Shield,
                        contentDescription = null,
                        tint = HarvestTheme.Colors.primary,
                        modifier = Modifier.size(24.dp)
                    )
                    Text(
                        text = "Staying safe on Harvest",
                        style = HarvestTheme.Typography.h4,
                        color = HarvestTheme.Colors.textPrimary
                    )
                }
            }

            SectionHeader("Guidance")
            SAFETY_TIPS.forEach { (title, body) ->
                GlassCard(style = GlassCardStyle.LIGHT) {
                    Text(
                        text = title,
                        style = HarvestTheme.Typography.bodyRegular,
                        fontWeight = FontWeight.SemiBold,
                        color = HarvestTheme.Colors.textPrimary
                    )
                    Text(
                        text = body,
                        style = HarvestTheme.Typography.bodySmall,
                        color = HarvestTheme.Colors.textSecondary,
                        modifier = Modifier.padding(top = HarvestTheme.Spacing.xs)
                    )
                }
            }

            SectionHeader("Zero tolerance")
            GlassCard(style = GlassCardStyle.LIGHT) {
                Text(
                    text = "There is zero tolerance for objectionable content or abusive " +
                        "behavior. Violations result in content removal and account " +
                        "termination, reviewed within 24 hours.",
                    style = HarvestTheme.Typography.bodySmall,
                    color = HarvestTheme.Colors.textPrimary
                )
            }
        }
    }
}

private val SAFETY_TIPS = listOf(
    "Keep it in the app" to
        "Keep conversations here until you trust someone. Harvest can't help with anything " +
        "that happens on another platform.",
    "Don't share contact details early" to
        "Phone numbers, addresses and payment details belong to a connection you've already built.",
    "Report anything that feels wrong" to
        "Use Report or Block from a conversation's menu. Blocking also files a report for review.",
    "Meet in public the first time" to
        "Tell someone you trust where you're going, and arrange your own way home."
)
