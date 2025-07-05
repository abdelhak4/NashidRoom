import Foundation
import Combine

class PlaylistService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    private let audioPlayer = AudioPlayerService.shared
    
    @Published var playlists: [CollaborativePlaylist] = []
    @Published var currentPlaylist: CollaborativePlaylist?
    @Published var playlistTracks: [PlaylistTrack] = []
    @Published var playlistInvitations: [PlaylistInvitation] = []
    @Published var acceptedInvitations: [PlaylistInvitation] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var currentFetchTask: Task<Void, Never>?
    private var currentTracksTask: Task<Void, Never>?
    private var currentInvitationsTask: Task<Void, Never>?
    private var lastFetchTime: Date?
    private let minFetchInterval: TimeInterval = 1.0 // Minimum 1 second between fetches
    
    // MARK: - Playlist CRUD Operations
    
    func createPlaylist(
        name: String,
        description: String = "",
        visibility: PlaylistVisibility = .public,
        editorLicenseType: PlaylistLicenseType = .everyone
    ) async throws -> CollaborativePlaylist {
        guard let currentUser = supabaseService.currentUser else {
            throw NSError(domain: "PlaylistService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let playlist = CollaborativePlaylist(
            name: name,
            description: description,
            creatorId: currentUser.id,
            visibility: visibility,
            editorLicenseType: editorLicenseType
        )
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let response = try await supabaseService.client
                .from("playlists")
                .insert(playlist)
                .select()
                .execute()
            
            // Supabase insert with select should return the created record
            let data = response.data
            
            let playlistData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            
            if let createdPlaylistDict = playlistData.first {
                let createdPlaylist = try CollaborativePlaylist.from(dictionary: createdPlaylistDict)
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.playlists.append(createdPlaylist)
                }
                
                return createdPlaylist
            } else {
                // Fallback if no data returned
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.playlists.append(playlist)
                }
                return playlist
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Failed to create playlist: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func fetchPlaylists(force: Bool = false) async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        // Debounce mechanism to prevent too frequent calls
        let now = Date()
        if !force, let lastFetch = lastFetchTime, now.timeIntervalSince(lastFetch) < minFetchInterval {
            print("DEBUG: Skipping fetch due to debounce (last fetch was \(now.timeIntervalSince(lastFetch))s ago)")
            return
        }
        
        // Cancel any existing fetch task
        currentFetchTask?.cancel()
        
        // Create a new task
        currentFetchTask = Task {
            // Record fetch time
            self.lastFetchTime = now
            
            // Set loading state
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }
            
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // This query should match the RLS policy logic:
                // 1. Public playlists (visibility = 'public')
                // 2. User's own playlists (creator_id = current_user_id) 
                // 3. Private playlists where user has accepted invitation
                // Note: The RLS policy should handle the invitation check automatically
                let response = try await supabaseService.client
                    .from("playlists")
                    .select("*")
                    .eq("is_active", value: true)
                    .order("updated_at", ascending: false)
                    .execute()
                
                // Check if task was cancelled after network request
                try Task.checkCancellation()
                
                let data = response.data
                let playlistsData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                let fetchedPlaylists = try playlistsData.compactMap { try CollaborativePlaylist.from(dictionary: $0) }
                
                print("DEBUG: Fetched \(fetchedPlaylists.count) playlists for user \(currentUser.id)")
                for playlist in fetchedPlaylists {
                    print("  - \(playlist.name) (id: \(playlist.id), visibility: \(playlist.visibility), creator: \(playlist.creatorId))")
                }
                
                // Also fetch accepted invitations to keep permissions cache up to date
                let _ = await fetchAcceptedInvitations()
                
                // Final cancellation check before updating UI
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.playlists = fetchedPlaylists
                    self.isLoading = false
                }
            } catch is CancellationError {
                // Task was cancelled, don't update UI state
                print("DEBUG: Playlist fetch was cancelled")
            } catch {
                print("Error fetching playlists: \(error)")
                
                // Handle URLSession cancellation error specifically
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    print("DEBUG: Network request was cancelled")
                    // Don't show error to user for cancelled requests
                    await MainActor.run {
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.error = "Failed to fetch playlists: \(error.localizedDescription)"
                    }
                }
            }
        }
        
        await currentFetchTask?.value
    }
    
    func updatePlaylist(_ playlist: CollaborativePlaylist) async throws {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            var updatedPlaylist = playlist
            updatedPlaylist.updatedAt = Date()
            
            try await supabaseService.client
                .from("playlists")
                .update(updatedPlaylist)
                .eq("id", value: playlist.id)
                .execute()
            
            DispatchQueue.main.async {
                self.isLoading = false
                if let index = self.playlists.firstIndex(where: { $0.id == playlist.id }) {
                    self.playlists[index] = updatedPlaylist
                }
                if self.currentPlaylist?.id == playlist.id {
                    self.currentPlaylist = updatedPlaylist
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Failed to update playlist: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func deletePlaylist(_ playlist: CollaborativePlaylist) async throws {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // Soft delete by setting is_active to false
            struct UpdateData: Codable {
                let is_active: Bool
                let updated_at: String
            }
            let updateData = UpdateData(
                is_active: false,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            try await supabaseService.client
                .from("playlists")
                .update(updateData)
                .eq("id", value: playlist.id)
                .execute()
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.playlists.removeAll { $0.id == playlist.id }
                if self.currentPlaylist?.id == playlist.id {
                    self.currentPlaylist = nil
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Failed to delete playlist: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    // MARK: - Playlist Track Operations
    
    func addTrackToPlaylist(playlistId: String, track: Track) async throws {
        guard let currentUser = supabaseService.currentUser else {
            throw NSError(domain: "PlaylistService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get current max position
        let maxPosition = playlistTracks.max(by: { $0.position < $1.position })?.position ?? -1
        
        print("🎵 Adding track to playlist:")
        print("   - Track ID: \(track.id)")
        print("   - Track Title: \(track.title)")
        print("   - YouTube Video ID: \(track.youtubeVideoId ?? "none")")
        print("   - YouTube URL: \(track.youtubeURL ?? "none")")
        print("   - Will use as trackId: \(track.youtubeVideoId ?? track.id)")
        
        let playlistTrack = PlaylistTrack(
            playlistId: playlistId,
            trackId: track.youtubeVideoId ?? track.id,
            addedBy: currentUser.id,
            position: maxPosition + 1,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: Int(track.duration * 1000), // Convert to milliseconds
            imageUrl: track.artworkURL,
            youtubeUrl: track.youtubeURL
        )
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            try await supabaseService.client
                .from("playlist_tracks")
                .insert(playlistTrack)
                .execute()
            
            // Update playlist track count
            if let playlist = playlists.first(where: { $0.id == playlistId }) {
                var updatedPlaylist = playlist
                updatedPlaylist.trackCount += 1
                updatedPlaylist.updatedAt = Date()
                try await updatePlaylist(updatedPlaylist)
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.playlistTracks.append(playlistTrack)
                self.playlistTracks.sort { $0.position < $1.position }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Failed to add track: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func removeTrackFromPlaylist(_ playlistTrack: PlaylistTrack) async throws {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            try await supabaseService.client
                .from("playlist_tracks")
                .delete()
                .eq("id", value: playlistTrack.id)
                .execute()
            
            // Update playlist track count
            if let playlist = playlists.first(where: { $0.id == playlistTrack.playlistId }) {
                var updatedPlaylist = playlist
                updatedPlaylist.trackCount = max(0, updatedPlaylist.trackCount - 1)
                updatedPlaylist.updatedAt = Date()
                try await updatePlaylist(updatedPlaylist)
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.playlistTracks.removeAll { $0.id == playlistTrack.id }
                // Reorder remaining tracks
                self.reorderTracksLocally()
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Failed to remove track: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    private func reorderTracksLocally() {
        playlistTracks = playlistTracks.enumerated().map { index, track in
            var updatedTrack = track
            updatedTrack.position = index
            return updatedTrack
        }
    }
    
    func fetchPlaylistTracks(playlistId: String) async {
        // Cancel any existing tracks fetch task
        currentTracksTask?.cancel()
        
        // Create a new task
        currentTracksTask = Task {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }
            
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                let response = try await supabaseService.client
                    .from("playlist_tracks")
                    .select("*")
                    .eq("playlist_id", value: playlistId)
                    .order("position", ascending: true)
                    .execute()
                
                // Check if task was cancelled after network request
                try Task.checkCancellation()
                
                let data = response.data
                let tracksData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                let fetchedTracks = try tracksData.compactMap { try PlaylistTrack.from(dictionary: $0) }
                
                // Final cancellation check before updating UI
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.playlistTracks = fetchedTracks
                    self.isLoading = false
                }
            } catch is CancellationError {
                // Task was cancelled, don't update UI state
                print("DEBUG: Playlist tracks fetch was cancelled")
            } catch {
                // Handle URLSession cancellation error specifically
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    print("DEBUG: Network request was cancelled")
                    // Don't show error to user for cancelled requests
                    await MainActor.run {
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.error = "Failed to fetch playlist tracks: \(error.localizedDescription)"
                    }
                }
            }
        }
        
        await currentTracksTask?.value
    }
    
    func reorderTracks(_ tracks: [PlaylistTrack]) async throws {
        let updatedTracks = tracks.enumerated().map { index, track in
            var updatedTrack = track
            updatedTrack.position = index
            return updatedTrack
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // To avoid duplicate key violations when reordering, we use a two-step approach:
            // 1. First, set all positions to negative values (temporary positions)
            // 2. Then, update to the final positions
            
            struct PositionUpdate: Codable {
                let position: Int
            }
            
            // Step 1: Set all tracks to temporary negative positions
            for (index, track) in updatedTracks.enumerated() {
                let tempPosition = -(index + 1000) // Use negative positions starting from -1000
                try await supabaseService.client
                    .from("playlist_tracks")
                    .update(PositionUpdate(position: tempPosition))
                    .eq("id", value: track.id)
                    .execute()
            }
            
            // Step 2: Update to final positions
            for track in updatedTracks {
                try await supabaseService.client
                    .from("playlist_tracks")
                    .update(PositionUpdate(position: track.position))
                    .eq("id", value: track.id)
                    .execute()
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.playlistTracks = updatedTracks.sorted { $0.position < $1.position }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Failed to reorder tracks: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    func getPlaylistTracks(playlistId: String) async throws -> [PlaylistTrack] {
        let response = try await supabaseService.client
            .from("playlist_tracks")
            .select("*")
            .eq("playlist_id", value: playlistId)
            .order("position", ascending: true)
            .execute()
        
        let data = response.data
        let tracksData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return try tracksData.compactMap { try PlaylistTrack.from(dictionary: $0) }
    }
    
    // MARK: - Invitation Management
    
    func inviteUserToPlaylist(playlistId: String, userEmail: String, role: PlaylistRole = .collaborator) async throws {
        guard let currentUser = supabaseService.currentUser else {
            throw NSError(domain: "PlaylistService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if user is trying to invite themselves
        if userEmail.lowercased() == currentUser.email.lowercased() {
            throw NSError(domain: "PlaylistService", code: 400, userInfo: [NSLocalizedDescriptionKey: "You cannot invite yourself to a playlist"])
        }
        
        // First, find the user by email
        do {
            let userResponse = try await supabaseService.client
                .from("users")
                .select("id")
                .eq("email", value: userEmail)
                .single()
                .execute()
            
            let userData = userResponse.data
            let userDict = try JSONSerialization.jsonObject(with: userData) as? [String: Any]
            
            // Handle both UUID string and direct string cases
            var inviteeId: String?
            if let uuidString = userDict?["id"] as? String {
                inviteeId = uuidString
            } else if let uuid = userDict?["id"] as? UUID {
                inviteeId = uuid.uuidString
            }
            
            guard let validInviteeId = inviteeId else {
                throw NSError(domain: "PlaylistService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
            }
            
            // Check if user is already invited (pending invitation exists)
            let existingInvitationResponse = try await supabaseService.client
                .from("playlist_invitations")
                .select("id")
                .eq("playlist_id", value: playlistId)
                .eq("invitee_id", value: validInviteeId)
                .eq("status", value: "pending")
                .execute()
            
            let existingData = existingInvitationResponse.data
            let existingInvitations = try JSONSerialization.jsonObject(with: existingData) as? [[String: Any]] ?? []
            
            if !existingInvitations.isEmpty {
                throw NSError(domain: "PlaylistService", code: 409, userInfo: [NSLocalizedDescriptionKey: "User already has a pending invitation for this playlist"])
            }
            
            // Check if user already has access (accepted invitation exists)
            let accessCheckResponse = try await supabaseService.client
                .from("playlist_invitations")
                .select("id")
                .eq("playlist_id", value: playlistId)
                .eq("invitee_id", value: validInviteeId)
                .eq("status", value: "accepted")
                .execute()
            
            let accessData = accessCheckResponse.data
            let acceptedInvitations = try JSONSerialization.jsonObject(with: accessData) as? [[String: Any]] ?? []
            
            if !acceptedInvitations.isEmpty {
                throw NSError(domain: "PlaylistService", code: 409, userInfo: [NSLocalizedDescriptionKey: "User already has access to this playlist"])
            }
            
            let invitation = PlaylistInvitation(
                playlistId: playlistId,
                inviterId: currentUser.id,
                inviteeId: validInviteeId,
                role: role
            )
            
            try await supabaseService.client
                .from("playlist_invitations")
                .insert(invitation)
                .execute()
            
            // Don't add to local array since this is a sent invitation, not a received one
            // The playlistInvitations array should only contain invitations for the current user
        } catch {
            throw NSError(domain: "PlaylistService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to send invitation: \(error.localizedDescription)"])
        }
    }
    
    func respondToPlaylistInvitation(_ invitation: PlaylistInvitation, accept: Bool) async throws {
        guard let currentUser = supabaseService.currentUser else {
            throw NSError(domain: "PlaylistService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let newStatus = accept ? "accepted" : "declined"
        
        // Create a struct that conforms to Codable for the update
        struct InvitationUpdate: Codable {
            let status: String
            let updated_at: String
        }
        
        let updateData = InvitationUpdate(
            status: newStatus,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        print("Responding to invitation: \(invitation.id) with status: \(newStatus)")
        
        do {
            let response = try await supabaseService.client
                .from("playlist_invitations")
                .update(updateData)
                .eq("id", value: invitation.id)
                .execute()
            
            print("Invitation update response: \(response)")
            
            DispatchQueue.main.async {
                // Update the invitation status in the list instead of removing it
                if let index = self.playlistInvitations.firstIndex(where: { $0.id == invitation.id }) {
                    self.playlistInvitations[index].status = accept ? .accepted : .declined
                    self.playlistInvitations[index].updatedAt = Date()
                }
                self.error = nil // Clear any previous errors
            }
            
            // If accepted, refresh playlists to show the newly accessible playlist
            if accept {
                print("Invitation accepted - refreshing playlists and permissions...")
                
                // Add a small delay to ensure the database transaction is committed
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Refresh playlists to show the newly accessible playlist
                await self.fetchPlaylists()
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to respond to invitation: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func fetchPlaylistInvitations() async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        // Cancel any existing invitations fetch task
        currentInvitationsTask?.cancel()
        
        // Create a new task
        currentInvitationsTask = Task {
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Fetch ALL playlist invitations (not just pending ones) - similar to event invitations
                let response = try await supabaseService.client
                    .from("playlist_invitations")
                    .select("*")
                    .eq("invitee_id", value: currentUser.id)
                    .order("created_at", ascending: false)
                    .execute()
                
                // Check if task was cancelled after network request
                try Task.checkCancellation()
                
                let data = response.data
                let invitationsData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                var fetchedInvitations = try invitationsData.compactMap { try PlaylistInvitation.from(dictionary: $0) }
                
                // Enhance invitations with playlist and inviter names
                for i in fetchedInvitations.indices {
                    let invitation = fetchedInvitations[i]
                    
                    // Fetch playlist name
                    do {
                        let playlistResponse = try await supabaseService.client
                            .from("playlists")
                            .select("name")
                            .eq("id", value: invitation.playlistId)
                            .execute()
                        
                        let playlistData = playlistResponse.data
                        let playlistJson = try JSONSerialization.jsonObject(with: playlistData) as? [[String: Any]] ?? []
                        if let playlistDict = playlistJson.first,
                           let playlistName = playlistDict["name"] as? String {
                            fetchedInvitations[i].playlistName = playlistName
                        }
                    } catch {
                        print("Failed to fetch playlist name for invitation \(invitation.id): \(error)")
                    }
                    
                    // Fetch inviter name
                    do {
                        let inviterResponse = try await supabaseService.client
                            .from("users")
                            .select("username, display_name")
                            .eq("id", value: invitation.inviterId)
                            .execute()
                        
                        let inviterData = inviterResponse.data
                        let inviterJson = try JSONSerialization.jsonObject(with: inviterData) as? [[String: Any]] ?? []
                        if let inviterDict = inviterJson.first {
                            let displayName = inviterDict["display_name"] as? String
                            let username = inviterDict["username"] as? String
                            fetchedInvitations[i].inviterName = displayName ?? username
                        }
                    } catch {
                        print("Failed to fetch inviter name for invitation \(invitation.id): \(error)")
                    }
                }
                
                // Final cancellation check before updating UI
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.playlistInvitations = fetchedInvitations
                }
            } catch is CancellationError {
                // Task was cancelled, don't update UI state
                print("DEBUG: Playlist invitations fetch was cancelled")
            } catch {
                // Handle URLSession cancellation error specifically
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    print("DEBUG: Network request was cancelled")
                    // Don't show error to user for cancelled requests
                } else {
                    await MainActor.run {
                        self.error = "Failed to fetch invitations: \(error.localizedDescription)"
                    }
                }
            }
        }
        
        await currentInvitationsTask?.value
    }
    
    func fetchAcceptedInvitations() async -> [PlaylistInvitation] {
        guard let currentUser = supabaseService.currentUser else { return [] }
        
        do {
            let response = try await supabaseService.client
                .from("playlist_invitations")
                .select("*")
                .eq("invitee_id", value: currentUser.id)
                .eq("status", value: "accepted")
                .order("created_at", ascending: false)
                .execute()
            
            let data = response.data
            let invitationsData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            let acceptedInvitations = try invitationsData.compactMap { try PlaylistInvitation.from(dictionary: $0) }
            
            // Update local cache
            DispatchQueue.main.async {
                self.acceptedInvitations = acceptedInvitations
            }
            
            return acceptedInvitations
        } catch {
            print("Failed to fetch accepted invitations: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Permission Checks
    func canEditPlaylist(_ playlist: CollaborativePlaylist) async -> Bool {
        guard let currentUser = supabaseService.currentUser else { return false }
        
        // Creator can always edit
        if playlist.creatorId == currentUser.id {
            return true
        }
        
        // Check license type
        switch playlist.editorLicenseType {
        case .everyone:
            return playlist.visibility == .public
        case .invitedOnly:
            // Check if user has accepted invitation with collaborator role
            let acceptedInvitations = await fetchAcceptedInvitations()
            return acceptedInvitations.contains { invitation in
                invitation.playlistId == playlist.id &&
                invitation.inviteeId == currentUser.id &&
                invitation.status == .accepted &&
                invitation.role.canEdit
            }
        }
    }
    
    func canAccessPlaylist(_ playlist: CollaborativePlaylist) async -> Bool {
        guard let currentUser = supabaseService.currentUser else { return false }
        
        // Creator can always access
        if playlist.creatorId == currentUser.id {
            return true
        }
        
        // Public playlists are accessible to everyone
        if playlist.visibility == .public {
            return true
        }
        
        // Private playlists require invitation
        let acceptedInvitations = await fetchAcceptedInvitations()
        return acceptedInvitations.contains { invitation in
            invitation.playlistId == playlist.id &&
            invitation.inviteeId == currentUser.id &&
            invitation.status == .accepted
        }
    }
    
    // Synchronous versions for UI binding (these should rely on RLS instead)
    func canEditPlaylist(_ playlist: CollaborativePlaylist) -> Bool {
        guard let currentUser = supabaseService.currentUser else { return false }
        
        // Creator can always edit
        if playlist.creatorId == currentUser.id {
            return true
        }
        
        // Check license type
        switch playlist.editorLicenseType {
        case .everyone:
            // Everyone can edit if playlist is public
            return playlist.visibility == .public
        case .invitedOnly:
            // For invited-only playlists, check if user has accepted invitation with edit permissions
            // First check cached accepted invitations
            let hasAcceptedInvitation = acceptedInvitations.contains { invitation in
                invitation.playlistId == playlist.id &&
                invitation.inviteeId == currentUser.id &&
                invitation.status == .accepted &&
                invitation.role.canEdit
            }
            
            if hasAcceptedInvitation {
                return true
            }

            return false
        }
    }
    
    func canAccessPlaylist(_ playlist: CollaborativePlaylist) -> Bool {
        // Since fetchPlaylists() uses RLS policy, if user can see the playlist, they have access
        // This is a simpler approach than the async version above
        return true
    }
    
    // MARK: - Debug Methods
    
    func debugRLSPolicy() async {
        guard let currentUser = supabaseService.currentUser else {
            print("DEBUG: No current user")
            return
        }
        
        print("DEBUG: Testing RLS policy for user \(currentUser.id)")
        
        // Special debugging for Fashion user
        if currentUser.id == "d96e8b7b-0005-48cf-9974-c551cbaf053b" {
            print("DEBUG: This is the Fashion user - running extended debugging")
        }
        
        do {
            // Test 1: Get all playlists without any filters (should respect RLS)
            let allResponse = try await supabaseService.client
                .from("playlists")
                .select("id, name, visibility, creator_id, is_active")
                .execute()
            
            let allData = allResponse.data
            let allPlaylists = try JSONSerialization.jsonObject(with: allData) as? [[String: Any]] ?? []
            print("DEBUG: RLS-filtered playlists: \(allPlaylists.count)")
            for playlist in allPlaylists {
                let id = playlist["id"] as? String ?? "unknown"
                let name = playlist["name"] as? String ?? "unknown"
                let visibility = playlist["visibility"] as? String ?? "unknown"
                let creatorId = playlist["creator_id"] as? String ?? "unknown"
                let isActive = playlist["is_active"] as? Bool ?? false
                print("  - \(name) (id: \(id), visibility: \(visibility), creator: \(creatorId), active: \(isActive))")
            }
            
            // Test 2: Get all accepted invitations for this user
            let invitationsResponse = try await supabaseService.client
                .from("playlist_invitations")
                .select("playlist_id, status, role, updated_at")
                .eq("invitee_id", value: currentUser.id)
                .eq("status", value: "accepted")
                .execute()
            
            let invitationsData = invitationsResponse.data
            let acceptedInvitations = try JSONSerialization.jsonObject(with: invitationsData) as? [[String: Any]] ?? []
            print("DEBUG: Accepted invitations: \(acceptedInvitations.count)")
            for invitation in acceptedInvitations {
                let playlistId = invitation["playlist_id"] as? String ?? "unknown"
                let role = invitation["role"] as? String ?? "unknown"
                let updatedAt = invitation["updated_at"] as? String ?? "unknown"
                print("  - Playlist: \(playlistId), Role: \(role), Updated: \(updatedAt)")
            }
            
            // Test 3: For each accepted invitation, try to query that specific playlist
            for invitation in acceptedInvitations {
                if let playlistId = invitation["playlist_id"] as? String {
                    print("DEBUG: Testing access to playlist \(playlistId)")
                    
                    let specificResponse = try await supabaseService.client
                        .from("playlists")
                        .select("id, name, visibility, creator_id, is_active")
                        .eq("id", value: playlistId)
                        .execute()
                    
                    let specificData = specificResponse.data
                    let specificResult = try JSONSerialization.jsonObject(with: specificData) as? [[String: Any]] ?? []
                    
                    print("DEBUG: Playlist \(playlistId) query result: \(specificResult.count) records")
                    if specificResult.isEmpty {
                        print("  ERROR: Playlist not accessible despite accepted invitation!")
                        
                        // Try to check if playlist exists by bypassing RLS (won't work in client, but good for debugging)
                        print("  Attempting to check if playlist exists...")
                        
                    } else {
                        let playlist = specificResult[0]
                        let name = playlist["name"] as? String ?? "unknown"
                        let visibility = playlist["visibility"] as? String ?? "unknown"
                        let isActive = playlist["is_active"] as? Bool ?? false
                        let creatorId = playlist["creator_id"] as? String ?? "unknown"
                        print("  SUCCESS: \(name) (visibility: \(visibility), active: \(isActive), creator: \(creatorId))")
                    }
                }
            }
            
            // Test 4: Check if auth.uid() is working correctly
            do {
                let currentUserResponse = try await supabaseService.client
                    .rpc("get_current_user_id")
                    .execute()
                
                print("DEBUG: Current user from auth.uid(): \(currentUserResponse)")
            } catch {
                print("DEBUG: get_current_user_id RPC failed: \(error)")
            }
            
            // Test 5: Try a raw SQL query to test the RLS policy conditions
            // This helps us understand if the issue is with the RLS policy itself
            print("DEBUG: Testing RLS policy components...")
            
        } catch {
            print("DEBUG: Error testing RLS policy: \(error)")
        }
    }
    
    // MARK: - Task Management
    
    func cancelAllTasks() {
        currentFetchTask?.cancel()
        currentTracksTask?.cancel()
        currentInvitationsTask?.cancel()
        currentFetchTask = nil
        currentTracksTask = nil
        currentInvitationsTask = nil
    }
    
    func refreshAllData(force: Bool = false) async {
        await fetchPlaylists(force: force)
        await fetchPlaylistInvitations()
    }
    
    deinit {
        cancelAllTasks()
    }
    
    // MARK: - Utility Methods
    
    func cleanupOrphanedInvitations() async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        do {
            // Get all invitations for the current user
            let invitationsResponse = try await supabaseService.client
                .from("playlist_invitations")
                .select("id, playlist_id")
                .eq("invitee_id", value: currentUser.id)
                .execute()
            
            let invitationsData = invitationsResponse.data
            let invitations = try JSONSerialization.jsonObject(with: invitationsData) as? [[String: Any]] ?? []
            
            for invitation in invitations {
                guard let invitationId = invitation["id"] as? String,
                      let playlistId = invitation["playlist_id"] as? String else { continue }
                
                // Check if the playlist still exists
                let playlistResponse = try await supabaseService.client
                    .from("playlists")
                    .select("id")
                    .eq("id", value: playlistId)
                    .eq("is_active", value: true)
                    .execute()
                
                let playlistData = playlistResponse.data
                let playlists = try JSONSerialization.jsonObject(with: playlistData) as? [[String: Any]] ?? []
                
                if playlists.isEmpty {
                    // Playlist doesn't exist, delete the orphaned invitation
                    try await supabaseService.client
                        .from("playlist_invitations")
                        .delete()
                        .eq("id", value: invitationId)
                        .execute()
                    
                    print("Cleaned up orphaned invitation \(invitationId) for non-existent playlist \(playlistId)")
                }
            }
        } catch {
            print("Failed to cleanup orphaned invitations: \(error)")
        }
    }
    
    // MARK: - Audio Player Integration
    
    func playPlaylist(_ playlist: CollaborativePlaylist, startIndex: Int = 0) async {
        do {
            let playlistTracks = try await getPlaylistTracks(playlistId: playlist.id)
            
            // Sort PlaylistTrack by position, then convert to Track
            let sortedPlaylistTracks = playlistTracks.sorted { $0.position < $1.position }
            let playableTracks: [Track] = sortedPlaylistTracks.map { $0.track }
            
            DispatchQueue.main.async {
                self.audioPlayer.playPlaylist(playlist.id, tracks: playableTracks, startIndex: startIndex)
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to load playlist tracks: \(error.localizedDescription)"
            }
        }
    }
    
    func playTrackFromPlaylist(_ track: Track, in playlist: CollaborativePlaylist) async {
        print("🎵 PlaylistService: Playing track from playlist - \(track.title)")
        print("🎵 Track YouTube Video ID: \(track.youtubeVideoId ?? "none")")
        print("🎵 Track ID: \(track.id)")
        
        do {
            let playlistTracks = try await getPlaylistTracks(playlistId: playlist.id)
            
            // Sort PlaylistTrack by position, then convert to Track
            let sortedPlaylistTracks = playlistTracks.sorted { $0.position < $1.position }
            let playableTracks: [Track] = sortedPlaylistTracks.map { $0.track }
            
            print("🎵 Found \(playableTracks.count) playable tracks")
            for (index, playableTrack) in playableTracks.enumerated() {
                print("   \(index): \(playableTrack.title) (ID: \(playableTrack.id), YouTube: \(playableTrack.youtubeVideoId ?? "none"))")
            }
            
            // Try to find the track by YouTube video ID first, then by ID
            let startIndex: Int
            if let youtubeVideoId = track.youtubeVideoId {
                startIndex = playableTracks.firstIndex { $0.youtubeVideoId == youtubeVideoId } ?? 
                           playableTracks.firstIndex { $0.id == track.id } ?? 0
                print("🎵 Found track by YouTube video ID: \(youtubeVideoId) at index: \(startIndex)")
            } else {
                startIndex = playableTracks.firstIndex { $0.id == track.id } ?? 0
                print("🎵 Found track by ID at index: \(startIndex)")
            }
            
            print("🎵 Starting at index: \(startIndex)")
            print("🎵 Track to play: \(playableTracks.indices.contains(startIndex) ? playableTracks[startIndex].title : "Invalid index")")
            
            DispatchQueue.main.async {
                self.audioPlayer.playPlaylist(playlist.id, tracks: playableTracks, startIndex: startIndex)
            }
        } catch {
            print("🎵 Error playing track from playlist: \(error)")
            DispatchQueue.main.async {
                self.error = "Failed to load playlist tracks: \(error.localizedDescription)"
            }
        }
    }
    
    func addTrackToQueue(_ track: Track) {
        audioPlayer.addToQueue(track)
    }
    
    func playNext(_ track: Track) {
        audioPlayer.insertNext(track)
    }
    
    // MARK: - Track Reordering with Queue Updates
    
    func moveTrack(in playlistId: String, from sourceIndex: Int, to destinationIndex: Int) async throws {
        // Get current tracks
        let currentTracks = try await getPlaylistTracks(playlistId: playlistId)
        
        // Perform the move operation
        var reorderedTracks = currentTracks
        let movedTrack = reorderedTracks.remove(at: sourceIndex)
        reorderedTracks.insert(movedTrack, at: destinationIndex)
        
        // Use the existing reorderTracks method
        try await reorderTracks(reorderedTracks)
        
        // Update audio player queue if this playlist is currently playing
        if case .playlist(let currentPlaylistId) = audioPlayer.queueSource,
           currentPlaylistId == playlistId {
            let updatedPlaylistTracks = try await getPlaylistTracks(playlistId: playlistId)
            let sortedPlaylistTracks = updatedPlaylistTracks.sorted { $0.position < $1.position }
            let sortedTracks: [Track] = sortedPlaylistTracks.map { $0.track }
            
            DispatchQueue.main.async {
                self.audioPlayer.updateQueueFromPlaylist(sortedTracks)
            }
        }
    }
}
