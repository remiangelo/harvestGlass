import SwiftUI

struct MatchModalView: View {
    let matchedProfile: UserProfile
    let currentProfile: UserProfile?
    let onSendMessage: () -> Void
    let onContinue: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: HarvestTheme.Spacing.xl) {
                Spacer()

                // Profile photos
                HStack(spacing: -20) {
                    profilePhoto(url: currentProfile?.primaryPhoto)
                        .offset(x: showContent ? 0 : -100)
                        .opacity(showContent ? 1 : 0)

                    profilePhoto(url: matchedProfile.primaryPhoto)
                        .offset(x: showContent ? 0 : 100)
                        .opacity(showContent ? 1 : 0)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showContent)

                // Match text
                VStack(spacing: HarvestTheme.Spacing.sm) {
                    Text("It's a Match!")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(HarvestTheme.Colors.primary)

                    Text("You and \(matchedProfile.displayName) liked each other")
                        .font(HarvestTheme.Typography.bodyRegular)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: showContent)

                Spacer()

                // Buttons
                VStack(spacing: HarvestTheme.Spacing.sm) {
                    GlassButton(title: "Send a Message", icon: "paperplane.fill", style: .primary) {
                        onSendMessage()
                    }

                    GlassButton(title: "Keep Swiping", style: .secondary) {
                        onContinue()
                    }
                }
                .padding(.horizontal, HarvestTheme.Spacing.xl)
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn.delay(0.6), value: showContent)

                Spacer(minLength: HarvestTheme.Spacing.xxl)
            }
        }
        .onAppear {
            showContent = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private func profilePhoto(url: String?) -> some View {
        Group {
            if let url, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(HarvestTheme.Colors.divider)
                }
            } else {
                Circle()
                    .fill(HarvestTheme.Colors.divider)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(radius: 8)
    }
}
