import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Content based on selected tab
            switch selectedTab {
            case 0:
                NavigationView {
                    ExploreView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case 1:
                NavigationView {
                    EventListView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case 2:
                NavigationView {
                    PlaylistEditorView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case 3:
                NavigationView {
                    ReceivedInvitationsView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case 4:
                NavigationView {
                    ProfileView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                NavigationView {
                    ExploreView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Bottom navigation bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .background(ThemeColor.appBackground.color)
        .ignoresSafeArea()
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Subtle separator line
            Rectangle()
                .fill(Color.separatorColor)
                .frame(height: 0.5)
            
            HStack(spacing: 0) {
                // Discover tab
                TabBarButton(
                    iconName: "house.fill",
                    title: "Discover",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                
                Spacer()
                
                // Events tab
                TabBarButton(
                    iconName: "calendar",
                    title: "Events",
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }
                
                Spacer()
                
                // Playlists tab
                TabBarButton(
                    iconName: "music.note.list",
                    title: "Playlists",
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                }
                
                Spacer()
                
                // Invitations tab
                TabBarButton(
                    iconName: "envelope.fill",
                    title: "Invites",
                    isSelected: selectedTab == 3
                ) {
                    selectedTab = 3
                }
                
                Spacer()
                
                // Profile tab
                TabBarButton(
                    iconName: "person.fill",
                    title: "Profile",
                    isSelected: selectedTab == 4
                ) {
                    selectedTab = 4
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .padding(.bottom, 34) // Account for home indicator
            .background(Color.tabBarBackground)
        }
        .background(Color.clear)
    }
}

struct TabBarButton: View {
    let iconName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? Color.selectedTabColor : Color.unselectedTabColor)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? Color.selectedTabColor : Color.unselectedTabColor)
            }
        }
    }
}

#Preview {
    MainTabView()
} 
