import Foundation
import Supabase
import CoreLocation
import PostgREST
import Realtime
import GoogleSignIn

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case notInvited
    case votingNotAllowed(String)
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .notInvited:
            return "User not invited to this event"
        case .votingNotAllowed(let message):
            return message
        case .custom(let message):
            return message
        }
    }
}

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        
        // Check if user is already logged in
        Task {
            if let authUser = try? await client.auth.user() {
                let authUserId = authUser.id.uuidString.lowercased() // Normalize to lowercase
                print("🔍 [DEBUG] init - Auth user ID (normalized): \(authUserId)")
                
                do {
                    let user = try await fetchUser(userId: authUserId)
                    print("🔍 [DEBUG] init - Fetched user: \(user)")
                    
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
                    }
                    
                    print("🔍 [DEBUG] init - Current user set: \(self.currentUser?.id ?? "nil")")
                } catch {
                    print("🔍 [DEBUG] init - Failed to fetch user: \(error)")
                    // Fallback to basic user from auth
                    await MainActor.run {
                        self.currentUser = try? User.from(authUser: authUser)
                        self.isAuthenticated = true
                    }
                }
            }
        }
    }
    
    // MARK: - Authentication
    func signUp(email: String, password: String, username: String) async throws -> User {
        // Log mobile information for sign up
        MobileLoggingService.shared.logAction("user_signup")
        
        do {
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["username": AnyJSON.string(username)]
            )
            
            let user = authResponse.user
            
            // Create user profile
            let userProfile = User(
                id: user.id.uuidString,
                username: username,
                email: email,
                profileImageURL: nil,
                spotifyConnected: false,
                youtubeConnected: true, // YouTube doesn't require explicit connection
                licenseType: .free,
                createdAt: Date(),
                updatedAt: Date()
            )

            // Only create user profile if email is confirmed (for email verification flow)
            // Or if email confirmation is disabled in Supabase settings
            if user.emailConfirmedAt != nil {
                try await client
                    .from("users")
                    .insert(userProfile)
                    .execute()
                
                await MainActor.run {
                    self.currentUser = userProfile
                    self.isAuthenticated = true
                }
            }
            
            return userProfile
        } catch {
            print("🔍 [DEBUG] signUp error: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("already registered") || errorMessage.contains("already exists") {
                throw SupabaseError.custom("An account with this email already exists. Try signing in instead.")
            } else if errorMessage.contains("invalid email") {
                throw SupabaseError.custom("Please enter a valid email address.")
            } else if errorMessage.contains("weak password") || errorMessage.contains("password") {
                throw SupabaseError.custom("Password is too weak. Please use at least 6 characters with a mix of letters and numbers.")
            } else if errorMessage.contains("rate limit") || errorMessage.contains("too many") {
                throw SupabaseError.custom("Too many attempts. Please wait a moment and try again.")
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw SupabaseError.custom("Network error. Please check your internet connection and try again.")
            } else {
                throw SupabaseError.custom("Failed to create account. Please check your information and try again.")
            }
        }
    }
    
    func signUpWithEmailVerification(email: String, password: String, username: String, redirectURL: String) async throws -> Bool {
        // Create user metadata
        let userData: [String: AnyJSON] = ["username": AnyJSON.string(username)]
        
        do {
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password,
                data: userData
            )
            
            let user = authResponse.user
            
            // Check if email confirmation is required
            if user.emailConfirmedAt != nil {
                // User is auto-confirmed, create profile and sign them in
                print("🔍 [DEBUG] User auto-confirmed, creating profile and signing in")
                
                let userProfile = User(
                    id: user.id.uuidString.lowercased(),
                    username: username,
                    email: email,
                    profileImageURL: nil,
                    spotifyConnected: false,
                    youtubeConnected: true,
                    licenseType: .free,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                // Save to database
                try await client
                    .from("users")
                    .insert(userProfile)
                    .execute()
                
                // Update authentication state
                await MainActor.run {
                    self.currentUser = userProfile
                    self.isAuthenticated = true
                }
                
                print("🔍 [DEBUG] User profile created and authenticated: \(userProfile.username)")
                
                // Return false to indicate no email verification needed
                return false
            } else {
                // Email verification required - OTP will be sent automatically
                print("🔍 [DEBUG] Email verification code sent to: \(email)")
                return true
            }
            
        } catch {
            print("🔍 [DEBUG] Sign up with email verification failed: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("already registered") || errorMessage.contains("already exists") {
                throw SupabaseError.custom("An account with this email already exists. Try signing in instead.")
            } else if errorMessage.contains("invalid email") {
                throw SupabaseError.custom("Please enter a valid email address.")
            } else if errorMessage.contains("weak password") || errorMessage.contains("password") {
                throw SupabaseError.custom("Password is too weak. Please use at least 6 characters with a mix of letters and numbers.")
            } else if errorMessage.contains("rate limit") || errorMessage.contains("too many") {
                throw SupabaseError.custom("Too many attempts. Please wait a moment and try again.")
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw SupabaseError.custom("Network error. Please check your internet connection and try again.")
            } else {
                throw SupabaseError.custom("Failed to create account. Please check your information and try again.")
            }
        }
    }
    
    func resendEmailVerification(email: String) async throws {
        do {
            try await client.auth.resend(
                email: email,
                type: .signup
            )
        } catch {
            print("🔍 [DEBUG] resendEmailVerification error: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("rate limit") || errorMessage.contains("too many") {
                throw SupabaseError.custom("Too many verification emails sent. Please wait a moment before requesting another.")
            } else if errorMessage.contains("invalid email") {
                throw SupabaseError.custom("Please enter a valid email address.")
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw SupabaseError.custom("Network error. Please check your internet connection and try again.")
            } else {
                throw SupabaseError.custom("Failed to send verification email. Please try again.")
            }
        }
    }
    
    func resetPassword(email: String, redirectURL: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: redirectURL)
            )
        } catch {
            print("🔍 [DEBUG] resetPassword error: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("rate limit") || errorMessage.contains("too many") {
                throw SupabaseError.custom("Too many password reset requests. Please wait a moment before trying again.")
            } else if errorMessage.contains("invalid email") {
                throw SupabaseError.custom("Please enter a valid email address.")
            } else if errorMessage.contains("user not found") || errorMessage.contains("not found") {
                throw SupabaseError.custom("No account found with this email address.")
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw SupabaseError.custom("Network error. Please check your internet connection and try again.")
            } else {
                throw SupabaseError.custom("Failed to send password reset email. Please try again.")
            }
        }
    }
    
    func resetPasswordWithOTP(email: String) async throws -> Bool {
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: nil
            )
            print("🔍 [DEBUG] Password reset OTP sent to: \(email)")
            return true
        } catch {
            print("🔍 [DEBUG] resetPasswordWithOTP error: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("rate limit") || errorMessage.contains("too many") {
                throw SupabaseError.custom("Too many password reset requests. Please wait a moment before trying again.")
            } else if errorMessage.contains("invalid email") {
                throw SupabaseError.custom("Please enter a valid email address.")
            } else if errorMessage.contains("user not found") || errorMessage.contains("not found") {
                throw SupabaseError.custom("No account found with this email address.")
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw SupabaseError.custom("Network error. Please check your internet connection and try again.")
            } else {
                throw SupabaseError.custom("Failed to send password reset code. Please try again.")
            }
        }
    }
    
    func verifyPasswordResetOTP(email: String, code: String) async throws -> Bool {
        do {
            try await client.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )
            print("🔍 [DEBUG] Password reset OTP verified for: \(email)")
            return true
        } catch {
            print("🔍 [DEBUG] verifyPasswordResetOTP error: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("invalid") || errorMessage.contains("expired") {
                throw SupabaseError.custom("Invalid or expired verification code. Please check the code and try again.")
            } else if errorMessage.contains("rate limit") || errorMessage.contains("too many") {
                throw SupabaseError.custom("Too many verification attempts. Please wait a moment and try again.")
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw SupabaseError.custom("Network error. Please check your internet connection and try again.")
            } else {
                throw SupabaseError.custom("Failed to verify code. Please check the verification code and try again.")
            }
        }
    }
    
    func updatePassword(newPassword: String) async throws {
        do {
            try await client.auth.update(user: UserAttributes(password: newPassword))
            print("🔍 [DEBUG] Password updated successfully")
        } catch {
            print("🔍 [DEBUG] updatePassword error: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("password") && errorMessage.contains("weak") {
                throw SupabaseError.custom("Password is too weak. Please choose a stronger password.")
            } else if errorMessage.contains("password") && errorMessage.contains("short") {
                throw SupabaseError.custom("Password must be at least 6 characters long.")
            } else if errorMessage.contains("unauthorized") {
                throw SupabaseError.custom("Session expired. Please start the password reset process again.")
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw SupabaseError.custom("Network error. Please check your internet connection and try again.")
            } else {
                throw SupabaseError.custom("Failed to update password. Please try again.")
            }
        }
    }
    
    func verifyEmailWithCode(email: String, code: String) async throws -> User {
        do {
            let authResponse = try await client.auth.verifyOTP(
                email: email,
                token: code,
                type: .signup
            )
            
            let authUser = authResponse.user
            let authUserId = authUser.id.uuidString.lowercased()
            
            // Check if user profile already exists
            do {
                let existingUser = try await fetchUser(userId: authUserId)
                await MainActor.run {
                    self.currentUser = existingUser
                    self.isAuthenticated = true
                }
                print("🔍 [DEBUG] Email verified successfully for existing user: \(existingUser.username)")
                return existingUser
            } catch {
                // Create user profile if it doesn't exist
                let username = authUser.userMetadata["username"] as? String ?? "User"
                
                let userProfile = User(
                    id: authUserId,
                    username: username,
                    email: authUser.email ?? "",
                    profileImageURL: nil,
                    spotifyConnected: false,
                    youtubeConnected: true,
                    licenseType: .free,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                try await client
                    .from("users")
                    .insert(userProfile)
                    .execute()
                
                await MainActor.run {
                    self.currentUser = userProfile
                    self.isAuthenticated = true
                }
                
                print("🔍 [DEBUG] Email verified and user profile created: \(userProfile.username)")
                return userProfile
            }
        } catch {
            print("🔍 [DEBUG] verifyEmailWithCode error: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("invalid") || errorMessage.contains("expired") {
                throw SupabaseError.custom("Invalid or expired verification code. Please check the code and try again.")
            } else if errorMessage.contains("rate limit") || errorMessage.contains("too many") {
                throw SupabaseError.custom("Too many verification attempts. Please wait a moment and try again.")
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw SupabaseError.custom("Network error. Please check your internet connection and try again.")
            } else {
                throw SupabaseError.custom("Failed to verify email. Please check the verification code and try again.")
            }
        }
    }
    
    func signIn(email: String, password: String) async throws -> User {
        // Log mobile information for sign in
        MobileLoggingService.shared.logAction("user_signin")
        
        do {
            let authResponse = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            let authUser = authResponse.user
            let authUserId = authUser.id.uuidString.lowercased() // Normalize to lowercase
            print("🔍 [DEBUG] signIn - Auth user ID (normalized): \(authUserId)")
            
            let user = try await fetchUser(userId: authUserId)
            print("🔍 [DEBUG] signIn - Fetched user: \(user)")
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
            }
            
            print("🔍 [DEBUG] signIn - Current user set: \(self.currentUser?.id ?? "nil")")
            
            return user
        } catch {
            print("🔍 [DEBUG] signIn error: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("invalid_grant") || errorMessage.contains("invalid credentials") {
                throw SupabaseError.custom("Invalid email or password. Please check your credentials and try again.")
            } else if errorMessage.contains("email not confirmed") || errorMessage.contains("not verified") {
                throw SupabaseError.custom("Please verify your email address before signing in. Check your inbox for a verification email.")
            } else if errorMessage.contains("rate limit") || errorMessage.contains("too many") {
                throw SupabaseError.custom("Too many login attempts. Please wait a moment and try again.")
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw SupabaseError.custom("Network error. Please check your internet connection and try again.")
            } else {
                throw SupabaseError.custom("Login failed. Please check your credentials and try again.")
            }
        }
    }
    
    func signOut() async throws {
        // Log mobile information for sign out
        MobileLoggingService.shared.logAction("user_signout")
        
        try await client.auth.signOut()
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    func fetchUser(userId: String) async throws -> User {
        let response = try await client
            .from("users")
            .select()
            .eq("id", value: userId)
            .execute()
        
        // The actual data is in response.data
        let data = response.data
        
        // Parse the JSON data
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
            guard let userArray = jsonArray as? [[String: Any]],
                  userArray.count == 1,
                  let userDictionary = userArray.first else {
                print("User not found with ID: \(userId)")
                throw SupabaseError.custom("User not found")
            }

            return try User.from(dictionary: userDictionary)
        } catch {
            print("JSON parsing error: \(error)")
            print("Raw data: \(String(data: data, encoding: .utf8) ?? "Could not convert to string")")
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user JSON: \(error.localizedDescription)"])
        }
    }
    
    func updateUserProfile(user: User) async throws {
        try await client
            .from("users")
            .update(user)
            .eq("id", value: user.id)
            .execute()
        
        // Update current user
        await MainActor.run {
            self.currentUser = user
        }
    }
}

