import Foundation

struct CollaborativePlaylist: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    let creatorId: String
    var visibility: PlaylistVisibility
    var editorLicenseType: PlaylistLicenseType
    let createdAt: Date
    var updatedAt: Date
    var isActive: Bool
    var trackCount: Int
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        creatorId: String,
        visibility: PlaylistVisibility = .public,
        editorLicenseType: PlaylistLicenseType = .everyone,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isActive: Bool = true,
        trackCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.creatorId = creatorId
        self.visibility = visibility
        self.editorLicenseType = editorLicenseType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
        self.trackCount = trackCount
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case creatorId = "creator_id"
        case visibility
        case editorLicenseType = "editor_license_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isActive = "is_active"
        case trackCount = "track_count"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "description": description,
            "creator_id": creatorId,
            "visibility": visibility.rawValue,
            "editor_license_type": editorLicenseType.rawValue,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt),
            "is_active": isActive,
            "track_count": trackCount
        ]
    }
    
    static func from(dictionary: [String: Any]) throws -> CollaborativePlaylist {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let creatorId = dictionary["creator_id"] as? String,
              let visibilityString = dictionary["visibility"] as? String,
              let editorLicenseString = dictionary["editor_license_type"] as? String,
              let createdAtString = dictionary["created_at"] as? String,
              let updatedAtString = dictionary["updated_at"] as? String,
              let isActive = dictionary["is_active"] as? Bool,
              let trackCount = dictionary["track_count"] as? Int,
              let visibility = PlaylistVisibility(rawValue: visibilityString),
              let editorLicenseType = PlaylistLicenseType(rawValue: editorLicenseString) else {
            throw NSError(domain: "PlaylistParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse required playlist fields"])
        }
        
        let isoFormatterWithFractionalSeconds = ISO8601DateFormatter()
        isoFormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let isoFormatterStandard = ISO8601DateFormatter()
        isoFormatterStandard.formatOptions = [.withInternetDateTime]
        
        guard let createdAt = isoFormatterWithFractionalSeconds.date(from: createdAtString) ?? isoFormatterStandard.date(from: createdAtString),
              let updatedAt = isoFormatterWithFractionalSeconds.date(from: updatedAtString) ?? isoFormatterStandard.date(from: updatedAtString) else {
            throw NSError(domain: "PlaylistParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse playlist dates"])
        }
        
        let description = dictionary["description"] as? String ?? ""
        
        return CollaborativePlaylist(
            id: id,
            name: name,
            description: description,
            creatorId: creatorId,
            visibility: visibility,
            editorLicenseType: editorLicenseType,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isActive: isActive,
            trackCount: trackCount
        )
    }
}

enum PlaylistVisibility: String, Codable, CaseIterable {
    case `public` = "public"
    case `private` = "private"
    
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .private: return "Private"
        }
    }
    
    var description: String {
        switch self {
        case .public: return "Everyone can find and access this playlist"
        case .private: return "Only invited users can access this playlist"
        }
    }
}

enum PlaylistLicenseType: String, Codable, CaseIterable {
    case everyone = "everyone"
    case invitedOnly = "invited_only"
    
    var displayName: String {
        switch self {
        case .everyone: return "Everyone can edit"
        case .invitedOnly: return "Invited users only"
        }
    }
    
    var description: String {
        switch self {
        case .everyone: return "All users with access can add and remove tracks"
        case .invitedOnly: return "Only specifically invited collaborators can edit"
        }
    }
}
