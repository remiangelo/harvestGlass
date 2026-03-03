import SwiftUI

struct ProfileDetailView: View {
    let profile: UserProfile
    let onSwipe: (SwipeAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.lg) {
                    // Photo carousel
                    if let photos = profile.photos, !photos.isEmpty {
                        TabView {
                            ForEach(Array(photos.enumerated()), id: \.offset) { _, url in
                                AsyncImage(url: URL(string: url)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Rectangle()
                                        .fill(HarvestTheme.Colors.divider)
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 60))
                                                .foregroundStyle(HarvestTheme.Colors.textTertiary)
                                        }
                                }
                            }
                        }
                        .frame(height: 450)
                        .tabViewStyle(.page)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                        // Name & Age
                        HStack(alignment: .firstTextBaseline, spacing: HarvestTheme.Spacing.sm) {
                            Text(profile.displayName)
                                .font(HarvestTheme.Typography.h1)

                            if let age = profile.age {
                                Text("\(age)")
                                    .font(HarvestTheme.Typography.h2)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }

                            Spacer()
                        }

                        // Location
                        if let location = profile.location, !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundStyle(HarvestTheme.Colors.primary)
                                Text(location)
                                    .font(HarvestTheme.Typography.bodySmall)
                                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                            }
                        }

                        // Bio
                        if let bio = profile.bio, !bio.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("About")
                                        .font(HarvestTheme.Typography.h4)
                                    Text(bio)
                                        .font(HarvestTheme.Typography.bodyRegular)
                                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                                }
                            }
                        }

                        // Goals
                        if !profile.goalsList.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Looking For")
                                        .font(HarvestTheme.Typography.h4)

                                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                        ForEach(profile.goalsList, id: \.self) { goal in
                                            ChipView(title: goal)
                                        }
                                    }
                                }
                            }
                        }

                        // Hobbies
                        if let hobbies = profile.hobbies, !hobbies.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: HarvestTheme.Spacing.sm) {
                                    Text("Interests")
                                        .font(HarvestTheme.Typography.h4)

                                    FlowLayout(spacing: HarvestTheme.Spacing.xs) {
                                        ForEach(hobbies, id: \.self) { hobby in
                                            ChipView(title: hobby)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Spacer for action buttons
                    Color.clear.frame(height: 100)
                }
            }

            // Close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.5))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
            }

            // Action buttons
            VStack {
                Spacer()
                actionButtons
                    .padding(.bottom, HarvestTheme.Spacing.lg)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: HarvestTheme.Spacing.xl) {
            Button {
                onSwipe(.nope)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(HarvestTheme.Colors.nope)
                    .frame(width: 60, height: 60)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
            }

            Button {
                onSwipe(.superLike)
                dismiss()
            } label: {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(HarvestTheme.Colors.superLike)
                    .frame(width: 48, height: 48)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
            }

            Button {
                onSwipe(.like)
                dismiss()
            } label: {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundStyle(HarvestTheme.Colors.like)
                    .frame(width: 60, height: 60)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
            }
        }
    }
}
