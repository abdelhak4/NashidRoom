import Foundation
import Supabase

struct User: Codable, Identifiable {
    let id: String
    var username: String
    var email: String
    var profileImageURL: String?
    
    // Personal Information
    var displayName: String?
    var bio: String?
    var location: String?
    var dateOfBirth: Date?
    var phoneNumber: String?
    var website: String?
    
    // Platform Connections
    var spotifyConnected: Bool // Keep for backward compatibility
    var youtubeConnected: Bool
    var licenseType: LicenseType
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case profileImageURL = "profile_image_url"
        case displayName = "display_name"
        case bio
        case location
        case dateOfBirth = "date_of_birth"
        case phoneNumber = "phone_number"
        case website
        case spotifyConnected = "spotify_connected"
        case youtubeConnected = "youtube_connected"
        case licenseType = "license_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Convert User to Supabase dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "username": username,
            "email": email,
            "profile_image_url": profileImageURL as Any,
            "display_name": displayName as Any,
            "bio": bio as Any,
            "location": location as Any,
            "phone_number": phoneNumber as Any,
            "website": website as Any,
            "spotify_connected": spotifyConnected,
            "youtube_connected": youtubeConnected,
            "license_type": licenseType.rawValue,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
        
        // Handle date of birth separately with proper formatting
        if let dateOfBirth = dateOfBirth {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dict["date_of_birth"] = dateFormatter.string(from: dateOfBirth)
        }
        
        return dict
    }
    
    // Create User from Supabase dictionary
    static func from(dictionary: [String: Any]) throws -> User {
        guard let id = dictionary["id"] as? String,
              let username = dictionary["username"] as? String,
              let email = dictionary["email"] as? String,
              let createdAtString = dictionary["created_at"] as? String,
              let updatedAtString = dictionary["updated_at"] as? String else {
            
            print("❌ Missing required fields in user dictionary:")
            print("id: \(dictionary["id"] ?? "nil")")
            print("username: \(dictionary["username"] ?? "nil")")
            print("email: \(dictionary["email"] ?? "nil")")
            print("created_at: \(dictionary["created_at"] ?? "nil")")
            print("updated_at: \(dictionary["updated_at"] ?? "nil")")
            
            throw NSError(domain: "User", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid user data - missing required fields"])
        }
        
        // Try multiple date formatters to handle different formats
        let createdAt: Date
        let updatedAt: Date
        
        let isoFormatter = ISO8601DateFormatter()
        let isoFormatterWithFractionalSeconds = ISO8601DateFormatter()
        isoFormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try parsing created_at
        if let date = isoFormatterWithFractionalSeconds.date(from: createdAtString) {
            createdAt = date
        } else if let date = isoFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            print("❌ Failed to parse created_at: \(createdAtString)")
            throw NSError(domain: "User", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid created_at date format"])
        }
        
        // Try parsing updated_at  
        if let date = isoFormatterWithFractionalSeconds.date(from: updatedAtString) {
            updatedAt = date
        } else if let date = isoFormatter.date(from: updatedAtString) {
            updatedAt = date
        } else {
            print("❌ Failed to parse updated_at: \(updatedAtString)")
            throw NSError(domain: "User", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid updated_at date format"])
        }
        
        let licenseTypeString = dictionary["license_type"] as? String ?? "free"
        let licenseType = LicenseType(rawValue: licenseTypeString) ?? .free
        
        // Parse date of birth if present
        var dateOfBirth: Date?
        if let dobString = dictionary["date_of_birth"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateOfBirth = dateFormatter.date(from: dobString)
        }
        
        return User(
            id: id,
            username: username,
            email: email,
            profileImageURL: dictionary["profile_image_url"] as? String,
            displayName: dictionary["display_name"] as? String,
            bio: dictionary["bio"] as? String,
            location: dictionary["location"] as? String,
            dateOfBirth: dateOfBirth,
            phoneNumber: dictionary["phone_number"] as? String,
            website: dictionary["website"] as? String,
            spotifyConnected: dictionary["spotify_connected"] as? Bool ?? false,
            youtubeConnected: dictionary["youtube_connected"] as? Bool ?? true, // Default to true for YouTube
            licenseType: licenseType,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    // Create User from Supabase Auth User  
    static func from(authUser: Supabase.User) throws -> User {
        let username: String
        if let usernameValue = authUser.userMetadata["username"] {
            username = String(describing: usernameValue)
        } else {
            username = "User"
        }
        
        return User(
            id: authUser.id.uuidString,
            username: username,
            email: authUser.email ?? "",
            profileImageURL: nil,
            displayName: nil,
            bio: nil,
            location: nil,
            dateOfBirth: nil,
            phoneNumber: nil,
            website: nil,
            spotifyConnected: false,
            youtubeConnected: true, // YouTube doesn't require explicit connection
            licenseType: .free,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

enum LicenseType: String, Codable, CaseIterable {
    case free = "free"
    case premium = "premium"
    case locationBased = "location_based"
    
} 