// MARK: - Events
extension SupabaseService {
    func createEvent(_ event: Event) async throws {
        // Log mobile information for event creation
        MobileLoggingService.shared.logAction("create_event")
        
        print("🔍 [DEBUG] createEvent - Creating event: \(event.name)")
        print("🔍 [DEBUG] createEvent - Host ID: \(event.hostId)")
        print("🔍 [DEBUG] createEvent - Visibility: \(event.visibility.rawValue)")
        print("🔍 [DEBUG] createEvent - Event dictionary: \(event.toDictionary())")
        
        let response = try await client
            .from("events")
            .insert(event)
            .select() // Get the inserted event back
            .execute()
        
        let data = response.data
        print("🔍 [DEBUG] createEvent - Response data: \(String(data: data, encoding: .utf8) ?? "Could not convert to string")")
    }
    
    func fetchPublicEvents() async throws -> [Event] {
        let response = try await client
            .from("events")
            .select()
            .eq("visibility", value: "public")
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
        
        // The actual data is in response.data
        let data = response.data
        
        // Parse the JSON data
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
            guard let eventDictionaries = jsonArray as? [[String: Any]] else {
                print("JSON is not an array of dictionaries: \(jsonArray)")
                return []
            }
            
            return try eventDictionaries.map { try Event.from(dictionary: $0) }
        } catch {
            print("JSON parsing error: \(error)")
            print("Raw data: \(String(data: data, encoding: .utf8) ?? "Could not convert to string")")
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse events JSON: \(error.localizedDescription)"])
        }
    }
    
    func fetchUserEvents() async throws -> [Event] {
        guard let currentUser = currentUser else {
            print("🔍 [DEBUG] fetchUserEvents - No current user, throwing notAuthenticated")
            throw SupabaseError.notAuthenticated
        }
        
        print("🔍 [DEBUG] fetchUserEvents - Current user ID: \(currentUser.id)")
        
        // Fetch all events that the user has access to
        // This includes:
        // 1. Events hosted by the user
        // 2. Private events where the user has accepted invitations
        // The RLS policy handles the access control automatically
        let response = try await client
            .from("events")
            .select()
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()

        // The actual data is in response.data
        let data = response.data
        print("🔍 [DEBUG] fetchUserEvents - Raw response data: \(String(data: data, encoding: .utf8) ?? "Could not convert to string")")
        
        // Parse the JSON data
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
            guard let eventDictionaries = jsonArray as? [[String: Any]] else {
                print("🔍 [DEBUG] fetchUserEvents - JSON is not an array of dictionaries: \(jsonArray)")
                return []
            }
            
            // Filter out public events since this is for "user events"
            // We only want events where the user is the host OR has accepted invitations to private events
            let userEventDictionaries = eventDictionaries.filter { event in
                let hostId = event["host_id"] as? String
                let visibility = event["visibility"] as? String
                
                // Include if user is the host
                if hostId == currentUser.id {
                    return true
                }
                
                // Include if it's a private event (user must have accepted invitation to see it due to RLS)
                if visibility == "private" {
                    return true
                }
                
                // Exclude public events from user events list
                return false
            }
            
            print("🔍 [DEBUG] fetchUserEvents - Found \(userEventDictionaries.count) user events out of \(eventDictionaries.count) total events")
            for (index, event) in userEventDictionaries.enumerated() {
                let eventId = event["id"] as? String ?? "nil"
                let hostId = event["host_id"] as? String ?? "nil"
                let visibility = event["visibility"] as? String ?? "nil"
                let name = event["name"] as? String ?? "nil"
                let isHost = hostId == currentUser.id
                print("🔍 [DEBUG] Event #\(index + 1): \(name) (\(visibility)) - host_id: \(hostId) - isHost: \(isHost)")
            }

            return try userEventDictionaries.map { try Event.from(dictionary: $0) }
        } catch {
            print("🔍 [DEBUG] fetchUserEvents - JSON parsing error: \(error)")
            print("🔍 [DEBUG] fetchUserEvents - Raw data: \(String(data: data, encoding: .utf8) ?? "Could not convert to string")")
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user events JSON: \(error.localizedDescription)"])
        }
    }
    
    func joinEvent(eventId: String) async throws {
        guard let currentUser = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        // Check if user can join this event
        let event = try await fetchEvent(eventId: eventId)
        
        if event.visibility == .private && event.hostId != currentUser.id {
            // Check if user is invited
            let isInvited = try await checkEventInvitation(eventId: eventId, userId: currentUser.id)
            guard isInvited else {
                throw SupabaseError.notInvited
            }
        }
        
        // Add user to event participants if not already joined
        let existingParticipantResponse = try await client
            .from("event_participants")
            .select()
            .eq("event_id", value: eventId)
            .eq("user_id", value: currentUser.id)
            .execute()
        
        let existingParticipants: [[String: Any]]
        let data = existingParticipantResponse.data
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
        existingParticipants = jsonArray as? [[String: Any]] ?? []
        
        if existingParticipants.isEmpty {
            struct EventParticipant: Codable {
                let eventId: String
                let userId: String
                let joinedAt: String
                
                enum CodingKeys: String, CodingKey {
                    case eventId = "event_id"
                    case userId = "user_id"
                    case joinedAt = "joined_at"
                }
            }
            
            try await client
                .from("event_participants")
                .insert(EventParticipant(
                    eventId: eventId,
                    userId: currentUser.id,
                    joinedAt: ISO8601DateFormatter().string(from: Date())
                ))
                .execute()
        }
    }
     private func fetchEvent(eventId: String) async throws -> Event {
        let response = try await client
            .from("events")
            .select()
            .eq("id", value: eventId)
            .execute()
        
        // The actual data is in response.data
        let data = response.data
        
        // Parse the JSON data
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
            guard let eventArray = jsonArray as? [[String: Any]],
                  eventArray.count == 1,
                  let eventDictionary = eventArray.first else {
                print("Event not found with ID: \(eventId)")
                throw SupabaseError.custom("Event not found")
            }

            return try Event.from(dictionary: eventDictionary)
        } catch {
            print("JSON parsing error: \(error)")
            print("Raw data: \(String(data: data, encoding: .utf8) ?? "Could not convert to string")")
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse event JSON: \(error.localizedDescription)"])
        }
    }
    
    private func checkEventInvitation(eventId: String, userId: String) async throws -> Bool {
        let response = try await client
            .from("event_invitations")
            .select("status")
            .eq("event_id", value: eventId)
            .eq("user_id", value: userId)
            .execute()
        
        let invitations: [[String: Any]]
        let data = response.data
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
        invitations = jsonArray as? [[String: Any]] ?? []
        
        return !invitations.isEmpty && invitations.first?["status"] as? String == "accepted"
    }
}

