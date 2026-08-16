package com.harvestglass.harvest.ui.components.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestTheme
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * Port of Harvest/Views/Components/Chat/DateSeparator.swift.
 * A centred pill marking the day a run of messages belongs to.
 */
@Composable
fun DateSeparator(date: Instant) {
    val shape = RoundedCornerShape(percent = 50)
    Box(
        Modifier
            .fillMaxWidth()
            .padding(vertical = HarvestTheme.Spacing.sm),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = dateSeparatorLabel(date),
            style = HarvestTheme.Typography.caption,
            color = HarvestTheme.Colors.textSecondary,
            modifier = Modifier
                // Solid rather than translucent: a light blur over the cream
                // page reads as nothing at all.
                .background(HarvestTheme.Colors.wineRaised, shape)
                .border(1.dp, HarvestTheme.Colors.border, shape)
                .padding(horizontal = HarvestTheme.Spacing.md, vertical = HarvestTheme.Spacing.xs)
        )
    }
}

/**
 * [now] is injectable so the label is testable without freezing the clock.
 * Everything is derived from the day gap rather than an "is today" helper,
 * which would silently ignore an injected [now] and read the real clock.
 */
fun dateSeparatorLabel(date: Instant, now: Instant = Instant.now()): String {
    val zone = ZoneId.systemDefault()
    val then: LocalDate = date.atZone(zone).toLocalDate()
    val today: LocalDate = now.atZone(zone).toLocalDate()
    val days = ChronoUnit.DAYS.between(then, today)

    return when {
        days == 0L -> "Today"
        days == 1L -> "Yesterday"
        days in 2..6 -> then.format(DateTimeFormatter.ofPattern("EEEE", Locale.getDefault()))
        // Anything older than a week — or in the future, which shouldn't
        // happen but shouldn't render as a weekday either.
        else -> then.format(
            DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(Locale.getDefault())
        )
    }
}
