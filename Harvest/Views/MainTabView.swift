import SwiftUI
import UIKit

struct MainTabView: View {
    let authViewModel: AuthViewModel
    @State private var selection: Int = 1
    @State private var showDifferentiation: Bool = !UserDefaults.standard.bool(forKey: "hasSeenDifferentiation")
    @State private var pendingChatDeepLink: String?

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(hex: "150A0F")
        appearance.shadowColor = UIColor(hex: "FB2E63")?.withAlphaComponent(0.18)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(hex: "9A7E88")
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(hex: "9A7E88") ?? .white]
        itemAppearance.selected.iconColor = UIColor(hex: "FFFFFF")
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(hex: "FFFFFF") ?? .white]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Soil", systemImage: "heart.text.square.fill", value: 0) {
                ValuesView(authViewModel: authViewModel)
            }

            Tab("The Field", systemImage: "leaf.circle.fill", value: 1) {
                FieldView(authViewModel: authViewModel)
            }

            Tab("Gardener", systemImage: "leaf.fill", value: 2) {
                GardenerChatView(authViewModel: authViewModel)
            }

            Tab("Seeds", systemImage: "bubble.left.fill", value: 3) {
                SeedsView(
                    authViewModel: authViewModel,
                    pendingChatDeepLink: $pendingChatDeepLink
                )
            }

            Tab("Profile", systemImage: "person.fill", value: 4) {
                ProfileView(authViewModel: authViewModel)
            }
        }
        .tint(HarvestTheme.Colors.primary)
        .onReceive(NotificationCenter.default.publisher(for: .harvestDeepLink)) { note in
            guard let link = note.userInfo?["deepLink"] as? String else { return }
            handleDeepLink(link)
        }
        .fullScreenCover(isPresented: $showDifferentiation) {
            DifferentiationView {
                UserDefaults.standard.set(true, forKey: "hasSeenDifferentiation")
                showDifferentiation = false
                selection = 1   // land on The Field after the intro
            }
        }
    }

    private func handleDeepLink(_ link: String) {
        if link.hasPrefix("chat:") {
            let conversationId = String(link.dropFirst("chat:".count))
            selection = 3
            pendingChatDeepLink = conversationId
        } else if link.hasPrefix("seed:") || link == "seeds" || link.hasPrefix("match:") {
            selection = 3            // all connection events open the Seeds tab
        } else if link == "gardener" {
            selection = 2
        } else if link.hasPrefix("community:") {
            selection = 1            // Phase 3 deep-links into the room
        }
    }
}

private extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }

        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
