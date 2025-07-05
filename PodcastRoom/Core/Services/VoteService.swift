import Foundation
import SwiftUI

@MainActor
class VoteService: ObservableObject {
    @Published var trackVotes: [String: Int] = [:] // trackId -> vote count
    @Published var userVotes: [String: VoteType] = [:] // trackId -> user's vote
    @Published var isLoading = false
    @Published var error: String?
    
    private let supabaseService = SupabaseService.shared
    private var pollingTask: Task<Void, Never>?
    
    // MARK: - Voting Actions
    
    func voteForTrack(eventId: String, trackId: String, voteType: VoteType) async {
        isLoading = true
        error = nil
        
        // Store previous state for potential rollback
        let originalVote = userVotes[trackId]
        let originalCount = trackVotes[trackId] ?? 0
        
        // Optimistically update local state
        userVotes[trackId] = voteType
        updateLocalVoteCount(trackId: trackId, previousVote: originalVote, newVote: voteType)
        
        do {
            // Send vote to server
            try await supabaseService.voteForTrack(eventId: eventId, trackId: trackId, voteType: voteType)
            
            // Add a longer delay to allow the database trigger and vote count update to complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Refresh vote counts from server (this is the single source of truth)
            await loadVoteCounts(eventId: eventId)
            
        } catch {
            print("❌ Vote failed: \(error.localizedDescription)")
            
            // Revert optimistic changes on error
            if let originalVote = originalVote {
                userVotes[trackId] = originalVote
            } else {
                userVotes.removeValue(forKey: trackId)
            }
            trackVotes[trackId] = originalCount
            
            self.error = "There was an issue casting your vote. Please try again."
        }
        
        isLoading = false
    }
    
    func removeVote(eventId: String, trackId: String) async {
        guard let currentVote = userVotes[trackId] else { return }
        
        isLoading = true
        error = nil
        
        let originalCount = trackVotes[trackId] ?? 0
        
        do {
            // Optimistically remove vote
            userVotes.removeValue(forKey: trackId)
            updateLocalVoteCount(trackId: trackId, previousVote: currentVote, newVote: nil)
            
            // Remove vote from server
            try await removeVoteFromServer(eventId: eventId, trackId: trackId)
            
            // Refresh vote counts
            await loadVoteCounts(eventId: eventId)
            
        } catch {
            // Revert on error
            userVotes[trackId] = currentVote
            trackVotes[trackId] = originalCount
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Data Loading
    
    func loadVoteCounts(eventId: String) async {
        do {
            let tracks = try await supabaseService.fetchEventTracks(eventId: eventId)
            
            var newVoteCounts: [String: Int] = [:]
            for track in tracks {
                newVoteCounts[track.id] = track.votes
            }
            
            // Update vote counts and log any discrepancies for debugging
            for (trackId, serverCount) in newVoteCounts {
                if let localCount = trackVotes[trackId], localCount != serverCount {
                    print("🔄 Vote count sync: Track \(trackId) - Local: \(localCount), Server: \(serverCount)")
                }
            }
            
            trackVotes = newVoteCounts
            
        } catch {
            print("❌ Failed to load vote counts: \(error)")
            self.error = error.localizedDescription
        }
    }
    
    func loadUserVotes(eventId: String) async {
        do {
            let votes = try await supabaseService.getUserVotes(eventId: eventId)
            userVotes = votes
        } catch {
            print("❌ Failed to load user votes: \(error)")
            self.error = error.localizedDescription
        }
    }
    
    func loadAllVoteData(eventId: String) async {
        await loadVoteCounts(eventId: eventId)
        await loadUserVotes(eventId: eventId)
    }
    
    /// Force refresh all vote data, useful when inconsistencies are detected
    func forceRefreshVoteData(eventId: String) async {
        print("🔄 Force refreshing vote data for event: \(eventId)")
        await loadAllVoteData(eventId: eventId)
    }
    
    // MARK: - Real-time Updates
    
    func subscribeToVoteUpdates(eventId: String) {
        // Cancel any existing polling task
        unsubscribeFromVoteUpdates()
        
        // Start polling for vote updates every 2 seconds for more responsive updates
        pollingTask = Task {
            while !Task.isCancelled {
                await loadVoteCounts(eventId: eventId)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
    
    func unsubscribeFromVoteUpdates() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    // MARK: - Helper Methods
    
    private func removeVoteFromServer(eventId: String, trackId: String) async throws {
        guard let currentUser = supabaseService.currentUser else {
            throw SupabaseError.notAuthenticated
        }
        
        // Delete the vote from the database
        try await supabaseService.client
            .from("votes")
            .delete()
            .eq("event_id", value: eventId)
            .eq("track_id", value: trackId)
            .eq("user_id", value: currentUser.id)
            .execute()
        
        // Update track vote count
        try await supabaseService.updateTrackVoteCount(trackId: trackId, eventId: eventId)
    }
    
    private func updateLocalVoteCount(trackId: String, previousVote: VoteType?, newVote: VoteType?) {
        let currentCount = trackVotes[trackId] ?? 0
        var newCount = currentCount
        
        print("🔢 Vote count update - Track: \(trackId), Current: \(currentCount), Previous: \(previousVote?.rawValue ?? "none"), New: \(newVote?.rawValue ?? "none")")
        
        // Remove previous vote effect
        if let previousVote = previousVote {
            switch previousVote {
            case .up:
                newCount -= 1
            case .down:
                newCount += 1
            }
        }
        
        // Add new vote effect
        if let newVote = newVote {
            switch newVote {
            case .up:
                newCount += 1
            case .down:
                newCount -= 1
            }
        }
        
        let finalCount = max(0, newCount) // Ensure non-negative
        trackVotes[trackId] = finalCount
        
        print("🔢 Vote count result - Track: \(trackId), Final: \(finalCount)")
    }
    
    // MARK: - Track Reordering
    
    func reorderTracks(_ tracks: [Track]) -> [Track] {
        return tracks.sorted { track1, track2 in
            let votes1 = trackVotes[track1.id] ?? track1.votes
            let votes2 = trackVotes[track2.id] ?? track2.votes
            
            // Sort by votes (descending), then by added date (ascending)
            if votes1 != votes2 {
                return votes1 > votes2
            } else {
                return track1.addedAt < track2.addedAt
            }
        }
    }
    
    func getVoteCount(for trackId: String, fallback: Int = 0) -> Int {
        return trackVotes[trackId] ?? fallback
    }
    
    func getUserVote(for trackId: String) -> VoteType? {
        return userVotes[trackId]
    }
    
    // Clean up when service is deinitialized
    deinit {
        pollingTask?.cancel()
    }
}


