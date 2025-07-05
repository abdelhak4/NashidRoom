import Foundation

struct Friend: Codable, Identifiable {
    let id: String
    let userId: String
    let friendId: String
    let status: FriendStatus
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Convert Friend to Supabase dictionary
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "user_id": userId,
            "friend_id": friendId,
            "status": status.rawValue,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
    }
    
    // Create Friend from Supabase dictionary
    static func from(dictionary: [String: Any]) throws -> Friend {
        guard let id = dictionary["id"] as? String,
              let userId = dictionary["user_id"] as? String,
              let friendId = dictionary["friend_id"] as? String,
              let createdAtString = dictionary["created_at"] as? String,
              let updatedAtString = dictionary["updated_at"] as? String else {
            throw NSError(domain: "Friend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid friend data - missing required fields"])
        }
        
        // Parse dates
        let isoFormatter = ISO8601DateFormatter()
        let isoFormatterWithFractionalSeconds = ISO8601DateFormatter()
        isoFormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdAt: Date
        let updatedAt: Date
        
        if let date = isoFormatterWithFractionalSeconds.date(from: createdAtString) {
            createdAt = date
        } else if let date = isoFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            throw NSError(domain: "Friend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid created_at date format"])
        }
        
        if let date = isoFormatterWithFractionalSeconds.date(from: updatedAtString) {
            updatedAt = date
        } else if let date = isoFormatter.date(from: updatedAtString) {
            updatedAt = date
        } else {
            throw NSError(domain: "Friend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid updated_at date format"])
        }
        
        let statusString = dictionary["status"] as? String ?? "accepted"
        let status = FriendStatus(rawValue: statusString) ?? .accepted
        
        return Friend(
            id: id,
            userId: userId,
            friendId: friendId,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

enum FriendStatus: String, Codable, CaseIterable {
    case accepted = "accepted"
}
