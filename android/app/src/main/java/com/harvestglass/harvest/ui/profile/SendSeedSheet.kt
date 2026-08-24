package com.harvestglass.harvest.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.components.GlassCard
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Seeds/SendSeedSheet.swift.
 *
 * The daily count and limit are passed in rather than fetched here, so the
 * profile screen's single load covers both.
 */
@Composable
fun SendSeedSheet(
    recipientName: String,
    sentToday: Int,
    limit: Int,
    isSending: Boolean,
    error: String?,
    onSend: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var message by remember { mutableStateOf("") }
    val atLimit = sentToday >= limit
    val canSend = message.isNotBlank() && !isSending && !atLimit

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
            .imePadding()
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(HarvestTheme.Colors.wineBlack)
                .statusBarsPadding()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Text(
                text = "Cancel",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.accent,
                modifier = Modifier.clickable { onDismiss() }
            )
            Text(
                text = "Send a Seed",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = HarvestTheme.Spacing.md)
            )
            Text(
                text = if (isSending) "Sending…" else "Send",
                style = HarvestTheme.Typography.bodyRegular,
                fontWeight = FontWeight.SemiBold,
                color = if (canSend) {
                    HarvestTheme.Colors.accent
                } else {
                    HarvestTheme.Colors.textTertiary
                },
                modifier = Modifier.clickable(enabled = canSend) { onSend(message) }
            )
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            Text(
                text = "Plant a Seed with $recipientName 🌱",
                style = HarvestTheme.Typography.h3,
                color = HarvestTheme.Colors.textPrimary
            )
            Text(
                text = "Start with something intentional — a question or a shared value.",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textSecondary
            )

            GlassCard {
                BasicTextField(
                    value = message,
                    onValueChange = { message = it },
                    textStyle = LocalTextStyle.current.merge(
                        TextStyle(color = HarvestTheme.Colors.textPrimary)
                    ),
                    cursorBrush = SolidColor(HarvestTheme.Colors.accent),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 150.dp),
                    decorationBox = { innerTextField ->
                        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopStart) {
                            if (message.isEmpty()) {
                                Text(
                                    text = "What made you want to reach out?",
                                    style = HarvestTheme.Typography.bodyRegular,
                                    color = HarvestTheme.Colors.textTertiary
                                )
                            }
                            innerTextField()
                        }
                    }
                )
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)
            ) {
                Icon(
                    Icons.Filled.Spa,
                    contentDescription = null,
                    tint = if (atLimit) HarvestTheme.Colors.error else HarvestTheme.Colors.textSecondary,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = "$sentToday of $limit Seeds sent today",
                    style = HarvestTheme.Typography.caption,
                    color = if (atLimit) {
                        HarvestTheme.Colors.error
                    } else {
                        HarvestTheme.Colors.textSecondary
                    }
                )
            }

            error?.let {
                Text(
                    text = it,
                    style = HarvestTheme.Typography.caption,
                    color = HarvestTheme.Colors.error
                )
            }
        }
    }
}
