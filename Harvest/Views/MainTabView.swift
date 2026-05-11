import SwiftUI
import UIKit

struct MainTabView: View {
    let authViewModel: AuthViewModel
    @State private var selection: Int = 0
    @State private var showDifferentiation: Bool = !UserDefaults.standard.bool(forKey: "hasSeenDifferentiation")

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(hex: "5B1E35")
        appearance.shadowColor = UIColor(hex: "7A3452")?.withAlphaComponent(0.45)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(hex: "F0D5C8")
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(hex: "F0D5C8") ?? .white]
        itemAppearance.selected.iconColor = UIColor(hex: "F0D5C8")
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(hex: "F0D5C8") ?? .white]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Gardener", systemImage: "leaf.fill", value: 0) {
                GardenerChatView(authViewModel: authViewModel)
            }

            Tab("Discover", systemImage: "safari", value: 1) {
                DiscoverView(authViewModel: authViewModel)
            }

            Tab("Matches", systemImage: "heart.fill", value: 2) {
                MatchesView(authViewModel: authViewModel)
            }

            Tab("Chat", systemImage: "bubble.left.fill", value: 3) {
                ChatListView(authViewModel: authViewModel)
            }

            Tab("Profile", systemImage: "person.fill", value: 4) {
                ProfileView(authViewModel: authViewModel)
            }
        }
        .tint(HarvestTheme.Colors.primary)
        .fullScreenCover(isPresented: $showDifferentiation) {
            DifferentiationView {
                UserDefaults.standard.set(true, forKey: "hasSeenDifferentiation")
                showDifferentiation = false
                selection = 0
            }
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
