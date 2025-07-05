import Foundation
import SwiftUI

class YouTubeService: ObservableObject {
    static let shared = YouTubeService()
    
    @Published var isConnected = true // YouTube API doesn't require authentication for basic search
    
    private let apiKey: String
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    
    private init() {
        self.apiKey = Config.youtubeAPIKey
    }
    
    func configure() {
        // YouTube API doesn't require additional configuration for basic usage
        print("YouTube Service configured")
    }
    
    func searchTracks(query: String) async throws -> [Track] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search?part=snippet&type=video&videoCategoryId=10&maxResults=20&q=\(encodedQuery)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw YouTubeError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw YouTubeError.networkError
            }
            
            let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
            
            // Get video details including duration for each video
            let videoIds = searchResponse.items.map { $0.id.videoId }.joined(separator: ",")
            let detailsUrlString = "\(baseURL)/videos?part=contentDetails,snippet&id=\(videoIds)&key=\(apiKey)"
            
            guard let detailsUrl = URL(string: detailsUrlString) else {
                throw YouTubeError.invalidURL
            }
            
            let (detailsData, detailsHttpResponse) = try await URLSession.shared.data(from: detailsUrl)
            
            guard let httpDetailsResponse = detailsHttpResponse as? HTTPURLResponse,
                  httpDetailsResponse.statusCode == 200 else {
                throw YouTubeError.networkError
            }
            
            let detailsResponse = try JSONDecoder().decode(YouTubeVideoDetailsResponse.self, from: detailsData)
            
            return detailsResponse.items.map { videoDetail in
                let duration = parseDuration(videoDetail.contentDetails.duration)
                let snippet = videoDetail.snippet
                
                // Extract artist and title from video title
                let (title, artist) = extractTitleAndArtist(from: snippet.title)
                
                return Track(
                    id: UUID().uuidString, // Temporary UUID that won't be saved to database
                    title: title,
                    artist: artist,
                    album: nil,
                    duration: duration,
                    artworkURL: snippet.thumbnails.medium?.url ?? snippet.thumbnails.default?.url,
                    previewURL: nil,
                    spotifyURI: nil, // We'll keep this for backward compatibility but use YouTube video ID
                    youtubeVideoId: videoDetail.id, // Store YouTube video ID separately
                    youtubeURL: "https://www.youtube.com/watch?v=\(videoDetail.id)"
                )
            }
            
        } catch {
            if error is YouTubeError {
                throw error
            } else {
                throw YouTubeError.searchFailed
            }
        }
    }
    
    private func extractTitleAndArtist(from videoTitle: String) -> (title: String, artist: String) {
        // Common patterns for YouTube music videos
        let patterns = [
            "(.+?) - (.+)", // "Artist - Title"
            "(.+?) – (.+)", // "Artist – Title" (em dash)
            "(.+?) by (.+)", // "Title by Artist"
            "(.+?) \\| (.+)" // "Artist | Title"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: videoTitle.utf16.count)
                if let match = regex.firstMatch(in: videoTitle, options: [], range: range) {
                    let firstGroup = String(videoTitle[Range(match.range(at: 1), in: videoTitle)!])
                    let secondGroup = String(videoTitle[Range(match.range(at: 2), in: videoTitle)!])
                    
                    // For "Title by Artist" pattern, swap the order
                    if pattern.contains("by") {
                        return (title: firstGroup.trimmingCharacters(in: .whitespacesAndNewlines),
                               artist: secondGroup.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        return (title: secondGroup.trimmingCharacters(in: .whitespacesAndNewlines),
                               artist: firstGroup.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        }
        
        // If no pattern matches, use the full title as both title and artist
        return (title: videoTitle, artist: "Unknown Artist")
    }
    
    private func parseDuration(_ duration: String) -> TimeInterval {
        // Parse ISO 8601 duration format (PT4M13S = 4 minutes 13 seconds)
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return 0
        }
        
        let range = NSRange(location: 0, length: duration.utf16.count)
        guard let match = regex.firstMatch(in: duration, options: [], range: range) else {
            return 0
        }
        
        var totalSeconds: TimeInterval = 0
        
        // Hours
        if match.range(at: 1).location != NSNotFound {
            let hoursString = String(duration[Range(match.range(at: 1), in: duration)!])
            if let hours = Int(hoursString) {
                totalSeconds += TimeInterval(hours * 3600)
            }
        }
        
        // Minutes
        if match.range(at: 2).location != NSNotFound {
            let minutesString = String(duration[Range(match.range(at: 2), in: duration)!])
            if let minutes = Int(minutesString) {
                totalSeconds += TimeInterval(minutes * 60)
            }
        }
        
        // Seconds
        if match.range(at: 3).location != NSNotFound {
            let secondsString = String(duration[Range(match.range(at: 3), in: duration)!])
            if let seconds = Int(secondsString) {
                totalSeconds += TimeInterval(seconds)
            }
        }
        
        return totalSeconds
    }
    
    func createPlaylist(name: String, description: String) async throws -> String {
        // YouTube playlist creation requires OAuth, which we might implement later
        throw YouTubeError.notImplemented
    }
    
    func addToPlaylist(playlistId: String, videoId: String) async throws {
        // YouTube playlist modification requires OAuth, which we might implement later
        throw YouTubeError.notImplemented
    }
}

// MARK: - YouTube API Response Models

struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]
}

struct YouTubeSearchItem: Codable {
    let id: YouTubeVideoId
}

struct YouTubeVideoId: Codable {
    let videoId: String
}

struct YouTubeVideoDetailsResponse: Codable {
    let items: [YouTubeVideoDetail]
}

struct YouTubeVideoDetail: Codable {
    let id: String
    let snippet: YouTubeSnippet
    let contentDetails: YouTubeContentDetails
}

struct YouTubeSnippet: Codable {
    let title: String
    let channelTitle: String
    let thumbnails: YouTubeThumbnails
}

struct YouTubeThumbnails: Codable {
    let `default`: YouTubeThumbnail?
    let medium: YouTubeThumbnail?
    let high: YouTubeThumbnail?
}

struct YouTubeThumbnail: Codable {
    let url: String
    let width: Int?
    let height: Int?
}

struct YouTubeContentDetails: Codable {
    let duration: String
}

// MARK: - YouTube Errors

enum YouTubeError: Error, LocalizedError {
    case notImplemented
    case invalidURL
    case networkError
    case searchFailed
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "YouTube feature not yet implemented"
        case .invalidURL:
            return "Invalid YouTube API URL"
        case .networkError:
            return "YouTube API network error"
        case .searchFailed:
            return "YouTube search failed"
        case .invalidAPIKey:
            return "Invalid YouTube API key"
        }
    }
}
