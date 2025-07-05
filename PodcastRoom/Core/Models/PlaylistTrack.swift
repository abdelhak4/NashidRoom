import Foundation

struct PlaylistTrack: Codable, Identifiable {
    let id: String
    let playlistId: String
    let trackId: String // YouTube video ID
    let addedBy: String // User ID who added this track
    var position: Int
    let addedAt: Date
    
    // Track details (cached from YouTube API)
    var title: String?
    var artist: String?
    var album: String?
    var duration: Int? // in milliseconds
    var imageUrl: String?
    var youtubeUrl: String?
    
    init(
        id: String = UUID().uuidString,
        playlistId: String,
        trackId: String,
        addedBy: String,
        position: Int,
        addedAt: Date = Date(),
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        duration: Int? = nil,
        imageUrl: String? = nil,
        youtubeUrl: String? = nil
    ) {
        self.id = id
        self.playlistId = playlistId
        self.trackId = trackId
        self.addedBy = addedBy
        self.position = position
        self.addedAt = addedAt
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.imageUrl = imageUrl
        self.youtubeUrl = youtubeUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case playlistId = "playlist_id"
        case trackId = "track_id"
        case addedBy = "added_by"
        case position
        case addedAt = "added_at"
        case title
        case artist
        case album
        case duration
        case imageUrl = "image_url"
        case youtubeUrl = "youtube_url"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "playlist_id": playlistId,
            "track_id": trackId,
            "added_by": addedBy,
            "position": position,
            "added_at": ISO8601DateFormatter().string(from: addedAt)
        ]
        
        if let title = title { dict["title"] = title }
        if let artist = artist { dict["artist"] = artist }
        if let album = album { dict["album"] = album }
        if let duration = duration { dict["duration"] = duration }
        if let imageUrl = imageUrl { dict["image_url"] = imageUrl }
        if let youtubeUrl = youtubeUrl { dict["youtube_url"] = youtubeUrl }
        
        return dict
    }
    
    static func from(dictionary: [String: Any]) throws -> PlaylistTrack {
        guard let id = dictionary["id"] as? String,
              let playlistId = dictionary["playlist_id"] as? String,
              let trackId = dictionary["track_id"] as? String,
              let addedBy = dictionary["added_by"] as? String,
              let position = dictionary["position"] as? Int,
              let addedAtString = dictionary["added_at"] as? String else {
            throw NSError(domain: "PlaylistTrackParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse required playlist track fields"])
        }
        
        let isoFormatterWithFractionalSeconds = ISO8601DateFormatter()
        isoFormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let isoFormatterStandard = ISO8601DateFormatter()
        isoFormatterStandard.formatOptions = [.withInternetDateTime]
        
        guard let addedAt = isoFormatterWithFractionalSeconds.date(from: addedAtString) ?? isoFormatterStandard.date(from: addedAtString) else {
            throw NSError(domain: "PlaylistTrackParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse playlist track date"])
        }
        
        return PlaylistTrack(
            id: id,
            playlistId: playlistId,
            trackId: trackId,
            addedBy: addedBy,
            position: position,
            addedAt: addedAt,
            title: dictionary["title"] as? String,
            artist: dictionary["artist"] as? String,
            album: dictionary["album"] as? String,
            duration: dictionary["duration"] as? Int,
            imageUrl: dictionary["image_url"] as? String,
            youtubeUrl: dictionary["youtube_url"] as? String
        )
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "0:00" }
        let totalSeconds = duration / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Convert PlaylistTrack to Track for audio player
    var track: Track {
        let convertedTrack = Track(
            id: trackId,
            title: title ?? "Unknown Track",
            artist: artist ?? "Unknown Artist",
            album: album,
            duration: TimeInterval((duration ?? 0) / 1000), // Convert milliseconds to seconds
            artworkURL: imageUrl,
            previewURL: nil,
            youtubeVideoId: trackId, // Using trackId as YouTube video ID
            youtubeURL: youtubeUrl,
            addedBy: addedBy,
            position: position,
            addedAt: addedAt
        )
        
        print("🎵 Converting PlaylistTrack to Track:")
        print("   - PlaylistTrack ID: \(id)")
        print("   - Track ID (from trackId): \(trackId)")
        print("   - Title: \(title ?? "Unknown")")
        print("   - Artist: \(artist ?? "Unknown")")
        print("   - YouTube URL: \(youtubeUrl ?? "none")")
        print("   - Converted YouTube Video ID: \(convertedTrack.youtubeVideoId ?? "none")")
        print("   - Duration: \(convertedTrack.duration)s")
        
        return convertedTrack
    }
}
