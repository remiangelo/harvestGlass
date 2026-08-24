package com.harvestglass.harvest.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import com.harvestglass.harvest.ui.theme.HarvestTheme

/** Renders one of the three legal documents. */
@Composable
fun LegalScreen(document: LegalDocument, onBack: () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        SettingsTopBar(title = document.title, onBack = onBack)

        Column(
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.lg),
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(HarvestTheme.Spacing.md)
                .navigationBarsPadding()
        ) {
            Text(
                text = document.title,
                style = HarvestTheme.Typography.h2,
                color = HarvestTheme.Colors.textPrimary
            )

            document.sections.forEach { (title, body) ->
                Column(verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm)) {
                    Text(
                        text = title,
                        style = HarvestTheme.Typography.h4,
                        fontWeight = FontWeight.SemiBold,
                        color = HarvestTheme.Colors.textPrimary
                    )
                    Text(
                        text = body,
                        style = HarvestTheme.Typography.bodyRegular,
                        color = HarvestTheme.Colors.textSecondary
                    )
                }
            }
        }
    }
}
