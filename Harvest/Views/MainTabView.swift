import SwiftUI

struct MainTabView: View {
    let authViewModel: AuthViewModel

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
