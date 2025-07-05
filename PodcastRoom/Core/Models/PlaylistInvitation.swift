import Foundation

struct PlaylistInvitation: Codable, Identifiable {
    let id: String
    let playlistId: String
    let inviterId: String
    let inviteeId: String
    var status: InvitationStatus
    var role: PlaylistRole
    let createdAt: Date
    var updatedAt: Date
    
    // Additional fields for UI display
    var playlistName: String?
    var inviterName: String?
    
    init(
        id: String = UUID().uuidString,
        playlistId: String,
        inviterId: String,
        inviteeId: String,
        status: InvitationStatus = .pending,
        role: PlaylistRole = .collaborator,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.playlistId = playlistId
        self.inviterId = inviterId
        self.inviteeId = inviteeId
        self.status = status
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case playlistId = "playlist_id"
        case inviterId = "inviter_id"
        case inviteeId = "invitee_id"
        case status
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "playlist_id": playlistId,
            "inviter_id": inviterId,
            "invitee_id": inviteeId,
            "status": status.rawValue,
            "role": role.rawValue,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
    }
    
    static func from(dictionary: [String: Any]) throws -> PlaylistInvitation {
        guard let id = dictionary["id"] as? String,
              let playlistId = dictionary["playlist_id"] as? String,
              let inviterId = dictionary["inviter_id"] as? String,
              let inviteeId = dictionary["invitee_id"] as? String,
              let statusString = dictionary["status"] as? String,
              let roleString = dictionary["role"] as? String,
              let createdAtString = dictionary["created_at"] as? String,
              let updatedAtString = dictionary["updated_at"] as? String,
              let status = InvitationStatus(rawValue: statusString),
              let role = PlaylistRole(rawValue: roleString) else {
            throw NSError(domain: "PlaylistInvitationParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse required playlist invitation fields"])
        }
        
        let isoFormatterWithFractionalSeconds = ISO8601DateFormatter()
        isoFormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let isoFormatterStandard = ISO8601DateFormatter()
        isoFormatterStandard.formatOptions = [.withInternetDateTime]
        
        guard let createdAt = isoFormatterWithFractionalSeconds.date(from: createdAtString) ?? isoFormatterStandard.date(from: createdAtString),
              let updatedAt = isoFormatterWithFractionalSeconds.date(from: updatedAtString) ?? isoFormatterStandard.date(from: updatedAtString) else {
            throw NSError(domain: "PlaylistInvitationParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse playlist invitation dates"])
        }
        
        return PlaylistInvitation(
            id: id,
            playlistId: playlistId,
            inviterId: inviterId,
            inviteeId: inviteeId,
            status: status,
            role: role,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

enum PlaylistRole: String, Codable, CaseIterable {
    case collaborator = "collaborator"
    case viewer = "viewer"
    
    var displayName: String {
        switch self {
        case .collaborator: return "Collaborator"
        case .viewer: return "Viewer"
        }
    }
    
    var description: String {
        switch self {
        case .collaborator: return "Can add, remove, and reorder tracks"
        case .viewer: return "Can view and listen but not edit"
        }
    }
    
    var canEdit: Bool {
        switch self {
        case .collaborator: return true
        case .viewer: return false
        }
    }
}

// MARK: - PlaylistInvitation Conformance
extension PlaylistInvitation: UnifiedInvitation {
    var title: String {
        return playlistName ?? "Unknown Playlist"
    }
    
    var subtitle: String {
        return "Playlist • Role: \(role.displayName)"
    }
}
