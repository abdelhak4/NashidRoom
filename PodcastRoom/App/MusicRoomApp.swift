import SwiftUI
import Supabase
import GoogleSignIn

@main
struct MusicRoomApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        // Validate configuration
        if Config.validateConfiguration() {
            print("✅ Configuration validated successfully")
        } else {
            print("⚠️ Configuration validation failed - using mock data")
        }
        
        // Initialize Supabase
        _ = SupabaseService.shared
        
        // Initialize Audio Player
        _ = AudioPlayerService.shared
        
        // Initialize Google Sign In
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Config.googleClientID)
        
        // Initialize YouTube Service
        YouTubeService.shared.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if supabaseService.isAuthenticated {
                    MainTabView()
                        .environmentObject(supabaseService)
                        .environmentObject(authViewModel)
                        .environmentObject(themeManager)
                } else {
                    LoginView()
                        .environmentObject(supabaseService)
                        .environmentObject(authViewModel)
                        .environmentObject(themeManager)
                }
            }
            .preferredColorScheme(themeManager.selectedTheme.colorScheme)
            .onOpenURL { url in
                // Handle Google Sign In URLs
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
