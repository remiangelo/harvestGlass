import SwiftUI
import StoreKit

struct PurchaseSheet: View {
    let tier: SubscriptionTier
    let viewModel: SubscriptionViewModel
    let authViewModel: AuthViewModel
    @Binding var billingPeriod: BillingPeriod
    @Environment(\.dismiss) private var dismiss

    private var selectedProduct: Product? {
        viewModel.getProduct(for: tier, billingPeriod: billingPeriod)
    }

    private var hasAnyStoreKitProducts: Bool {
        !viewModel.products.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.xl) {
                    // Header
                    VStack(spacing: HarvestTheme.Spacing.md) {
                        Image(systemName: tierIcon)
                            .font(.system(size: 60))
                            .foregroundStyle(tierColor)

                        Text("Upgrade to \(tier.marketingDisplayName)")
                            .font(HarvestTheme.Typography.h2)

                        Text(tier.description)
                            .font(HarvestTheme.Typography.bodyRegular)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Billing Period Selector
                    Picker("Billing Period", selection: $billingPeriod) {
                        Text("Weekly").tag(BillingPeriod.weekly)
                        Text("Monthly").tag(BillingPeriod.monthly)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Price Display
                    if let product = selectedProduct {
                        VStack(spacing: HarvestTheme.Spacing.sm) {
                            Text(product.displayPrice)
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)

                            Text(billingPeriod == .weekly ? "per week" : "per month")
                                .font(HarvestTheme.Typography.bodyRegular)
                                .foregroundStyle(HarvestTheme.Colors.textSecondary)
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
                    if let product = selectedProduct {
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
                    } else if hasAnyStoreKitProducts {
                        VStack(spacing: HarvestTheme.Spacing.sm) {
                            Text("This subscription product is not available right now.")
                                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)

                            Button("Retry") {
                                Task {
                                    await viewModel.loadProducts()
                                }
                            }
                            .font(HarvestTheme.Typography.bodySmall)
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: HarvestTheme.Spacing.sm) {
                            Text(viewModel.error ?? "Loading product information...")
                                .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)

                            Button("Retry") {
                                Task {
                                    await viewModel.loadProducts()
                                }
                            }
                            .font(HarvestTheme.Typography.bodySmall)
                        }
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
            .foregroundStyle(HarvestTheme.Colors.textPrimary)
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if viewModel.products.isEmpty {
                    await viewModel.loadProducts()
                }
            }
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

    private func featureRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(HarvestTheme.Typography.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
        }
    }

    private func featureCheck(_ label: String) -> some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HarvestTheme.Colors.accent)
            Text(label)
                .font(HarvestTheme.Typography.bodySmall)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
            Spacer()
        }
    }
}
