import Foundation

struct FriendRequest: Codable, Identifiable {
    let id: String
    let requesterId: String
    let recipientId: String
    let status: FriendRequestStatus
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case recipientId = "recipient_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Convert FriendRequest to Supabase dictionary
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "requester_id": requesterId,
            "recipient_id": recipientId,
            "status": status.rawValue,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
    }
    
    // Create FriendRequest from Supabase dictionary
    static func from(dictionary: [String: Any]) throws -> FriendRequest {
        guard let id = dictionary["id"] as? String,
              let requesterId = dictionary["requester_id"] as? String,
              let recipientId = dictionary["recipient_id"] as? String,
              let createdAtString = dictionary["created_at"] as? String,
              let updatedAtString = dictionary["updated_at"] as? String else {
            throw NSError(domain: "FriendRequest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid friend request data - missing required fields"])
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
            throw NSError(domain: "FriendRequest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid created_at date format"])
        }
        
        if let date = isoFormatterWithFractionalSeconds.date(from: updatedAtString) {
            updatedAt = date
        } else if let date = isoFormatter.date(from: updatedAtString) {
            updatedAt = date
        } else {
            throw NSError(domain: "FriendRequest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid updated_at date format"])
        }
        
        let statusString = dictionary["status"] as? String ?? "pending"
        let status = FriendRequestStatus(rawValue: statusString) ?? .pending
        
        return FriendRequest(
            id: id,
            requesterId: requesterId,
            recipientId: recipientId,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

enum FriendRequestStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
}