// MARK: - Tracks & Voting
extension SupabaseService {
    // Helper struct for inserting tracks without ID (let database generate UUID)
    private struct InsertableTrack: Codable {
        let title: String
        let artist: String
        let album: String?
        let duration: Int
        let artworkURL: String?
        let previewURL: String?
        let spotifyURI: String?
        let youtubeVideoId: String?
        let youtubeURL: String?
        let eventId: String?
        let addedBy: String?
        let votes: Int
        let position: Int
        let isPlayed: Bool
        let addedAt: String
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case title
            case artist
            case album
            case duration
            case artworkURL = "artwork_url"
            case previewURL = "preview_url"
            case spotifyURI = "spotify_uri"
            case youtubeVideoId = "youtube_video_id"
            case youtubeURL = "youtube_url"
            case eventId = "event_id"
            case addedBy = "added_by"
            case votes
            case position
            case isPlayed = "is_played"
            case addedAt = "added_at"
            case updatedAt = "updated_at"
        }
        
        init(from track: Track) {
            self.title = track.title
            self.artist = track.artist
            self.album = track.album
            self.duration = Int(track.duration)
            self.artworkURL = track.artworkURL
            self.previewURL = track.previewURL
            self.spotifyURI = track.spotifyURI
            self.youtubeVideoId = track.youtubeVideoId
            self.youtubeURL = track.youtubeURL
            self.eventId = track.eventId
            self.addedBy = track.addedBy
            self.votes = track.votes
            self.position = track.position
            self.isPlayed = track.isPlayed
            self.addedAt = ISO8601DateFormatter().string(from: track.addedAt)
            self.updatedAt = ISO8601DateFormatter().string(from: track.updatedAt)
        }
    }
    
    func addTrackToEvent(eventId: String, track: Track) async throws {
        guard let currentUser = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        // Create a new track for this event
        var eventTrack = track
        eventTrack.eventId = eventId
        eventTrack.addedBy = currentUser.id
        eventTrack.votes = 0 // Start with 0, we'll add a vote after creation
        
        // Create an insertable track without the ID
        let insertableTrack = InsertableTrack(from: eventTrack)
        
        print("Inserting track without ID: \(insertableTrack)")
        
        let response = try await client
            .from("tracks")
            .insert(insertableTrack)
            .select() // Select the inserted data to get the generated UUID
            .execute()
        
        // Parse the response to get the newly created track with UUID
        let data = response.data
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
        guard let trackDictionaries = jsonArray as? [[String: Any]],
              let trackDict = trackDictionaries.first else {
            print("Failed to get track data from insert response")
            print("Raw response data: \(String(data: data, encoding: .utf8) ?? "Could not convert to string")")
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get created track data"])
        }
        
        print("Got track response from insert: \(trackDict)")
        let newTrack = try Track.from(dictionary: trackDict)
        
        // Automatically vote up for the track that the user added
        try await voteForTrack(eventId: eventId, trackId: newTrack.id, voteType: .up)
    }
    
    func voteForTrack(eventId: String, trackId: String, voteType: VoteType) async throws {
        print("🟡 SupabaseService.voteForTrack called - eventId: \(eventId), trackId: \(trackId), voteType: \(voteType.rawValue)")
        
        guard let currentUser = currentUser else {
            print("❌ No current user - throwing notAuthenticated")
            throw SupabaseError.notAuthenticated
        }
        
        print("� Current user: \(currentUser.id)")
        
        // Check if user can vote for this event
        print("🟡 Checking if user can vote...")
        let canVote = try await canUserVote(eventId: eventId)
        print("🟡 Can user vote: \(canVote)")
        guard canVote else {
            print("❌ User cannot vote - throwing votingNotAllowed")
            throw SupabaseError.votingNotAllowed("You are not allowed to vote for this event")
        }
        
        // Check if user has already voted for this track
        print("🟡 Checking for existing votes...")
        let existingVoteResponse = try await client
            .from("votes")
            .select("id, vote_type")
            .eq("event_id", value: eventId)
            .eq("track_id", value: trackId)
            .eq("user_id", value: currentUser.id)
            .execute()
        
        let existingVotes: [[String: Any]]
        let data = existingVoteResponse.data
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
        existingVotes = jsonArray as? [[String: Any]] ?? []
        
        print("🟡 Found \(existingVotes.count) existing votes")
        
        if !existingVotes.isEmpty {
            // Update existing vote
            let voteDict = existingVotes.first!
            let voteId = voteDict["id"] as! String
            let currentVoteType = voteDict["vote_type"] as? String
            
            print("� Updating existing vote: \(currentVoteType ?? "nil") → \(voteType.rawValue)")
            
            // Check if the vote type is the same - if so, remove the vote instead
            if currentVoteType == voteType.rawValue {
                print("🟡 Same vote type detected, removing vote instead")
                let deleteResponse = try await client
                    .from("votes")
                    .delete()
                    .eq("id", value: voteId)
                    .execute()
                print("🟡 Vote delete response status: \(deleteResponse.status)")
                print("✅ Vote removed successfully")
            } else {
                // Update with different vote type
                struct VoteUpdate: Codable {
                    let voteType: String
                    let updatedAt: String
                    
                    enum CodingKeys: String, CodingKey {
                        case voteType = "vote_type"
                        case updatedAt = "updated_at"
                    }
                }
                
                let updateData = VoteUpdate(
                    voteType: voteType.rawValue,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )
                
                let updateResponse = try await client
                    .from("votes")
                    .update(updateData)
                    .eq("id", value: voteId)
                    .execute()
                    
                print("🟡 Vote update response status: \(updateResponse.status)")
                print("✅ Vote updated successfully")
            } // Close the else block for different vote type
        } else {
            // Create new vote
            print("🟡 Creating new \(voteType.rawValue) vote")
            
            let vote = Vote(
                userId: currentUser.id,
                trackId: trackId,
                eventId: eventId,
                voteType: voteType
            )
            
            let insertResponse = try await client
                .from("votes")
                .insert(vote)
                .execute()
                
            print("🟡 Vote insert response status: \(insertResponse.status)")
            print("✅ New vote created successfully")
        }
        
        // Note: Vote count update is handled automatically by database trigger
        print("� Vote count will be updated automatically by database trigger")
        
        // Manual vote count update as backup (in case database trigger isn't working)
        print("🟡 Manually updating vote count as backup...")
        try await updateTrackVoteCount(trackId: trackId, eventId: eventId)
        print("🟡 Manual vote count update completed")
    }
     func fetchEventTracks(eventId: String) async throws -> [Track] {
        let response = try await client
            .from("tracks")
            .select()
            .eq("event_id", value: eventId)
            .order("votes", ascending: false)
            .order("added_at", ascending: true)
            .execute()

        // The actual data is in response.data
        let data = response.data
        
        // Parse the JSON data
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
            guard let trackDictionaries = jsonArray as? [[String: Any]] else {
                print("JSON is not an array of dictionaries: \(jsonArray)")
                return []
            }

            print("fetchEventTracks: Found \(trackDictionaries.count) track dictionaries")
            
            return try trackDictionaries.enumerated().map { index, dict in
                print("Parsing track #\(index + 1)")
                var track = try Track.from(dictionary: dict)
                track.position = index + 1
                return track
            }
        } catch {
            print("JSON parsing error in fetchEventTracks: \(error)")
            print("Raw data: \(String(data: data, encoding: .utf8) ?? "Could not convert to string")")
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse tracks JSON: \(error.localizedDescription)"])
        }
    }
    
    func canUserVote(eventId: String) async throws -> Bool {
        guard let currentUser = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        // Fetch the event details
        let event = try await fetchEvent(eventId: eventId)
        
        // Check based on license type
        switch event.licenseType {
        case .free:
            return true
            
        case .premium:
            // Check if user is invited or is the host
            if event.hostId == currentUser.id {
                return true
            }
            return try await checkEventInvitation(eventId: eventId, userId: currentUser.id)
            
        case .locationBased:
            // Check location and time restrictions
            if let startTime = event.timeStart, let endTime = event.timeEnd {
                let now = Date()
                guard now >= startTime && now <= endTime else {
                    throw SupabaseError.votingNotAllowed("Event is not currently active")
                }
            }
            
            // Check location if coordinates are provided
            if let eventLat = event.locationLat, 
               let eventLng = event.locationLng,
               let radius = event.locationRadius {
                
                let locationService = await LocationService.shared
                guard let userCoordinates = await locationService.getCurrentCoordinates() else {
                    throw SupabaseError.votingNotAllowed("Location access is required to vote for this event")
                }
                
                let distance = await locationService.calculateDistance(
                    from: CLLocationCoordinate2D(latitude: userCoordinates.latitude, longitude: userCoordinates.longitude),
                    to: CLLocationCoordinate2D(latitude: eventLat, longitude: eventLng)
                )
                
                guard distance <= Double(radius) else {
                    throw SupabaseError.votingNotAllowed("You must be within \(radius)m of the event location to vote")
                }
            }
            
            return true
        }
    }
    
    func getUserVotes(eventId: String) async throws -> [String: VoteType] {
        guard let currentUser = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        let response = try await client
            .from("votes")
            .select("track_id, vote_type")
            .eq("event_id", value: eventId)
            .eq("user_id", value: currentUser.id)
            .execute()
        
        let votes: [[String: Any]]
        let data = response.data
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
        votes = jsonArray as? [[String: Any]] ?? []
        
        var userVotes: [String: VoteType] = [:]
        
        for vote in votes {
            if let trackId = vote["track_id"] as? String,
               let voteTypeString = vote["vote_type"] as? String,
               let voteType = VoteType(rawValue: voteTypeString) {
                userVotes[trackId] = voteType
            }
        }
        
        return userVotes
    }
}

