import Foundation
import SwiftUI

// MARK: - Unified Invitation Protocol
protocol UnifiedInvitation: Identifiable {
    var id: String { get }
    var status: InvitationStatus { get }
    var createdAt: Date { get }
    var title: String { get }
    var subtitle: String { get }
    var inviterName: String? { get }
}

struct EventInvitation: Codable, Identifiable {
    let id: String
    let eventId: String
    let userId: String
    let hostId: String
    var status: InvitationStatus
    let createdAt: Date
    var updatedAt: Date
    
    // Additional fields for UI display
    var eventName: String?
    var userEmail: String?
    var hostName: String?
    
    init(id: String = UUID().uuidString, eventId: String, userId: String, hostId: String, status: InvitationStatus = .pending, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.eventId = eventId
        self.userId = userId
        self.hostId = hostId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case hostId = "host_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "event_id": eventId,
            "user_id": userId,
            "host_id": hostId,
            "status": status.rawValue,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
    }
    
    static func from(dictionary: [String: Any]) throws -> EventInvitation {
        guard let id = dictionary["id"] as? String,
              let eventId = dictionary["event_id"] as? String,
              let userId = dictionary["user_id"] as? String,
              let hostId = dictionary["host_id"] as? String,
              let statusString = dictionary["status"] as? String,
              let createdAtString = dictionary["created_at"] as? String,
              let status = InvitationStatus(rawValue: statusString) else {
            throw NSError(domain: "EventInvitation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid invitation data"])
        }
        
        // Parse dates with multiple formatters to handle different formats
        let isoFormatterWithFractionalSeconds = ISO8601DateFormatter()
        isoFormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let isoFormatterStandard = ISO8601DateFormatter()
        
        let createdAt: Date
        let updatedAt: Date
        
        if let date = isoFormatterWithFractionalSeconds.date(from: createdAtString) {
            createdAt = date
        } else if let date = isoFormatterStandard.date(from: createdAtString) {
            createdAt = date
        } else {
            throw NSError(domain: "EventInvitation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid created_at date format"])
        }
        
        // Handle updated_at - use it if present, otherwise fall back to created_at
        if let updatedAtString = dictionary["updated_at"] as? String {
            if let date = isoFormatterWithFractionalSeconds.date(from: updatedAtString) {
                updatedAt = date
            } else if let date = isoFormatterStandard.date(from: updatedAtString) {
                updatedAt = date
            } else {
                updatedAt = createdAt // Fall back to created_at if parsing fails
            }
        } else {
            updatedAt = createdAt // Use created_at if updated_at is not present
        }
        
        return EventInvitation(
            id: id,
            eventId: eventId,
            userId: userId,
            hostId: hostId,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - EventInvitation Conformance
extension EventInvitation: UnifiedInvitation {
    var title: String {
        return eventName ?? "Unknown Event"
    }
    
    var subtitle: String {
        return "Event Invitation"
    }
    
    var inviterName: String? {
        return hostName
    }
}

enum InvitationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .declined:
            return "Declined"
        }
    }
}

// MARK: - SwiftUI Extensions
extension InvitationStatus {
    var color: Color {
        switch self {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .declined:
            return .red
        }
    }
}
