import Foundation
import SwiftUI

@MainActor
class EventService: ObservableObject {
    @Published var events: [Event] = []
    @Published var publicEvents: [Event] = []
    @Published var userEvents: [Event] = []
    @Published var currentEvent: Event?
    @Published var tracks: [Track] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let supabaseService = SupabaseService.shared
    private let audioPlayer = AudioPlayerService.shared
    
    init() {
        // Listen for notifications that user events need to be refreshed
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserEventsNeedRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.fetchUserEvents()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func fetchPublicEvents() async {
        isLoading = true
        error = nil
        
        do {
            publicEvents = try await supabaseService.fetchPublicEvents()
            events = publicEvents // Update the main events array for compatibility
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func fetchUserEvents() async {
        isLoading = true
        error = nil
        
        do {
            userEvents = try await supabaseService.fetchUserEvents()
            events = userEvents // Update the main events array for compatibility
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createEvent(_ event: Event) async throws {
        try await supabaseService.createEvent(event)
        // Refresh both arrays, but don't update the main events array yet
        let publicEventsTask = Task { try await supabaseService.fetchPublicEvents() }
        let userEventsTask = Task { try await supabaseService.fetchUserEvents() }
        
        do {
            let (fetchedPublicEvents, fetchedUserEvents) = try await (publicEventsTask.value, userEventsTask.value)
            publicEvents = fetchedPublicEvents
            userEvents = fetchedUserEvents
        } catch {
            // If refresh fails, at least try to refresh the current view
            if event.visibility == .public {
                await fetchPublicEvents()
            } else {
                await fetchUserEvents()
            }
        }
    }
    
    func createEvent(name: String, description: String, visibility: EventVisibility, licenseType: LicenseType, locationLat: Double? = nil, locationLng: Double? = nil, locationRadius: Int? = nil, timeStart: Date? = nil, timeEnd: Date? = nil) async {
        guard let userId = supabaseService.currentUser?.id else {
            error = "User not authenticated"
            return
        }

        isLoading = true
        error = nil

        do {
            // TODO: Create Spotify playlist first
            let spotifyPlaylistId = "temp_playlist_id" // Replace with actual Spotify integration

            let event = Event(
                name: name,
                description: description,
                hostId: userId,
                visibility: visibility,
                licenseType: licenseType,
                locationLat: locationLat,
                locationLng: locationLng,
                locationRadius: locationRadius,
                timeStart: timeStart,
                timeEnd: timeEnd,
                spotifyPlaylistId: spotifyPlaylistId
            )

            try await createEvent(event)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
    
    func voteForTrack(eventId: String, trackId: String, voteType: VoteType) async throws {
        try await supabaseService.voteForTrack(eventId: eventId, trackId: trackId, voteType: voteType)
    }
    
    func canUserVote(eventId: String) async throws -> Bool {
        return try await supabaseService.canUserVote(eventId: eventId)
    }
    
    func getUserVotes(eventId: String) async throws -> [String: VoteType] {
        return try await supabaseService.getUserVotes(eventId: eventId)
    }
    
    func fetchEventTracks(eventId: String) async throws -> [Track] {
        return try await supabaseService.fetchEventTracks(eventId: eventId)
    }
    
    private func fetchTracksForEvent(_ eventId: String) async {
        do {
            let fetchedTracks = try await fetchEventTracks(eventId: eventId)
            DispatchQueue.main.async {
                self.tracks = fetchedTracks
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to fetch event tracks: \(error.localizedDescription)"
            }
        }
    }
    
    func addTrackToEvent(eventId: String, track: Track) async throws {
        try await supabaseService.addTrackToEvent(eventId: eventId, track: track)
    }
    
    func joinEvent(eventId: String) async {
        error = nil
        
        do {
            try await supabaseService.joinEvent(eventId: eventId)
            // Subscribe to real-time updates
            subscribeToEventTracks(eventId: eventId)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func subscribeToEventTracks(eventId: String) {
        supabaseService.subscribeToEventTracks(eventId: eventId) { [weak self] updatedTracks in
            self?.tracks = updatedTracks
        }
    }
    
    // MARK: - Audio Player Integration
    
    func playEvent(_ event: Event, startIndex: Int = 0) async {
        do {
            let fetchedTracks = try await fetchEventTracks(eventId: event.id)
            let sortedTracks = fetchedTracks.sorted { $0.position < $1.position }
            
            audioPlayer.playEvent(event.id, tracks: sortedTracks, startIndex: startIndex)
            
            // Update the instance variable for UI consistency
            DispatchQueue.main.async {
                self.tracks = fetchedTracks
            }
        } catch {
            self.error = "Failed to load event tracks: \(error.localizedDescription)"
        }
    }
    
    func playTrackFromEvent(_ track: Track, in event: Event) async {
        print("🎪 EventService: Playing track from event - \(track.title)")
        print("🎪 Track YouTube Video ID: \(track.youtubeVideoId ?? "none")")
        
        do {
            let fetchedTracks = try await fetchEventTracks(eventId: event.id)
            let sortedTracks = fetchedTracks.sorted { $0.position < $1.position }
            let startIndex = sortedTracks.firstIndex { $0.id == track.id } ?? 0
            
            print("🎪 Found \(sortedTracks.count) tracks, starting at index: \(startIndex)")
            
            audioPlayer.playEvent(event.id, tracks: sortedTracks, startIndex: startIndex)
            
            // Update the instance variable for UI consistency
            DispatchQueue.main.async {
                self.tracks = fetchedTracks
            }
        } catch {
            print("🎪 Error playing track from event: \(error)")
            self.error = "Failed to load event tracks: \(error.localizedDescription)"
        }
    }
    
    func addTrackToQueue(_ track: Track) {
        audioPlayer.addToQueue(track)
    }
    
    func playNext(_ track: Track) {
        audioPlayer.insertNext(track)
    }
    
    // MARK: - Track Reordering with Queue Updates
    
    func moveTrack(in eventId: String, from sourceIndex: Int, to destinationIndex: Int) async {
        // Update positions in database
        // ... existing reorder logic ...
        
        // Update audio player queue if this event is currently playing
        if case .event(let currentEventId) = audioPlayer.queueSource,
           currentEventId == eventId {
            do {
                let fetchedTracks = try await fetchEventTracks(eventId: eventId)
                let sortedTracks = fetchedTracks.sorted { $0.position < $1.position }
                audioPlayer.updateQueueFromEvent(sortedTracks)
                
                // Update the instance variable for UI consistency
                DispatchQueue.main.async {
                    self.tracks = fetchedTracks
                }
            } catch {
                print("🎪 Error updating queue after track move: \(error)")
            }
        }
    }
}
