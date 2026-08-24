package com.harvestglass.harvest.ui.components.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Components/Chat/ChatComposer.swift.
 *
 * A rounded field plus a send button with three states — disabled, ready,
 * and in-flight.
 */
@Composable
fun ChatComposer(
    text: String,
    onTextChange: (String) -> Unit,
    accent: ChatAccent,
    placeholder: String,
    isSending: Boolean,
    onSend: () -> Unit,
    modifier: Modifier = Modifier,
    accessory: @Composable (() -> Unit)? = null
) {
    val canSend = text.trim().isNotEmpty() && !isSending
    val pill = RoundedCornerShape(percent = 50)

    Column(
        modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.wineBlack)
            // safeDrawing's bottom is max(navigation bar, keyboard), so the
            // composer clears the gesture bar without double-padding when the
            // keyboard is open.
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Bottom))
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(HarvestTheme.Colors.border)
        )

        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    horizontal = HarvestTheme.Spacing.md,
                    vertical = HarvestTheme.Spacing.sm
                )
        ) {
            accessory?.invoke()

            BasicTextField(
                value = text,
                onValueChange = onTextChange,
                maxLines = 5,
                textStyle = LocalTextStyle.current.merge(
                    TextStyle(color = HarvestTheme.Colors.textPrimary)
                ),
                cursorBrush = SolidColor(accent.base),
                modifier = Modifier
                    .weight(1f)
                    .semantics { contentDescription = placeholder },
                decorationBox = { innerTextField ->
                    Box(
                        Modifier
                            .background(HarvestTheme.Colors.wineRaised, pill)
                            .border(1.dp, HarvestTheme.Colors.border, pill)
                            .padding(horizontal = HarvestTheme.Spacing.md, vertical = 10.dp),
                        contentAlignment = Alignment.CenterStart
                    ) {
                        if (text.isEmpty()) {
                            Text(
                                text = placeholder,
                                style = HarvestTheme.Typography.bodyRegular,
                                color = HarvestTheme.Colors.textTertiary
                            )
                        }
                        innerTextField()
                    }
                }
            )

            SendButton(canSend = canSend, isSending = isSending, accent = accent, onSend = onSend)
        }
    }
}

@Composable
private fun SendButton(
    canSend: Boolean,
    isSending: Boolean,
    accent: ChatAccent,
    onSend: () -> Unit
) {
    Box(
        modifier = Modifier
            .padding(bottom = 2.dp)
            .size(36.dp)
            .background(
                if (canSend) {
                    Brush.verticalGradient(listOf(accent.base, accent.deep))
                } else {
                    SolidColor(HarvestTheme.Colors.textTertiary.copy(alpha = 0.25f))
                },
                CircleShape
            )
            .semantics { contentDescription = "Send" }
            .clickable(enabled = canSend, onClick = onSend),
        contentAlignment = Alignment.Center
    ) {
        if (isSending) {
            CircularProgressIndicator(
                color = HarvestTheme.Colors.textInverse,
                strokeWidth = 2.dp,
                modifier = Modifier.size(18.dp)
            )
        } else {
            Icon(
                imageVector = Icons.Filled.ArrowUpward,
                contentDescription = null,
                tint = if (canSend) {
                    HarvestTheme.Colors.textInverse
                } else {
                    HarvestTheme.Colors.textTertiary
                },
                modifier = Modifier.size(15.dp)
            )
        }
    }
}
