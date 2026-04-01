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
                // Photo carousel / fallback surface
                photoCarousel(in: geo.size)

                // Swipe overlays
                if isTopCard {
                    swipeOverlays
                }

                // Info overlay
                if isTopCard {
                    infoOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            .offset(offset)
            .rotationEffect(isTopCard ? dragRotation : .zero)
            .highPriorityGesture(isTopCard ? dragGesture : nil)
            .onChange(of: profile.id) {
                currentPhotoIndex = 0
            }
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
                    .fill(.black.opacity(0.4))
            }
            .padding(.horizontal, HarvestTheme.Spacing.sm)
            .padding(.bottom, HarvestTheme.Spacing.md)
        }
    }

    @ViewBuilder
    private func photoCarousel(in size: CGSize) -> some View {
        let validPhotoURLs = (profile.photos ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { photoString -> URL? in
                guard !photoString.isEmpty else { return nil }
                return URL(string: photoString)
            }

        if validPhotoURLs.isEmpty {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                .fill(HarvestTheme.Colors.glassFillStrong)
                .frame(width: size.width, height: size.height)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                }
        } else {
            TabView(selection: $currentPhotoIndex) {
                ForEach(Array(validPhotoURLs.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: url) { image in
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
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
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
