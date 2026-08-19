package com.harvestglass.harvest.ui.values

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.data.model.Question
import com.harvestglass.harvest.ui.components.GlassButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Values/QuestionSheetView.swift.
 *
 * Presents one unanswered question at a time; answering it removes it from the
 * queue, so the next appears without any explicit paging.
 */
@Composable
fun QuestionSheet(
    unanswered: List<Question>,
    onAnswer: (questionId: String, optionId: String) -> Unit,
    onDismiss: () -> Unit
) {
    val current = unanswered.firstOrNull()

    Column(
        Modifier
            .fillMaxSize()
            .background(HarvestTheme.Colors.background)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(HarvestTheme.Spacing.md)
        ) {
            Text(
                text = "More questions",
                style = HarvestTheme.Typography.h4,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = "Done",
                style = HarvestTheme.Typography.bodyRegular,
                fontWeight = FontWeight.SemiBold,
                color = HarvestTheme.Colors.textPrimary,
                modifier = Modifier.clickable { onDismiss() }
            )
        }

        Box(
            Modifier
                .fillMaxSize()
                .padding(
                    horizontal = HarvestTheme.Spacing.lg,
                    vertical = HarvestTheme.Spacing.lg
                )
        ) {
            if (current != null) {
                QuestionBody(current, onAnswer)
            } else {
                AllAnswered(onDismiss)
            }
        }
    }
}

@Composable
private fun QuestionBody(question: Question, onAnswer: (String, String) -> Unit) {
    Column(
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = question.prompt,
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.roseLight
        )

        question.options.forEach { option ->
            val shape = RoundedCornerShape(HarvestTheme.Radius.md)
            Row(
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                modifier = Modifier
                    .fillMaxWidth()
                    // iOS tints this with Liquid Glass; a translucent fill over
                    // the cream page is the closest Android equivalent.
                    .background(HarvestTheme.Colors.roseLight.copy(alpha = 0.18f), shape)
                    .border(1.dp, HarvestTheme.Colors.roseLight.copy(alpha = 0.45f), shape)
                    .clickable { onAnswer(question.id, option.id) }
                    .padding(HarvestTheme.Spacing.md)
            ) {
                Icon(
                    imageVector = Icons.Filled.RadioButtonUnchecked,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.roseLight
                )
                Text(
                    text = option.label,
                    style = HarvestTheme.Typography.bodyRegular,
                    color = HarvestTheme.Colors.textPrimary
                )
            }
        }
    }
}

@Composable
private fun AllAnswered(onDismiss: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(
            HarvestTheme.Spacing.md,
            Alignment.CenterVertically
        ),
        modifier = Modifier.fillMaxSize()
    ) {
        Icon(
            imageVector = Icons.Filled.Verified,
            contentDescription = null,
            tint = HarvestTheme.Colors.accent,
            modifier = Modifier.size(40.dp)
        )
        Text(
            text = "You've answered everything for now.",
            style = HarvestTheme.Typography.h4,
            color = HarvestTheme.Colors.textPrimary,
            textAlign = TextAlign.Center
        )
        Text(
            text = "New questions will appear here as they're added.",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary,
            textAlign = TextAlign.Center
        )
        GlassButton(title = "Done", style = HarvestButtonKind.PRIMARY, onClick = onDismiss)
    }
}
