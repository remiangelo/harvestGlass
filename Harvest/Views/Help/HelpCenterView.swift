import SwiftUI

struct HelpCenterView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = HelpCenterViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: HarvestTheme.Spacing.lg) {
                // Category filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HarvestTheme.Spacing.sm) {
                        ChipView(
                            title: "All",
                            isSelected: viewModel.selectedCategory == nil,
                            lightStyle: true
                        ) {
                            viewModel.selectedCategory = nil
                        }

                        ForEach(HelpCenterViewModel.categories, id: \.self) { category in
                            ChipView(
                                title: category,
                                isSelected: viewModel.selectedCategory == category,
                                lightStyle: true
                            ) {
                                viewModel.selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // FAQs
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    Text("Frequently Asked Questions")
                        .font(HarvestTheme.Typography.h3)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        .padding(.horizontal)

                    ForEach(viewModel.filteredFAQs) { faq in
                        GlassCard(padding: HarvestTheme.Spacing.sm, style: .light) {
                            DisclosureGroup {
                                Text(faq.answer)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                    .padding(.top, HarvestTheme.Spacing.sm)
                            } label: {
                                HStack {
                                    Text(faq.question)
                                        .font(HarvestTheme.Typography.bodyRegular)
                                        .fontWeight(.medium)
                                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                        .multilineTextAlignment(.leading)

                                    Spacer()

                                    GlassBadge(text: faq.category, color: .secondary)
                                }
                            }
                            .tint(HarvestTheme.Colors.formAccent)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Contact Support
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    Text("Contact Support")
                        .font(HarvestTheme.Typography.h3)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        .padding(.horizontal)

                    GlassCard(style: .light) {
                        VStack(spacing: HarvestTheme.Spacing.md) {
                            // Category
                            HStack {
                                Text("Category")
                                    .font(HarvestTheme.Typography.bodyRegular)
                                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                Spacer()
                                Picker("", selection: $viewModel.ticketCategory) {
                                    ForEach(HelpCenterViewModel.categories, id: \.self) {
                                        Text($0).tag($0)
                                    }
                                    Text("General").tag("General")
                                }
                                .tint(HarvestTheme.Colors.formAccent)
                            }

                            // Subject
                            TextField("Subject", text: $viewModel.ticketSubject)
                                .font(HarvestTheme.Typography.bodyRegular)
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                .padding(HarvestTheme.Spacing.sm)
                                .background {
                                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.sm)
                                        .fill(HarvestTheme.Colors.formSurfaceStrong)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.sm)
                                                .stroke(HarvestTheme.Colors.formBorder, lineWidth: 1)
                                        }
                                }

                            // Message
                            TextEditor(text: $viewModel.ticketMessage)
                                .font(HarvestTheme.Typography.bodyRegular)
                                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                                .padding(HarvestTheme.Spacing.xs)
                                .background {
                                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.sm)
                                        .fill(HarvestTheme.Colors.formSurfaceStrong)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.sm)
                                                .stroke(HarvestTheme.Colors.formBorder, lineWidth: 1)
                                        }
                                }

                            GlassButton(title: "Submit", icon: "paperplane", style: .primary) {
                                if let userId = authViewModel.currentUserId {
                                    Task { await viewModel.submitTicket(userId: userId) }
                                }
                            }
                            .disabled(
                                viewModel.ticketSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                viewModel.ticketMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                viewModel.isSubmitting
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                // Resources
                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                    Text("Resources")
                        .font(HarvestTheme.Typography.h3)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                        .padding(.horizontal)

                    VStack(spacing: HarvestTheme.Spacing.sm) {
                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            resourceRow("Privacy Policy", icon: "lock.shield")
                        }

                        NavigationLink {
                            TermsOfServiceView()
                        } label: {
                            resourceRow("Terms of Service", icon: "doc.text")
                        }

                        NavigationLink {
                            CommunityGuidelinesView()
                        } label: {
                            resourceRow("Community Guidelines", icon: "person.2")
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
        .background(HarvestTheme.Colors.formBackground.ignoresSafeArea())
        .toolbarBackground(HarvestTheme.Colors.formBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Ticket Submitted", isPresented: $viewModel.showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We've received your support request and will get back to you soon.")
        }
    }

    private func resourceRow(_ title: String, icon: String) -> some View {
        GlassCard(padding: HarvestTheme.Spacing.md, style: .light) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(HarvestTheme.Colors.formAccent)
                Text(title)
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
            }
        }
    }
}
