import Foundation
import SwiftUI

struct Podcast: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let description: String
    let imageURL: String
    let backgroundColor: Color
    let category: String
    let duration: String
    let isPlaying: Bool
    
    init(title: String, author: String, description: String, imageURL: String, backgroundColor: Color, category: String, duration: String, isPlaying: Bool = false) {
        self.title = title
        self.author = author
        self.description = description
        self.imageURL = imageURL
        self.backgroundColor = backgroundColor
        self.category = category
        self.duration = duration
        self.isPlaying = isPlaying
    }
}

struct PodcastEpisode: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let duration: String
    let currentTime: String
    let imageURL: String
    let backgroundColor: Color
    let isRecentlyPlayed: Bool
    let playProgress: Double
    
    init(title: String, author: String, duration: String, currentTime: String, imageURL: String, backgroundColor: Color, isRecentlyPlayed: Bool = false, playProgress: Double = 0.0) {
        self.title = title
        self.author = author
        self.duration = duration
        self.currentTime = currentTime
        self.imageURL = imageURL
        self.backgroundColor = backgroundColor
        self.isRecentlyPlayed = isRecentlyPlayed
        self.playProgress = playProgress
    }
}

struct Playlist: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let imageURL: String
    let backgroundColor: Color
    let episodeCount: Int
    
    init(name: String, description: String, imageURL: String, backgroundColor: Color, episodeCount: Int) {
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.backgroundColor = backgroundColor
        self.episodeCount = episodeCount
    }
} 