import SwiftUI
import StoreKit

struct PurchaseSheet: View {
    let tier: SubscriptionTier
    let viewModel: SubscriptionViewModel
    let authViewModel: AuthViewModel
    @Binding var billingPeriod: BillingPeriod
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.xl) {
                    // Header
                    VStack(spacing: HarvestTheme.Spacing.md) {
                        Image(systemName: tierIcon)
                            .font(.system(size: 60))
                            .foregroundStyle(tierColor)

                        Text("Upgrade to \(tier.displayName)")
                            .font(HarvestTheme.Typography.h2)

                        Text(tier.description)
                            .font(HarvestTheme.Typography.bodyRegular)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Billing Period Selector
                    Picker("Billing Period", selection: $billingPeriod) {
                        Text("Monthly").tag(BillingPeriod.monthly)
                        Text("Yearly (Save \(yearlySavingsPercent)%)").tag(BillingPeriod.yearly)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Price Display
                    if let product = viewModel.getProduct(for: tier, billingPeriod: billingPeriod) {
                        VStack(spacing: HarvestTheme.Spacing.sm) {
                            Text(product.displayPrice)
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(HarvestTheme.Colors.accent)

                            Text(billingPeriod == .monthly ? "per month" : "per year")
                                .font(HarvestTheme.Typography.bodyRegular)
                                .foregroundStyle(HarvestTheme.Colors.textSecondary)

                            if billingPeriod == .yearly {
                                Text("That's \(monthlyEquivalent(product)) per month")
                                    .font(HarvestTheme.Typography.caption)
                                    .foregroundStyle(HarvestTheme.Colors.textTertiary)
                            }
                        }
                        .padding(.vertical)
                    }

                    // Features
                    GlassCard {
                        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                            Text("What you get:")
                                .font(HarvestTheme.Typography.h3)

                            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                featureRow("Matches per week", value: tier.matchesPerWeek.map { "\($0)" } ?? "Unlimited")
                                featureRow("Search distance", value: tier.maxDistanceMiles.map { "\($0) miles" } ?? "Unlimited")
                                featureRow("Gardener chats/day", value: tier.gardenerConversationsPerDay.map { "\($0)" } ?? "Unlimited")
                                featureRow("Gardener character limit", value: "\(tier.gardenerCharacterLimit / 1000)k")

                                if tier.hasValuesMatching {
                                    featureCheck("Deep values-based matching")
                                }
                                if tier.hasAdvancedFilters {
                                    featureCheck("Advanced discovery filters")
                                }
                                if tier.hasFullFilters {
                                    featureCheck("Complete filter control")
                                }
                                if tier.canSeeLikes {
                                    featureCheck("See who likes you")
                                }
                                if tier.canDisableMindfulMessaging {
                                    featureCheck("Optional mindful messaging")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Purchase Button
                    if let product = viewModel.getProduct(for: tier, billingPeriod: billingPeriod) {
                        GlassButton(
                            title: viewModel.isPurchasing ? "Processing..." : "Subscribe Now",
                            style: .primary
                        ) {
                            Task {
                                if let userId = authViewModel.currentUserId {
                                    await viewModel.purchase(product: product, userId: userId)
                                    if viewModel.error == nil {
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .disabled(viewModel.isPurchasing)
                        .padding(.horizontal)
                    } else {
                        Text("Loading product information...")
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    }

                    // Fine Print
                    VStack(spacing: HarvestTheme.Spacing.xs) {
                        Text("Payment will be charged to your Apple ID account at confirmation of purchase.")
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                            .multilineTextAlignment(.center)

                        Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, HarvestTheme.Spacing.xl)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var tierIcon: String {
        switch tier.name {
        case .seed: return "leaf"
        case .green: return "leaf.fill"
        case .gold: return "crown.fill"
        }
    }

    private var tierColor: Color {
        switch tier.name {
        case .seed: return HarvestTheme.Colors.textPrimary
        case .green: return HarvestTheme.Colors.accent
        case .gold: return Color(hex: "F59E0B")
        }
    }

    private var yearlySavingsPercent: Int {
        guard tier.priceYearly > 0, tier.priceMonthly > 0 else { return 0 }
        let monthlyCost = tier.priceMonthly * 12
        let savings = ((monthlyCost - tier.priceYearly) / monthlyCost) * 100
        return Int(savings)
    }

    private func monthlyEquivalent(_ product: Product) -> String {
        guard billingPeriod == .yearly else { return "" }
        let monthly = product.price / 12
        return monthly.formatted(.currency(code: product.priceFormatStyle.currencyCode))
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

    private func featureCheck(_ label: String) -> some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HarvestTheme.Colors.accent)
            Text(label)
                .font(HarvestTheme.Typography.bodySmall)
            Spacer()
        }
    }
}
