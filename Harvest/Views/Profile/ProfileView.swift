import SwiftUI

struct ProfileView: View {
    let authViewModel: AuthViewModel
    @State private var viewModel = ProfileViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    // Photo pager
                    if let photos = viewModel.profile?.photos, !photos.isEmpty {
                        TabView {
                            ForEach(Array(photos.enumerated()), id: \.offset) { _, url in
                                AsyncImage(url: URL(string: url)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle()
                                        .fill(HarvestTheme.Colors.divider)
                                        .overlay { ProgressView() }
                                }
                            }
                        }
                        .frame(height: 400)
                        .tabViewStyle(.page)
                        .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
                        .padding(.horizontal)
                    }

                    // Info card
                    GlassCard {
                        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(viewModel.profile?.displayName ?? "")
                                    .font(HarvestTheme.Typography.h2)
                                    .foregroundStyle(HarvestTheme.Colors.textPrimary)
                                if let age = viewModel.profile?.age {
                                    Text(", \(age)")
                                        .font(HarvestTheme.Typography.h3)
                                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                }
                                Spacer()
                            }

                            if let location = viewModel.profile?.location, !location.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                        .foregroundStyle(HarvestTheme.Colors.primary)
                                    Text(location)
                                        .font(HarvestTheme.Typography.bodySmall)
                                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                }
                            }

                            if let bio = viewModel.profile?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(HarvestTheme.Typography.bodyRegular)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }

                            // Hobbies
                            if let hobbies = viewModel.profile?.hobbies, !hobbies.isEmpty {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Interests")
                                        .font(HarvestTheme.Typography.bodySmall)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                        ForEach(hobbies, id: \.self) { hobby in
                                            ChipView(title: hobby)
                                        }
                                    }
                                }
                            }

                            // Values I Bring
                            if let values = viewModel.valuesBrought, !values.isEmpty {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Values I Bring")
                                        .font(HarvestTheme.Typography.bodySmall)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                        ForEach(values) { value in
                                            ChipView(title: value.name)
                                        }
                                    }
                                }
                            }

                            // Values I Seek
                            if let values = viewModel.valuesSought, !values.isEmpty {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Values I Seek")
                                        .font(HarvestTheme.Typography.bodySmall)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(HarvestTheme.Colors.textPrimary)

                                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                        ForEach(values) { value in
                                            ChipView(title: value.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Edit button
                    NavigationLink {
                        ProfileEditView(authViewModel: authViewModel, viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Profile")
                        }
                        .font(HarvestTheme.Typography.buttonText)
                        .foregroundStyle(HarvestTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                .fill(.thinMaterial)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: HarvestTheme.Radius.md))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(HarvestTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(authViewModel: authViewModel)
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    }
                }
            }
            .task {
                if let userId = authViewModel.currentUserId {
                    await viewModel.loadProfile(userId: userId)
                }
            }
            .toolbarBackground(HarvestTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