// MARK: - Real-time subscriptions
extension SupabaseService {
    func subscribeToEventTracks(eventId: String, onUpdate: @escaping ([Track]) -> Void) {
        // For now, implement a polling mechanism as real-time subscriptions need proper setup
        // Real-time subscriptions can be implemented when the Supabase real-time API is properly configured
        fallbackToPolling(eventId: eventId, onUpdate: onUpdate)
    }
    
    private func fallbackToPolling(eventId: String, onUpdate: @escaping ([Track]) -> Void) {
        // Fallback polling mechanism
        Task {
            while true {
                do {
                    let tracks = try await self.fetchEventTracks(eventId: eventId)
                    await MainActor.run {
                        onUpdate(tracks)
                    }
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                } catch {
                    print("Error fetching tracks: \(error)")
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds on error
                }
            }
        }
    }
}

// MARK: - Helper Methods
extension SupabaseService {
    func updateTrackVoteCount(trackId: String, eventId: String) async throws {
        print("🔢 Calculating vote count for track \(trackId) in event \(eventId)")
        
        // Get all votes for this track in this specific event
        let votesResponse = try await client
            .from("votes")
            .select("vote_type")
            .eq("track_id", value: trackId)
            .eq("event_id", value: eventId)
            .execute()
        
        let votes: [[String: Any]]
        let data = votesResponse.data
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
        votes = jsonArray as? [[String: Any]] ?? []
        
        print("🗳️ Raw votes data for event \(eventId): \(votes)")
        
        var upVotes = 0
        var downVotes = 0
        
        for vote in votes {
            if let voteType = vote["vote_type"] as? String {
                if voteType == "up" {
                    upVotes += 1
                } else if voteType == "down" {
                    downVotes += 1
                }
            }
        }
        
        let totalVotes = max(0, upVotes - downVotes) // Ensure non-negative
        
        print("📊 Vote calculation for event \(eventId): \(upVotes) up, \(downVotes) down, total: \(totalVotes)")
        
        // First, let's check the current track vote count before updating
        let currentTrackResponse = try await client
            .from("tracks")
            .select("votes")
            .eq("id", value: trackId)
            .execute()
        
        let currentTrackData = currentTrackResponse.data
        let currentJson = try JSONSerialization.jsonObject(with: currentTrackData, options: [])
        if let trackArray = currentJson as? [[String: Any]], let track = trackArray.first {
            let currentVotes = track["votes"] as? Int ?? 0
            print("🎵 Current track votes in DB before update: \(currentVotes)")
        }
        
        // Update track with new vote count using a simpler approach
        struct TrackVoteUpdate: Codable {
            let votes: Int
            
            enum CodingKeys: String, CodingKey {
                case votes
            }
        }
        
        let updateData = TrackVoteUpdate(votes: totalVotes)
        
        print("🔄 Attempting to update track votes to \(totalVotes)")
        
        let updateResponse = try await client
            .from("tracks")
            .update(updateData)
            .eq("id", value: trackId)
            .execute()
        
        print("🔄 Update response status: \(updateResponse)")
        
        // Verify the update worked by fetching the track again
        let verifyResponse = try await client
            .from("tracks")
            .select("votes, updated_at")
            .eq("id", value: trackId)
            .execute()
        
        let verifyData = verifyResponse.data
        let verifyJson = try JSONSerialization.jsonObject(with: verifyData, options: [])
        if let verifyArray = verifyJson as? [[String: Any]], let verifyTrack = verifyArray.first {
            let finalVotes = verifyTrack["votes"] as? Int ?? 0
            let updatedAt = verifyTrack["updated_at"] as? String ?? "unknown"
            print("🔍 Verification - Track votes now: \(finalVotes), updated_at: \(updatedAt)")
            
            if finalVotes != totalVotes {
                print("⚠️ WARNING: Expected \(totalVotes) but got \(finalVotes) - update may have failed!")
                throw SupabaseError.custom("Vote count update verification failed: expected \(totalVotes), got \(finalVotes)")
            } else {
                print("✅ Track vote count updated successfully to \(totalVotes)")
            }
        } else {
            print("❌ Could not verify track update - track not found")
            throw SupabaseError.custom("Could not verify track update")
        }
    }
    
