import SwiftUI

struct SubscriptionView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = SubscriptionViewModel()
    @State private var showPurchaseSheet = false
    @State private var selectedTier: SubscriptionTier?
    @State private var billingPeriod: BillingPeriod = .monthly

    var body: some View {
        ScrollView {
            VStack(spacing: HarvestTheme.Spacing.lg) {
                Text("Choose Your Plan")
                    .font(HarvestTheme.Typography.h2)
                    .padding(.top)

                Text("Unlock premium features to grow your connections")
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                ForEach(viewModel.tiers) { tier in
                    tierCard(tier)
                }
            }
            .padding()
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .background(HarvestTheme.Colors.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Restore") {
                    Task {
                        if let userId = authViewModel.currentUserId {
                            await viewModel.restorePurchases(userId: userId)
                        }
                    }
                }
                .font(HarvestTheme.Typography.bodySmall)
            }
        }
        .task {
            if let userId = authViewModel.currentUserId {
                await viewModel.loadSubscriptionData(userId: userId)
                await viewModel.loadProducts()
                await viewModel.checkSubscriptionStatus(userId: userId)
            }
        }
        .sheet(isPresented: $showPurchaseSheet) {
            if let tier = selectedTier {
                PurchaseSheet(
                    tier: tier,
                    viewModel: viewModel,
                    authViewModel: authViewModel,
                    billingPeriod: $billingPeriod
                )
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func tierCard(_ tier: SubscriptionTier) -> some View {
        let isCurrent = viewModel.isCurrentTier(tier)

        return GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                HStack {
                    Image(systemName: tierIcon(tier.name))
                        .font(.title2)
                        .foregroundStyle(tierColor(tier.name))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(tier.displayName)
                                .font(HarvestTheme.Typography.h3)

                            if tier.name == .green {
                                GlassBadge(text: "Most Popular", color: HarvestTheme.Colors.accent)
                            }
                        }

                        Text(tier.description)
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        if tier.priceMonthly == 0 {
                            Text("Free")
                                .font(HarvestTheme.Typography.h3)
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        } else {
                            Text("$\(String(format: "%.2f", tier.priceMonthly))")
                                .font(HarvestTheme.Typography.h3)
                            Text("/month")
                                .font(HarvestTheme.Typography.caption)
                                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                    featureRow("Matches/week", value: tier.matchesPerWeek.map { "\($0)" } ?? "Unlimited")
                    featureRow("Distance", value: tier.maxDistanceMiles.map { "\($0) mi" } ?? "Unlimited")
                    featureRow("Gardener chats/day", value: tier.gardenerConversationsPerDay.map { "\($0)" } ?? "Unlimited")
                    featureRow("Character limit", value: "\(tier.gardenerCharacterLimit / 1000)k")
                    featureCheck("Values matching", enabled: tier.hasValuesMatching)
                    featureCheck("Advanced filters", enabled: tier.hasAdvancedFilters)
                    featureCheck("Full filters", enabled: tier.hasFullFilters)
                    featureCheck("See who likes you", enabled: tier.canSeeLikes)
                    featureCheck("Disable mindful messaging", enabled: tier.canDisableMindfulMessaging)
                }

                if isCurrent {
                    HStack {
                        Spacer()
                        HStack(spacing: HarvestTheme.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Current Plan")
                        }
                        .font(HarvestTheme.Typography.buttonText)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                } else if tier.name != .seed {
                    GlassButton(title: "Upgrade to \(tier.displayName)", style: .primary) {
                        selectedTier = tier
                        showPurchaseSheet = true
                    }
                }
            }
        }
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                    .stroke(HarvestTheme.Colors.accent, lineWidth: 2)
            }
        }
    }

    private func featureRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(.semibold)
        }
    }

    private func featureCheck(_ label: String, enabled: Bool) -> some View {
        HStack {
            Text(label)
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(enabled ? HarvestTheme.Colors.accent : HarvestTheme.Colors.textTertiary)
        }
    }

    private func tierIcon(_ name: TierName) -> String {
        switch name {
        case .seed: return "leaf"
        case .green: return "leaf.fill"
        case .gold: return "crown.fill"
        }
    }

    private func tierColor(_ name: TierName) -> Color {
        switch name {
        case .seed: return HarvestTheme.Colors.textPrimary
        case .green: return HarvestTheme.Colors.accent
        case .gold: return Color(hex: "F59E0B")
        }
    }
}
