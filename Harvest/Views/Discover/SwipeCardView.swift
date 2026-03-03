import SwiftUI

struct SwipeCardView: View {
    let profile: UserProfile
    let isTopCard: Bool
    let onSwipe: (SwipeAction) -> Void

    @State private var offset: CGSize = .zero
    @State private var currentPhotoIndex = 0
    @State private var showProfileDetail = false

    private let swipeThreshold: CGFloat = 120

    private var dragRotation: Angle {
        .degrees(Double(offset.width) / 20)
    }

    private var likeOpacity: Double {
        max(0, Double(offset.width) / swipeThreshold)
    }

    private var nopeOpacity: Double {
        max(0, Double(-offset.width) / swipeThreshold)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Photo carousel
                TabView(selection: $currentPhotoIndex) {
                    ForEach(Array((profile.photos ?? []).enumerated()), id: \.offset) { index, url in
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
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // Swipe overlays
                swipeOverlays

                // Info overlay
                infoOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            .offset(offset)
            .rotationEffect(isTopCard ? dragRotation : .zero)
            .gesture(isTopCard ? dragGesture : nil)
            .onTapGesture {
                if isTopCard {
                    showProfileDetail = true
                }
            }
            .fullScreenCover(isPresented: $showProfileDetail) {
                ProfileDetailView(profile: profile, onSwipe: onSwipe)
            }
        }
    }

    private var swipeOverlays: some View {
        ZStack {
            // Like overlay
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                .stroke(HarvestTheme.Colors.like, lineWidth: 4)
                .overlay(alignment: .topLeading) {
                    Text("LIKE")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(HarvestTheme.Colors.like)
                        .rotationEffect(.degrees(-15))
                        .padding(30)
                }
                .opacity(likeOpacity)

            // Nope overlay
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                .stroke(HarvestTheme.Colors.nope, lineWidth: 4)
                .overlay(alignment: .topTrailing) {
                    Text("NOPE")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(HarvestTheme.Colors.nope)
                        .rotationEffect(.degrees(15))
                        .padding(30)
                }
                .opacity(nopeOpacity)
        }
    }

    private var infoOverlay: some View {
        VStack(alignment: .leading, spacing: HarvestTheme.Spacing.xs) {
            Spacer()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: HarvestTheme.Spacing.sm) {
                        Text(profile.displayName)
                            .font(HarvestTheme.Typography.h2)
                            .fontWeight(.bold)

                        if let age = profile.age {
                            Text("\(age)")
                                .font(HarvestTheme.Typography.h3)
                                .fontWeight(.regular)
                        }
                    }

                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(HarvestTheme.Typography.bodySmall)
                            .lineLimit(2)
                    }

                    if let location = profile.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(location)
                                .font(HarvestTheme.Typography.caption)
                        }
                    }
                }

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(HarvestTheme.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                    .fill(.ultraThinMaterial)
                    .glassEffect(.regular, in: .rect(
                        cornerRadii: .init(
                            topLeading: 0, bottomLeading: HarvestTheme.Radius.xl,
                            bottomTrailing: HarvestTheme.Radius.xl, topTrailing: 0
                        )
                    ))
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
            .onEnded { value in
                let width = value.translation.width
                if width > swipeThreshold {
                    withAnimation(.spring(response: 0.3)) {
                        offset = CGSize(width: 500, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSwipe(.like)
                        offset = .zero
                    }
                } else if width < -swipeThreshold {
                    withAnimation(.spring(response: 0.3)) {
                        offset = CGSize(width: -500, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSwipe(.nope)
                        offset = .zero
                    }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        offset = .zero
                    }
                }
            }
    }
}
