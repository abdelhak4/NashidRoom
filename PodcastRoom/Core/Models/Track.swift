import Foundation

struct Track: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var artist: String
    var album: String?
    var duration: TimeInterval
    var artworkURL: String?
    var previewURL: String?
    var spotifyURI: String? // Keep for backward compatibility
    var youtubeVideoId: String?
    var youtubeURL: String?
    var eventId: String?
    var addedBy: String?
    var votes: Int
    var position: Int
    var isPlayed: Bool
    var addedAt: Date
    var updatedAt: Date
    
    init(id: String, title: String, artist: String, album: String? = nil, duration: TimeInterval, artworkURL: String? = nil, previewURL: String? = nil, spotifyURI: String? = nil, youtubeVideoId: String? = nil, youtubeURL: String? = nil, eventId: String? = nil, addedBy: String? = nil, votes: Int = 0, position: Int = 0, isPlayed: Bool = false, addedAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        self.previewURL = previewURL
        self.spotifyURI = spotifyURI
        self.youtubeVideoId = youtubeVideoId
        self.youtubeURL = youtubeURL
        self.eventId = eventId
        self.addedBy = addedBy
        self.votes = votes
        self.position = position
        self.isPlayed = isPlayed
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case album
        case duration
        case artworkURL = "artwork_url"
        case previewURL = "preview_url"
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
    
    // Convert Track to Supabase dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "artist": artist,
            "duration": Int(duration),
            "votes": votes,
            "position": position,
            "is_played": isPlayed,
            "added_at": ISO8601DateFormatter().string(from: addedAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
        
        if let eventId = eventId { dict["event_id"] = eventId }
        if let addedBy = addedBy { dict["added_by"] = addedBy }
        if let album = album { dict["album"] = album }
        if let artworkURL = artworkURL { dict["artwork_url"] = artworkURL }
        if let previewURL = previewURL { dict["preview_url"] = previewURL }
        if let spotifyURI = spotifyURI { dict["spotify_uri"] = spotifyURI }
        if let youtubeVideoId = youtubeVideoId { dict["youtube_video_id"] = youtubeVideoId }
        if let youtubeURL = youtubeURL { dict["youtube_url"] = youtubeURL }
        
        return dict
    }
    
    // Create Track from Supabase dictionary
    static func from(dictionary: [String: Any]) throws -> Track {
        // Debug the dictionary contents
        print("Parsing track dictionary: \(dictionary)")
        
        guard let id = dictionary["id"] as? String,
              let title = dictionary["title"] as? String,
              let artist = dictionary["artist"] as? String else {
            // Debug which field is failing
            print("Failed to parse required fields:")
            print("id: \(dictionary["id"] ?? "nil") (type: \(type(of: dictionary["id"])))")
            print("title: \(dictionary["title"] ?? "nil") (type: \(type(of: dictionary["title"])))")
            print("artist: \(dictionary["artist"] ?? "nil") (type: \(type(of: dictionary["artist"])))")
            print("duration: \(dictionary["duration"] ?? "nil") (type: \(type(of: dictionary["duration"])))")
            
            throw NSError(domain: "Track", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid track data - missing required fields"])
        }
        
        // Handle duration as various numeric types that Supabase might return
        let durationInt: Int
        if let duration = dictionary["duration"] as? Int {
            durationInt = duration
        } else if let duration = dictionary["duration"] as? Double {
            durationInt = Int(duration)
        } else if let duration = dictionary["duration"] as? NSNumber {
            durationInt = duration.intValue
        } else if let durationString = dictionary["duration"] as? String, let duration = Int(durationString) {
            durationInt = duration
        } else {
            print("Failed to parse duration: \(dictionary["duration"] ?? "nil") (type: \(type(of: dictionary["duration"])))")
            throw NSError(domain: "Track", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid track data - invalid duration"])
        }
        
        // Handle optional numeric fields with type flexibility
        let votes: Int
        if let v = dictionary["votes"] as? Int {
            votes = v
        } else if let v = dictionary["votes"] as? Double {
            votes = Int(v)
        } else if let v = dictionary["votes"] as? NSNumber {
            votes = v.intValue
        } else {
            votes = 0
        }
        
        let position: Int
        if let p = dictionary["position"] as? Int {
            position = p
        } else if let p = dictionary["position"] as? Double {
            position = Int(p)
        } else if let p = dictionary["position"] as? NSNumber {
            position = p.intValue
        } else {
            position = 0
        }
        
        // Handle boolean fields
        let isPlayed: Bool
        if let played = dictionary["is_played"] as? Bool {
            isPlayed = played
        } else if let played = dictionary["is_played"] as? NSNumber {
            isPlayed = played.boolValue
        } else if let played = dictionary["is_played"] as? String {
            isPlayed = played.lowercased() == "true" || played == "1"
        } else {
            isPlayed = false
        }
        
        // Parse dates with multiple formatters to handle different formats
        let addedAt: Date
        let updatedAt: Date
        
        // Helper function to try multiple date formats
        func parseDate(from dateString: String) -> Date? {
            // Try ISO8601 formatter first
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 with fractional seconds
            let iso8601FractionalFormatter = ISO8601DateFormatter()
            iso8601FractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601FractionalFormatter.date(from: dateString) {
                return date
            }
            
            // Try custom date format with microseconds
            let microsecondsFormatter = DateFormatter()
            microsecondsFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            microsecondsFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = microsecondsFormatter.date(from: dateString) {
                return date
            }
            
            // Try custom date format without microseconds
            let standardFormatter = DateFormatter()
            standardFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            standardFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = standardFormatter.date(from: dateString) {
                return date
            }
            
            return nil
        }
        
        if let addedAtString = dictionary["added_at"] as? String {
            addedAt = parseDate(from: addedAtString) ?? Date()
        } else {
            addedAt = Date()
        }
        
        if let updatedAtString = dictionary["updated_at"] as? String {
            updatedAt = parseDate(from: updatedAtString) ?? Date()
        } else {
            updatedAt = Date()
        }
        
        return Track(
            id: id,
            title: title,
            artist: artist,
            album: dictionary["album"] as? String,
            duration: TimeInterval(durationInt),
            artworkURL: dictionary["artwork_url"] as? String,
            previewURL: dictionary["preview_url"] as? String,
            spotifyURI: dictionary["spotify_uri"] as? String,
            youtubeVideoId: dictionary["youtube_video_id"] as? String,
            youtubeURL: dictionary["youtube_url"] as? String,
            eventId: dictionary["event_id"] as? String,
            addedBy: dictionary["added_by"] as? String,
            votes: votes,
            position: position,
            isPlayed: isPlayed,
            addedAt: addedAt,
            updatedAt: updatedAt
        )
    }
} 