    func updateTrackVoteCount(trackId: String) async throws {
        print("🔢 Calculating vote count for track \(trackId)")
        
        // First, get the track to find its event_id
        let trackResponse = try await client
            .from("tracks")
            .select("event_id")
            .eq("id", value: trackId)
            .execute()
        
        let trackData = trackResponse.data
        let trackJsonArray = try JSONSerialization.jsonObject(with: trackData, options: [])
        guard let trackArray = trackJsonArray as? [[String: Any]],
              trackArray.count == 1,
              let track = trackArray.first,
              let eventId = track["event_id"] as? String else {
            print("❌ Could not find event_id for track \(trackId)")
            throw SupabaseError.custom("Could not find event_id for track")
        }
        
        print("🎪 Track belongs to event: \(eventId)")
        
        // Use the main method with the found eventId
        try await updateTrackVoteCount(trackId: trackId, eventId: eventId)
    }
    
}

// MARK: - Debug/Test Methods
extension SupabaseService {
    func testVotingSystem(eventId: String, trackId: String) async {
        print("🧪 [SupabaseService] Testing voting system...")
        
        do {
            // First, check current vote state
            let userVotes = try await getUserVotes(eventId: eventId)
            let currentVote = userVotes[trackId]
            print("📊 Current vote for track: \(currentVote?.rawValue ?? "none")")
            
            // Get current track vote count
            let tracks = try await fetchEventTracks(eventId: eventId)
            if let track = tracks.first(where: { $0.id == trackId }) {
                print("📊 Current track vote count: \(track.votes)")
            }
            
            // Test down vote
            print("🔽 Testing DOWN vote...")
            try await voteForTrack(eventId: eventId, trackId: trackId, voteType: .down)
            
            // Check the result
            let updatedUserVotes = try await getUserVotes(eventId: eventId)
            let newVote = updatedUserVotes[trackId]
            print("📊 Vote after DOWN: \(newVote?.rawValue ?? "none")")
            
            let updatedTracks = try await fetchEventTracks(eventId: eventId)
            if let updatedTrack = updatedTracks.first(where: { $0.id == trackId }) {
                print("📊 Track vote count after DOWN: \(updatedTrack.votes)")
            }
            
            // Wait a bit for database trigger to complete
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Test up vote
            print("🔼 Testing UP vote...")
            try await voteForTrack(eventId: eventId, trackId: trackId, voteType: .up)
            
            // Check the final result
            let finalUserVotes = try await getUserVotes(eventId: eventId)
            let finalVote = finalUserVotes[trackId]
            print("📊 Vote after UP: \(finalVote?.rawValue ?? "none")")
            
            let finalTracks = try await fetchEventTracks(eventId: eventId)
            if let finalTrack = finalTracks.first(where: { $0.id == trackId }) {
                print("📊 Track vote count after UP: \(finalTrack.votes)")
            }
            
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    func testDatabaseConnection() async {
        print("🔗 Testing database connection...")
        
        do {
            // Test if we can query the users table
            _ = try await client
                .from("users")
                .select("id")
                .limit(1)
                .execute()
            print("✅ Users table accessible")
            
            // Test if we can query the events table
            _ = try await client
                .from("events")
                .select("id")
                .limit(1)
                .execute()
            print("✅ Events table accessible")
            
            // Test if we can query the tracks table
            _ = try await client
                .from("tracks")
                .select("id")
                .limit(1)
                .execute()
            print("✅ Tracks table accessible")
            
            // Test if we can query the votes table
            _ = try await client
                .from("votes")
                .select("id")
                .limit(1)
                .execute()
            print("✅ Votes table accessible")
            
            // Test if we can UPDATE tracks table
            print("🔄 Testing track update permissions...")
            let testTrackResponse = try await client
                .from("tracks")
                .select("id, votes")
                .limit(1)
                .execute()
            
            let testData = testTrackResponse.data
            let testJson = try JSONSerialization.jsonObject(with: testData, options: [])
            if let testArray = testJson as? [[String: Any]], let testTrack = testArray.first,
               let testTrackId = testTrack["id"] as? String,
               let currentVotes = testTrack["votes"] as? Int {
                
                print("🧪 Testing update on track \(testTrackId) with current votes: \(currentVotes)")
                
                // Try to update the track with the same vote count (no actual change)
                struct TestUpdate: Codable {
                    let votes: Int
                }
                
                try await client
                    .from("tracks")
                    .update(TestUpdate(votes: currentVotes))
                    .eq("id", value: testTrackId)
                    .execute()
                
                print("✅ Track update permissions work correctly")
            }
            
            print("🎉 All database tables are accessible!")
            
        } catch {
            print("❌ Database connection test failed: \(error)")
            
            if let error = error as? SupabaseError {
                print("Supabase error details: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Event Invitations
extension SupabaseService {
    func sendEventInvitation(eventId: String, userEmail: String) async throws {
        guard let currentUser = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        // First check if the event exists and if user is the host
        let eventResponse = try await client
            .from("events")
            .select("host_id")
            .eq("id", value: eventId)
            .execute()
        
        let eventData = eventResponse.data
        let eventJsonArray = try JSONSerialization.jsonObject(with: eventData, options: [])
        
        guard let eventArray = eventJsonArray as? [[String: Any]],
              eventArray.count == 1,
              let eventDict = eventArray.first,
              let hostId = eventDict["host_id"] as? String else {
            throw SupabaseError.custom("Event not found")
        }
        
        // Check if current user is the host
        if hostId != currentUser.id {
            throw SupabaseError.custom("Only the event host can send invitations")
        }
        
        // Get the user ID for the email
        let userResponse = try await client
            .from("users")
            .select("id")
            .eq("email", value: userEmail)
            .execute()
        
        let userData = userResponse.data
        let userJsonArray = try JSONSerialization.jsonObject(with: userData, options: [])
        
        guard let userArray = userJsonArray as? [[String: Any]],
              userArray.count == 1,
              let userDict = userArray.first,
              let targetUserId = userDict["id"] as? String else {
            throw SupabaseError.custom("User not found")
        }
        
        // Check if invitation already exists
        let existingResponse = try await client
            .from("event_invitations")
            .select("id")
            .eq("event_id", value: eventId)
            .eq("user_id", value: targetUserId)
            .execute()
        
        let existingData = existingResponse.data
        let existingJsonArray = try JSONSerialization.jsonObject(with: existingData, options: [])
        let existingInvitations = existingJsonArray as? [[String: Any]] ?? []
        
        if !existingInvitations.isEmpty {
            throw SupabaseError.custom("Invitation already sent to this user")
        }
        
        // Create new invitation
        let invitation = EventInvitation(
            eventId: eventId,
            userId: targetUserId,
            hostId: currentUser.id
        )
        
        try await client
            .from("event_invitations")
            .insert(invitation)
            .execute()
    }
    
    func cancelInvitation(invitationId: String) async throws {
        guard let currentUser = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        // First verify the invitation exists and the current user is the host
        let invitationResponse = try await client
            .from("event_invitations")
            .select("event_id")
            .eq("id", value: invitationId)
            .execute()
        
        let invitationData = invitationResponse.data
        let invitationJsonArray = try JSONSerialization.jsonObject(with: invitationData, options: [])
        
        guard let invitationArray = invitationJsonArray as? [[String: Any]],
              invitationArray.count == 1,
              let invitationDict = invitationArray.first,
              let eventId = invitationDict["event_id"] as? String else {
            throw SupabaseError.custom("Invitation not found")
        }
        
        // Check if current user is the event host
        let eventResponse = try await client
            .from("events")
            .select("host_id")
            .eq("id", value: eventId)
            .execute()
        
        let eventData = eventResponse.data
        let eventJsonArray = try JSONSerialization.jsonObject(with: eventData, options: [])
        
        guard let eventArray = eventJsonArray as? [[String: Any]],
              eventArray.count == 1,
              let eventDict = eventArray.first,
              let hostId = eventDict["host_id"] as? String,
              hostId == currentUser.id else {
            throw SupabaseError.custom("Only the event host can cancel invitations")
        }
        
        // Delete the invitation
        try await client
            .from("event_invitations")
            .delete()
            .eq("id", value: invitationId)
            .execute()
    }
    
    func respondToInvitation(invitationId: String, status: InvitationStatus) async throws {
        guard let currentUser = currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        // Verify the invitation exists and belongs to the current user
        let invitationResponse = try await client
            .from("event_invitations")
            .select("user_id")
            .eq("id", value: invitationId)
            .execute()
        
        let invitationData = invitationResponse.data
        let invitationJsonArray = try JSONSerialization.jsonObject(with: invitationData, options: [])
        
        guard let invitationArray = invitationJsonArray as? [[String: Any]],
              invitationArray.count == 1,
              let invitationDict = invitationArray.first,
              let userId = invitationDict["user_id"] as? String,
              userId == currentUser.id else {
            throw SupabaseError.custom("Invitation not found or access denied")
        }
        
        // Update the invitation status
        struct InvitationUpdate: Codable {
            let status: String
        }
        
        let updateData = InvitationUpdate(status: status.rawValue)
        
        try await client
            .from("event_invitations")
            .update(updateData)
            .eq("id", value: invitationId)
            .execute()
    }
    
    func fetchSentInvitations() async throws -> [EventInvitation] {
        guard let currentUser = currentUser else {
            throw SupabaseError.notAuthenticated
        }

        // Get invitations for events hosted by current user
        // Since host_id column might not exist, we'll get all invitations and filter by event host
        let allInvitationsResponse = try await client
            .from("event_invitations")
            .select("id, event_id, user_id, host_id, status, created_at")
            .order("created_at", ascending: false)
            .execute()

        let allData = allInvitationsResponse.data
        let allJsonArray = try JSONSerialization.jsonObject(with: allData, options: [])
        guard let allInvitationDictionaries = allJsonArray as? [[String: Any]] else {
            return []
        }

        // Convert to invitations and fetch related data, filtering for current user's events
        var invitations: [EventInvitation] = []
        
        for dict in allInvitationDictionaries {
            // Check if this invitation is for an event hosted by current user
            if let eventId = dict["event_id"] as? String {
                do {
                    let eventResponse = try await client
                        .from("events")
                        .select("name, host_id")
                        .eq("id", value: eventId)
                        .eq("host_id", value: currentUser.id) // Only get events hosted by current user
                        .execute()
                    
                    let eventData = eventResponse.data
                    let eventJsonArray = try JSONSerialization.jsonObject(with: eventData, options: [])
                    
                    // Check if we got exactly one event hosted by current user
                    guard let eventArray = eventJsonArray as? [[String: Any]],
                          eventArray.count == 1,
                          let eventJson = eventArray.first,
                          let eventName = eventJson["name"] as? String else {
                        // This invitation is not for an event hosted by current user, skip it
                        continue
                    }
                    
                    // Create invitation with correct hostId
                    var modifiedDict = dict
                    modifiedDict["host_id"] = currentUser.id
                    
                    var invitation = try EventInvitation.from(dictionary: modifiedDict)
                    invitation.eventName = eventName
                    
                    // Fetch user email (invited user)
                    if let userId = dict["user_id"] as? String {
                        do {
                            let userResponse = try await client
                                .from("users")
                                .select("email")
                                .eq("id", value: userId)
                                .execute()
                            
                            let userData = userResponse.data
                            let userJsonArray = try JSONSerialization.jsonObject(with: userData, options: [])
                            
                            if let userArray = userJsonArray as? [[String: Any]],
                               userArray.count == 1,
                               let userDict = userArray.first,
                               let userEmail = userDict["email"] as? String {
                                invitation.userEmail = userEmail
                            }
                        } catch {
                            print("Error fetching user email for invitation: \(error)")
                        }
                    }
                    
                    invitations.append(invitation)
                } catch {
                    print("Error fetching event for invitation: \(error)")
                }
            }
        }
        
        return invitations
    }
    
    func fetchReceivedInvitations() async throws -> [EventInvitation] {
        guard let currentUser = currentUser else {
            throw SupabaseError.notAuthenticated
        }

        // Get invitations where the current user is the invited user
        let response = try await client
            .from("event_invitations")
            .select("id, event_id, user_id, host_id, status, created_at")
            .eq("user_id", value: currentUser.id)
            .order("created_at", ascending: false)
            .execute()

        let data = response.data
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
        guard let invitationDictionaries = jsonArray as? [[String: Any]] else {
            return []
        }

        // Convert to EventInvitation objects
        var invitations: [EventInvitation] = []
        
        for dict in invitationDictionaries {
            var invitation = try EventInvitation.from(dictionary: dict)
            
            // Fetch event name
            if let eventId = dict["event_id"] as? String {
                do {
                    let eventResponse = try await client
                        .from("events")
                        .select("name")
                        .eq("id", value: eventId)
                        .execute()
                    
                    let eventData = eventResponse.data
                    let eventJsonArray = try JSONSerialization.jsonObject(with: eventData, options: [])
                    
                    if let eventArray = eventJsonArray as? [[String: Any]],
                       eventArray.count == 1,
                       let event = eventArray.first,
                       let eventName = event["name"] as? String {
                        invitation.eventName = eventName
                    }
                } catch {
                    print("🔍 [DEBUG] fetchEventName error: \(error)")
                    // Continue with invitation even if event name fetch fails
                }
            }
            
            invitations.append(invitation)
        }
        
        return invitations
    }
}


// MARK: - Google Sign In
extension SupabaseService {
    func signInWithGoogle(presenting: UIViewController) async throws -> User {
        // Configure Google Sign In using centralized config
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Config.googleClientID)
        
        // Perform Google Sign In
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        } catch {
            print("🔍 [DEBUG] Google Sign In UI error: \(error)")
            
            // Check for user cancellation
            if error.localizedDescription.contains("cancel") {
                throw SupabaseError.custom("Google Sign In was cancelled")
            } else {
                throw SupabaseError.custom("Google Sign In failed: \(error.localizedDescription)")
            }
        }
        
        let user = result.user
        
        guard let idToken = user.idToken?.tokenString else {
            throw SupabaseError.custom("Failed to get Google ID token")
        }
        
        // Get access token
        let accessToken = user.accessToken.tokenString
        
        print("🔍 [DEBUG] Google Sign In - Got tokens successfully")
        print("🔍 [DEBUG] Google Sign In - ID Token preview: \(String(idToken.prefix(20)))...")
        
        // Sign in with Supabase using Google token
        let session: Session
        do {
            session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
        } catch {
            print("🔍 [DEBUG] Supabase Google OAuth error: \(error)")
            
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("audience") {
                throw SupabaseError.custom("Google Sign In configuration error. The Google Client ID in your app doesn't match the one configured in Supabase. Please check your setup.")
            } else if errorMessage.contains("invalid_token") {
                throw SupabaseError.custom("Invalid Google token. Please try signing in again.")
            } else {
                throw SupabaseError.custom("Authentication failed: \(error.localizedDescription)")
            }
        }
        
        let authUser = session.user
        let authUserId = authUser.id.uuidString.lowercased()
        
        print("🔍 [DEBUG] Google Sign In - Auth user ID: \(authUserId)")
        print("🔍 [DEBUG] Google Sign In - Auth user email: \(authUser.email ?? "nil")")
        
        // Try to fetch existing user from database
        let userProfile: User
        do {
            userProfile = try await fetchUser(userId: authUserId)
            print("🔍 [DEBUG] Google Sign In - Found existing user: \(userProfile.username)")
        } catch {
            print("🔍 [DEBUG] Google Sign In - User not found, creating new user")
            
            // Create new user profile with Google info
            let googleProfile = user.profile
            let newUser = User(
                id: authUserId,
                username: googleProfile?.name ?? googleProfile?.givenName ?? "GoogleUser",
                email: authUser.email ?? googleProfile?.email ?? "",
                profileImageURL: googleProfile?.imageURL(withDimension: 200)?.absoluteString,
                displayName: googleProfile?.name,
                bio: nil,
                location: nil,
                dateOfBirth: nil,
                phoneNumber: nil,
                website: nil,
                spotifyConnected: false,
                youtubeConnected: true,
                licenseType: .free,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // Save to database
            do {
                try await client
                    .from("users")
                    .insert(newUser)
                    .execute()
                
                print("🔍 [DEBUG] Google Sign In - Created new user: \(newUser.username)")
                userProfile = newUser
            } catch {
                print("🔍 [DEBUG] Google Sign In - Failed to create user: \(error)")
                throw SupabaseError.custom("Failed to create user profile: \(error.localizedDescription)")
            }
        }
        
        // Update state
        await MainActor.run {
            self.currentUser = userProfile
            self.isAuthenticated = true
        }
        
        print("🔍 [DEBUG] Google Sign In - Authentication completed successfully")
        return userProfile
    }
}