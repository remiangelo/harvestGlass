import SwiftUI
import UIKit

struct MainTabView: View {
    let authViewModel: AuthViewModel

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
        TabView {
            Tab("Discover", systemImage: "safari") {
                DiscoverView(authViewModel: authViewModel)
            }

            Tab("Matches", systemImage: "heart.fill") {
                MatchesView(authViewModel: authViewModel)
            }

            Tab("Chat", systemImage: "bubble.left.fill") {
                ChatListView(authViewModel: authViewModel)
            }

            Tab("Gardener", systemImage: "leaf.fill") {
                GardenerChatView(authViewModel: authViewModel)
            }

            Tab("Profile", systemImage: "person.fill") {
                ProfileView(authViewModel: authViewModel)
            }
        }
        .tint(HarvestTheme.Colors.primary)
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
