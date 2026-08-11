import SwiftUI

/// Announcement only — there is no events feature yet. Deliberately
/// stateless: no dismiss, no persistence, nothing to fetch.
struct EventsComingSoonBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
            HStack(spacing: HarvestTheme.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("COMING SOON")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.8)
            }
            .foregroundStyle(HarvestTheme.Colors.accent)

            Text("Community events")
                .font(HarvestTheme.Typography.h3)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)

            Text("Online and in person. Gather with members near you — and everywhere.")
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: HarvestTheme.Spacing.sm) {
                modePill("Online", systemImage: "video.fill")
                modePill("In person", systemImage: "mappin.and.ellipse")
            }
            .padding(.top, HarvestTheme.Spacing.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HarvestTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            HarvestTheme.Colors.rose.opacity(0.14),
                            HarvestTheme.Colors.wineCard
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                        .stroke(HarvestTheme.Colors.rose.opacity(0.28), lineWidth: 1)
                }
        }
        .overlay(alignment: .topTrailing) {
            // Oversized leaf, clipped by the card — a watermark, not an icon.
            Image(systemName: "leaf.fill")
                .font(.system(size: 96))
                .foregroundStyle(HarvestTheme.Colors.fieldGreen.opacity(0.10))
                .rotationEffect(.degrees(-18))
                .offset(x: 22, y: -18)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
    }

    private func modePill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(HarvestTheme.Typography.caption)
            .foregroundStyle(HarvestTheme.Colors.accent)
            .padding(.horizontal, HarvestTheme.Spacing.sm)
            .padding(.vertical, HarvestTheme.Spacing.xs)
            .background {
                Capsule()
                    .fill(HarvestTheme.Colors.primarySoft)
                    .overlay {
                        Capsule().stroke(HarvestTheme.Colors.rose.opacity(0.22), lineWidth: 1)
                    }
            }
    }
}
