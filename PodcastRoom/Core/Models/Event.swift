import Foundation

struct Event: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    let hostId: String
    var visibility: EventVisibility
    var licenseType: LicenseType
    var locationLat: Double?
    var locationLng: Double?
    var locationRadius: Int? // meters
    var timeStart: Date?
    var timeEnd: Date?
    let spotifyPlaylistId: String
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date
    
    init(id: String = UUID().uuidString, name: String, description: String, hostId: String, visibility: EventVisibility = .public, licenseType: LicenseType = .free, locationLat: Double? = nil, locationLng: Double? = nil, locationRadius: Int? = nil, timeStart: Date? = nil, timeEnd: Date? = nil, spotifyPlaylistId: String, isActive: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.hostId = hostId
        self.visibility = visibility
        self.licenseType = licenseType
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.locationRadius = locationRadius
        self.timeStart = timeStart
        self.timeEnd = timeEnd
        self.spotifyPlaylistId = spotifyPlaylistId
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case hostId = "host_id"
        case visibility
        case licenseType = "license_type"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case locationRadius = "location_radius"
        case timeStart = "time_start"
        case timeEnd = "time_end"
        case spotifyPlaylistId = "spotify_playlist_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "description": description,
            "host_id": hostId,
            "visibility": visibility.rawValue,
            "license_type": licenseType.rawValue,
            "spotify_playlist_id": spotifyPlaylistId,
            "is_active": isActive,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
        
        if let lat = locationLat { dict["location_lat"] = lat }
        if let lng = locationLng { dict["location_lng"] = lng }
        if let radius = locationRadius { dict["location_radius"] = radius }
        if let start = timeStart { dict["time_start"] = ISO8601DateFormatter().string(from: start) }
        if let end = timeEnd { dict["time_end"] = ISO8601DateFormatter().string(from: end) }
        
        return dict
    }
    
    static func from(dictionary: [String: Any]) throws -> Event {
        // Debug the dictionary contents
        print("Parsing event dictionary: \(dictionary)")
        
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let hostId = dictionary["host_id"] as? String,
              let visibilityString = dictionary["visibility"] as? String,
              let licenseTypeString = dictionary["license_type"] as? String,
              let spotifyPlaylistId = dictionary["spotify_playlist_id"] as? String,
              let isActive = dictionary["is_active"] as? Bool,
              let createdAtString = dictionary["created_at"] as? String,
              let updatedAtString = dictionary["updated_at"] as? String,
              let visibility = EventVisibility(rawValue: visibilityString),
              let licenseType = LicenseType(rawValue: licenseTypeString) else {
                
            // Debug which field is failing
            print("Failed to parse required fields:")
            print("id: \(dictionary["id"] ?? "nil")")
            print("name: \(dictionary["name"] ?? "nil")")
            print("host_id: \(dictionary["host_id"] ?? "nil")")
            print("visibility: \(dictionary["visibility"] ?? "nil")")
            print("license_type: \(dictionary["license_type"] ?? "nil")")
            print("spotify_playlist_id: \(dictionary["spotify_playlist_id"] ?? "nil")")
            print("is_active: \(dictionary["is_active"] ?? "nil")")
            print("created_at: \(dictionary["created_at"] ?? "nil")")
            print("updated_at: \(dictionary["updated_at"] ?? "nil")")
            
            throw NSError(domain: "Event", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid event data - missing required fields"])
        }
        
        // Parse dates with multiple formatters to handle different formats
        let createdAt: Date
        let updatedAt: Date
        
        // Try ISO8601 with fractional seconds first, then without
        let isoFormatterWithFractionalSeconds = ISO8601DateFormatter()
        isoFormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let isoFormatterStandard = ISO8601DateFormatter()
        
        if let date = isoFormatterWithFractionalSeconds.date(from: createdAtString) {
            createdAt = date
        } else if let date = isoFormatterStandard.date(from: createdAtString) {
            createdAt = date
        } else {
            print("Failed to parse created_at date: \(createdAtString)")
            throw NSError(domain: "Event", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid created_at date format: \(createdAtString)"])
        }
        
        if let date = isoFormatterWithFractionalSeconds.date(from: updatedAtString) {
            updatedAt = date
        } else if let date = isoFormatterStandard.date(from: updatedAtString) {
            updatedAt = date
        } else {
            print("Failed to parse updated_at date: \(updatedAtString)")
            throw NSError(domain: "Event", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid updated_at date format: \(updatedAtString)"])
        }
        
        // Parse optional fields, handling null values
        let description = dictionary["description"] as? String ?? ""
        
        // Parse optional time fields with same flexible date parsing
        let timeStart: Date? = {
            if let timeString = dictionary["time_start"] as? String {
                if let date = isoFormatterWithFractionalSeconds.date(from: timeString) {
                    return date
                } else if let date = isoFormatterStandard.date(from: timeString) {
                    return date
                }
            }
            return nil
        }()
        
        let timeEnd: Date? = {
            if let timeString = dictionary["time_end"] as? String {
                if let date = isoFormatterWithFractionalSeconds.date(from: timeString) {
                    return date
                } else if let date = isoFormatterStandard.date(from: timeString) {
                    return date
                }
            }
            return nil
        }()
        
        // Handle null values for numeric fields
        let locationLat: Double? = {
            if let value = dictionary["location_lat"], !(value is NSNull) {
                return value as? Double
            }
            return nil
        }()
        
        let locationLng: Double? = {
            if let value = dictionary["location_lng"], !(value is NSNull) {
                return value as? Double
            }
            return nil
        }()
        
        let locationRadius: Int? = {
            if let value = dictionary["location_radius"], !(value is NSNull) {
                return value as? Int
            }
            return nil
        }()
        
        return Event(
            id: id,
            name: name,
            description: description,
            hostId: hostId,
            visibility: visibility,
            licenseType: licenseType,
            locationLat: locationLat,
            locationLng: locationLng,
            locationRadius: locationRadius,
            timeStart: timeStart,
            timeEnd: timeEnd,
            spotifyPlaylistId: spotifyPlaylistId,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

enum EventVisibility: String, Codable, CaseIterable {
    case `public` = "public"
    case `private` = "private"
}
