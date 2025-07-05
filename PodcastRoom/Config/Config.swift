import Foundation

struct Config {
    // MARK: - Supabase Configuration
    static let supabaseURL: String = {
        guard let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String else {
            fatalError("SUPABASE_URL not found in Info.plist")
        }
        return url
    }()
    
    static let supabaseAnonKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist")
        }
        return key
    }()
    
    // MARK: - YouTube Configuration
    static let youtubeAPIKey: String = {
        guard let key = Bundle.main.infoDictionary?["YOUTUBE_API_KEY"] as? String else {
            fatalError("YOUTUBE_API_KEY not found in Info.plist")
        }
        return key
    }()
    
    // MARK: - Google Sign-In Configuration
    static let googleClientID: String = {
        guard let clientID = Bundle.main.infoDictionary?["GIDClientID"] as? String else {
            fatalError("GIDClientID not found in Info.plist")
        }
        return clientID
    }()
    
    // MARK: - Spotify Configuration (for future use)
    static let spotifyClientID: String = {
        guard let clientID = Bundle.main.infoDictionary?["SPOTIFY_CLIENT_ID"] as? String else {
            return "" // Return empty string if not configured
        }
        return clientID
    }()
    
    static let spotifyRedirectURI: String = {
        guard let redirectURI = Bundle.main.infoDictionary?["SPOTIFY_REDIRECT_URI"] as? String else {
            return "podcastroom://spotify-callback" // Default redirect URI
        }
        return redirectURI
    }()
    
    // MARK: - Configuration Validation
    static func validateConfiguration() -> Bool {
        var isValid = true
        var missingKeys: [String] = []
        
        // Check required Supabase configuration
        if supabaseURL.isEmpty || supabaseURL.contains("YOUR_SUPABASE") {
            missingKeys.append("SUPABASE_URL")
            isValid = false
        }
        
        if supabaseAnonKey.isEmpty || supabaseAnonKey.contains("YOUR_SUPABASE") {
            missingKeys.append("SUPABASE_ANON_KEY")
            isValid = false
        }
        
        // Check required YouTube configuration
        if youtubeAPIKey.isEmpty || youtubeAPIKey.contains("YOUR_YOUTUBE") {
            missingKeys.append("YOUTUBE_API_KEY")
            isValid = false
        }
        
        // Check required Google Sign-In configuration
        if googleClientID.isEmpty || googleClientID.contains("YOUR_GOOGLE") {
            missingKeys.append("GIDClientID")
            isValid = false
        }
        
        if !isValid {
            print("❌ Missing or invalid configuration keys: \(missingKeys.joined(separator: ", "))")
            print("📝 Please ensure these keys are properly set in Info.plist")
        }
        
        return isValid
    }
    
    // MARK: - Environment pDetection
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var shouldUseMockData: Bool {
        return !validateConfiguration() && isDebug
    }
}
