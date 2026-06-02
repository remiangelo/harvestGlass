import SwiftUI

/// Legend explaining the four radar tiers (Low Presence → Core Value) with the
/// growth-metaphor icons and raw score ranges. Driven entirely by `ValuesTier`.
struct ValuesPresenceGuide: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text("Values Presence Guide")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.rose)

                HStack(alignment: .top, spacing: HarvestTheme.Spacing.sm) {
                    ForEach(ValuesTier.allCases, id: \.self) { tier in
                        column(for: tier)
                    }
                }
            }
        }
    }

    private func column(for tier: ValuesTier) -> some View {
        VStack(spacing: HarvestTheme.Spacing.xs) {
            Image(systemName: tier.iconName)
                .font(.title3)
                .foregroundStyle(HarvestTheme.Colors.rose)

            Text(tier.levelLabel)
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)

            Text(tier.displayName)
                .font(HarvestTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.roseLight)
                .multilineTextAlignment(.center)

            Text(tier.rangeLabel)
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)

            Text(tier.ringLabel)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Short explanatory footer shown beneath the alignment radar + guide.
struct ValuesAlignmentInfoFooter: View {
    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: HarvestTheme.Spacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundStyle(HarvestTheme.Colors.rose)
                Text("Higher tiers extend farther from the center. Greater overlap = stronger alignment.")
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                Spacer(minLength: 0)
            }
        }
    }
}
