import Foundation
import SwiftUI
import Combine
import AVFoundation

enum PlaybackState: Equatable {
    case stopped
    case loading
    case playing
    case paused
    case buffering
    case error(String)
}

enum RepeatMode: CaseIterable {
    case off
    case one
    case all
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .one: return "Repeat One"
        case .all: return "Repeat All"
        }
    }
}

class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    
    // MARK: - Published Properties
    @Published var currentTrack: Track?
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isShuffled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var volume: Float = 1.0
    
    // Queue Management
    @Published var currentQueue: [Track] = []
    @Published var originalQueue: [Track] = [] // For shuffle/unshuffle
    @Published var currentIndex: Int = 0
    @Published var queueSource: QueueSource = .none
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    
    enum QueueSource: Equatable {
        case none
        case playlist(String) // playlist ID
        case event(String) // event ID
    }
    
    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Queue Management
    func setQueue(_ tracks: [Track], startIndex: Int = 0, source: QueueSource = .none) {
        currentQueue = tracks
        originalQueue = tracks
        currentIndex = max(0, min(startIndex, tracks.count - 1))
        queueSource = source
        
        if !tracks.isEmpty {
            currentTrack = tracks[currentIndex]
        }
    }
    
    func addToQueue(_ track: Track) {
        currentQueue.append(track)
        originalQueue.append(track)
    }
    
    func insertNext(_ track: Track) {
        let insertIndex = currentIndex + 1
        if insertIndex < currentQueue.count {
            currentQueue.insert(track, at: insertIndex)
            originalQueue.insert(track, at: insertIndex)
        } else {
            addToQueue(track)
        }
    }
    
    func removeFromQueue(at index: Int) {
        guard index < currentQueue.count else { return }
        
        currentQueue.remove(at: index)
        originalQueue.removeAll { $0.id == currentQueue[index].id }
        
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex && currentIndex >= currentQueue.count {
            currentIndex = max(0, currentQueue.count - 1)
            if !currentQueue.isEmpty {
                currentTrack = currentQueue[currentIndex]
            }
        }
    }
    
    func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < currentQueue.count && destinationIndex < currentQueue.count else { return }
        
        let movedTrack = currentQueue.remove(at: sourceIndex)
        currentQueue.insert(movedTrack, at: destinationIndex)
        
        // Update original queue to match
        originalQueue = currentQueue
        
        // Update current index if needed
        if sourceIndex == currentIndex {
            currentIndex = destinationIndex
        } else if sourceIndex < currentIndex && destinationIndex >= currentIndex {
            currentIndex -= 1
        } else if sourceIndex > currentIndex && destinationIndex <= currentIndex {
            currentIndex += 1
        }
        
        // Update current track if index changed
        if currentIndex < currentQueue.count {
            currentTrack = currentQueue[currentIndex]
        }
    }
    
    func shuffleQueue() {
        guard !currentQueue.isEmpty else { return }
        
        if isShuffled {
            // Unshuffle - restore original order
            currentQueue = originalQueue
            if let currentTrack = currentTrack {
                currentIndex = currentQueue.firstIndex { $0.id == currentTrack.id } ?? 0
            }
        } else {
            // Shuffle
            let _ = currentTrack?.id
            var shuffledQueue = currentQueue
            
            // Remove current track from shuffle
            if let currentTrack = currentTrack {
                shuffledQueue.removeAll { $0.id == currentTrack.id }
            }
            
            shuffledQueue.shuffle()
            
            // Insert current track at beginning
            if let currentTrack = currentTrack {
                shuffledQueue.insert(currentTrack, at: 0)
            }
            
            currentQueue = shuffledQueue
            currentIndex = 0
        }
        
        isShuffled.toggle()
    }
    
    // MARK: - Playback Controls
    func play() {
        print("📱 AudioPlayerService: Play requested - current state: \(playbackState)")
        guard let track = currentTrack else { 
            print("📱 AudioPlayerService: No current track to play")
            return 
        }
        
        // If we have a current track and we're paused/stopped, just resume playback
        if playbackState == .paused || playbackState == .stopped {
            print("📱 AudioPlayerService: Resuming playback of current track: \(track.title)")
            playbackState = .playing
        } else {
            print("📱 AudioPlayerService: Starting fresh playback of track: \(track.title)")
            playTrack(track)
        }
    }
    
    func pause() {
        print("📱 AudioPlayerService: Pause requested - current state: \(playbackState)")
        playbackState = .paused
        print("📱 AudioPlayerService: State changed to paused")
        // YouTube player pause will be handled in the UI component
    }
    
    func stop() {
        playbackState = .stopped
        currentTime = 0
        // YouTube player stop will be handled in the UI component
    }
    
    func playTrack(_ track: Track) {
        print("📱 AudioPlayerService: Playing track - \(track.title) by \(track.artist)")
        print("📱 YouTube Video ID: \(track.youtubeVideoId ?? "none")")
        print("📱 YouTube URL: \(track.youtubeURL ?? "none")")
        
        currentTrack = track
        playbackState = .loading
        
        // Find track in queue and update index
        if let index = currentQueue.firstIndex(where: { $0.id == track.id }) {
            currentIndex = index
            print("📱 Updated current index to: \(index)")
        }
        
        // The actual playback will be handled by YouTubePlayerView
        // This service manages the state and queue
        updateNowPlayingInfo()
    }
    
    func playNext() {
        guard !currentQueue.isEmpty else { return }
        
        switch repeatMode {
        case .one:
            // Replay current track
            if let track = currentTrack {
                playTrack(track)
            }
            return
        case .off:
            if currentIndex < currentQueue.count - 1 {
                currentIndex += 1
            } else {
                // End of queue
                stop()
                return
            }
        case .all:
            currentIndex = (currentIndex + 1) % currentQueue.count
        }
        
        currentTrack = currentQueue[currentIndex]
        playTrack(currentQueue[currentIndex])
    }
    
    func playPrevious() {
        guard !currentQueue.isEmpty else { return }
        
        if currentTime > 3.0 {
            // If more than 3 seconds played, restart current track
            if let track = currentTrack {
                playTrack(track)
            }
            return
        }
        
        switch repeatMode {
        case .one:
            // Replay current track
            if let track = currentTrack {
                playTrack(track)
            }
            return
        case .off:
            if currentIndex > 0 {
                currentIndex -= 1
            } else {
                // Beginning of queue, restart current track
                if let track = currentTrack {
                    playTrack(track)
                }
                return
            }
        case .all:
            currentIndex = currentIndex > 0 ? currentIndex - 1 : currentQueue.count - 1
        }
        
        currentTrack = currentQueue[currentIndex]
        playTrack(currentQueue[currentIndex])
    }
    
    func seek(to time: TimeInterval) {
        currentTime = time
        // Notify YouTube player to seek
        NotificationCenter.default.post(
            name: Notification.Name("SeekToTime"), 
            object: nil, 
            userInfo: ["time": time]
        )
    }
    
    // MARK: - Remote Command Center
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - Now Playing Info
    func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album ?? ""
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = track.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackState == .playing ? 1.0 : 0.0
        
        // Load artwork if available
        if let artworkURL = track.artworkURL, let url = URL(string: artworkURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    DispatchQueue.main.async {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    }
                }
            }.resume()
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Playlist Integration
    func playPlaylist(_ playlistId: String, tracks: [Track], startIndex: Int = 0) {
        print("📱 AudioPlayerService: Playing playlist \(playlistId) with \(tracks.count) tracks, starting at index \(startIndex)")
        
        setQueue(tracks, startIndex: startIndex, source: .playlist(playlistId))
        if !tracks.isEmpty {
            let trackToPlay = tracks[currentIndex]
            print("📱 About to play track: \(trackToPlay.title) (YouTube ID: \(trackToPlay.youtubeVideoId ?? "none"))")
            playTrack(trackToPlay)
        } else {
            print("📱 No tracks to play!")
        }
    }
    
    func playEvent(_ eventId: String, tracks: [Track], startIndex: Int = 0) {
        print("📱 AudioPlayerService: Playing event \(eventId) with \(tracks.count) tracks, starting at index \(startIndex)")
        
        setQueue(tracks, startIndex: startIndex, source: .event(eventId))
        if !tracks.isEmpty {
            let trackToPlay = tracks[currentIndex]
            print("📱 About to play track: \(trackToPlay.title) (YouTube ID: \(trackToPlay.youtubeVideoId ?? "none"))")
            playTrack(trackToPlay)
        } else {
            print("📱 No tracks to play!")
        }
    }
    
    // MARK: - Queue Updates from External Sources
    func updateQueueFromPlaylist(_ tracks: [Track]) {
        guard case .playlist = queueSource else { return }
        
        let currentTrackId = currentTrack?.id
        currentQueue = tracks
        originalQueue = tracks
        
        // Try to maintain current track position
        if let trackId = currentTrackId,
           let newIndex = tracks.firstIndex(where: { $0.id == trackId }) {
            currentIndex = newIndex
            currentTrack = tracks[newIndex]
        } else if currentIndex >= tracks.count {
            currentIndex = max(0, tracks.count - 1)
            currentTrack = tracks.isEmpty ? nil : tracks[currentIndex]
        }
    }
    
    func updateQueueFromEvent(_ tracks: [Track]) {
        guard case .event = queueSource else { return }
        
        let currentTrackId = currentTrack?.id
        currentQueue = tracks
        originalQueue = tracks
        
        // Try to maintain current track position
        if let trackId = currentTrackId,
           let newIndex = tracks.firstIndex(where: { $0.id == trackId }) {
            currentIndex = newIndex
            currentTrack = tracks[newIndex]
        } else if currentIndex >= tracks.count {
            currentIndex = max(0, tracks.count - 1)
            currentTrack = tracks.isEmpty ? nil : tracks[currentIndex]
        }
    }
}

// MARK: - Remote Command Center Import
import MediaPlayer
