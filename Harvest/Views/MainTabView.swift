import SwiftUI
import UIKit

struct MainTabView: View {
    let authViewModel: AuthViewModel
    @State private var selection: Int = 1
    @State private var showDifferentiation: Bool = !UserDefaults.standard.bool(forKey: "hasSeenDifferentiation")
    @State private var pendingChatDeepLink: String?

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel

        // Driven by HarvestTheme, not literals. These were hardcoded to the
        // old dark palette, which is why the repalette never reached the
        // tab bar and the active item stayed white.
        let selected = UIColor(HarvestTheme.Colors.rose)
        let unselected = UIColor(HarvestTheme.Colors.textTertiary)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(HarvestTheme.Colors.wineBlack)
        appearance.shadowColor = UIColor(HarvestTheme.Colors.textPrimary).withAlphaComponent(0.12)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = unselected
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
        itemAppearance.selected.iconColor = selected
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: selected]

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

