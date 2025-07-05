import Foundation

struct Vote: Codable {
    let userId: String
    let trackId: String
    let eventId: String
    let voteType: VoteType
    let createdAt: Date
    let updatedAt: Date
    
    init(userId: String, trackId: String, eventId: String, voteType: VoteType, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.userId = userId
        self.trackId = trackId
        self.eventId = eventId
        self.voteType = voteType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case trackId = "track_id"
        case eventId = "event_id"
        case voteType = "vote_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "user_id": userId,
            "track_id": trackId,
            "event_id": eventId,
            "vote_type": voteType.rawValue,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
    }
    
    static func from(dictionary: [String: Any]) throws -> Vote {
        guard let userId = dictionary["user_id"] as? String,
              let trackId = dictionary["track_id"] as? String,
              let eventId = dictionary["event_id"] as? String,
              let voteTypeString = dictionary["vote_type"] as? String,
              let createdAtString = dictionary["created_at"] as? String,
              let updatedAtString = dictionary["updated_at"] as? String,
              let createdAt = ISO8601DateFormatter().date(from: createdAtString),
              let updatedAt = ISO8601DateFormatter().date(from: updatedAtString),
              let voteType = VoteType(rawValue: voteTypeString) else {
            throw NSError(domain: "Vote", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid vote data"])
        }
        
        return Vote(
            userId: userId,
            trackId: trackId,
            eventId: eventId,
            voteType: voteType,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

enum VoteType: String, Codable {
    case up = "up"
    case down = "down"
}
