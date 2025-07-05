import SwiftUI
import CoreLocation

struct EventDetailView: View {
    let event: Event
    @StateObject private var eventService = EventService()
    @StateObject private var voteService = VoteService()
    @StateObject private var youtubeService = YouTubeService.shared
    @StateObject private var locationService = LocationService.shared
    @ObservedObject private var supabaseService = SupabaseService.shared
    @State private var tracks: [Track] = []
    @State private var showingTrackSearch = false
    @State private var showingInvitationManagement = false
    @State private var canVote = true
    @State private var voteErrorMessage: String?
    @State private var isRefreshing = false
    @State private var showingFullPlayer = false
    
    private var isHost: Bool {
        guard let currentUser = supabaseService.currentUser else {
            print("🔍 [DEBUG] isHost - No current user available")
            return false
        }
        let isHostCheck = currentUser.id == event.hostId
        print("🔍 [DEBUG] isHost - Current user ID: \(currentUser.id), Event host ID: \(event.hostId), isHost: \(isHostCheck)")
        return isHostCheck
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Event header
            EventHeaderView(event: event)
            
            // Invitation management section for events that require invitations (host only)
            if isHost && (event.visibility == .private || event.licenseType == .premium) {
                InviteManagementBanner(onTap: {
                    showingInvitationManagement = true
                })
            }
            
            // Location/Time status for location-based events
            if event.licenseType == .locationBased {
                VStack(spacing: 8) {
                    LocationStatusView(event: event)
                    TimeStatusView(event: event)
                }
                .padding()
            }
            
            // Voting permission view if user can't vote
            if !canVote && voteErrorMessage != nil {
                VotingPermissionView(event: event, errorMessage: voteErrorMessage)
            } else {
                // Track list with voting
                TrackListView(
                    tracks: voteService.reorderTracks(tracks),
                    userVotes: voteService.userVotes,
                    canVote: canVote,
                    onVote: handleVote,
                    onRefresh: refreshTracks,
                    voteService: voteService,
                    onTrackPlay: { track in
                        Task {
                            await eventService.playTrackFromEvent(track, in: event)
                            // Navigate to full player after starting playback
                            showingFullPlayer = true
                        }
                    }
                )
                .refreshable {
                    await refreshTracks()
                }
            }
            
            // Add track button
            if canVote {
                Button(action: { showingTrackSearch = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Track")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Only show invite button for hosts of events that require invitations
                if isHost && (event.visibility == .private || event.licenseType == .premium) {
                    Button(action: {
                        showingInvitationManagement = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Invite")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTrackSearch) {
            TrackSearchView(
                title: "Add Track",
                subtitle: "Add tracks to \"\(event.name)\""
            ) { track in
                addTrackToEvent(track)
            }
        }
        .sheet(isPresented: $showingInvitationManagement) {
            InvitationManagementView(event: event)
        }
        .fullScreenCover(isPresented: $showingFullPlayer) {
            MusicPlayerView()
        }
        .task {
            await loadEventData()
            await voteService.loadAllVoteData(eventId: event.id)
            voteService.subscribeToVoteUpdates(eventId: event.id)
        }
        .onDisappear {
            voteService.unsubscribeFromVoteUpdates()
        }
        .alert("Voting Error", isPresented: .constant(voteErrorMessage != nil)) {
            Button("OK") { voteErrorMessage = nil }
        } message: {
            if let message = voteErrorMessage {
                Text(message)
            }
        }
        .alert("Location Required", isPresented: .constant(event.licenseType == .locationBased && locationService.authorizationStatus == .denied)) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This event requires location access to vote. Please enable location permissions in Settings.")
        }
    }
    
    private func loadEventData() async {
        // Request location permission if this is a location-based event
        if event.licenseType == .locationBased {
            await requestLocationPermissionIfNeeded()
        }
        
        await refreshTracks()
        await checkVotingPermissions()
    }
    
    private func requestLocationPermissionIfNeeded() async {
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestLocationPermission()
        }
    }
    
    private func refreshTracks() async {
        isRefreshing = true
        do {
            tracks = try await eventService.fetchEventTracks(eventId: event.id)
            await voteService.loadAllVoteData(eventId: event.id)
            if let error = voteService.error {
                voteErrorMessage = error
            }
        } catch {
            voteErrorMessage = error.localizedDescription
        }
        isRefreshing = false
    }
    
    private func checkVotingPermissions() async {
        do {
            canVote = try await eventService.canUserVote(eventId: event.id)
        } catch {
            canVote = false
            voteErrorMessage = error.localizedDescription
        }
    }
    
    private func handleVote(trackId: String, voteType: VoteType) {
        Task {
            await voteService.voteForTrack(eventId: event.id, trackId: trackId, voteType: voteType)
            
            if let error = voteService.error {
                voteErrorMessage = error
            } else {
                // Refresh tracks to see updated vote counts
                await refreshTracks()
            }
        }
    }
    
    private func addTrackToEvent(_ track: Track) {
        Task {
            do {
                try await eventService.addTrackToEvent(eventId: event.id, track: track)
                await refreshTracks()
            } catch {
                voteErrorMessage = error.localizedDescription
            }
        }
    }
}

struct EventHeaderView: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if !event.description.isEmpty {
                        Text(event.description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    EventVisibilityBadge(visibility: event.visibility)
                    LicenseTypeBadge(licenseType: event.licenseType)
                }
            }
            
            if event.licenseType == .locationBased {
                LocationInfoView(event: event)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct LocationInfoView: View {
    let event: Event
    
    var body: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundColor(.white.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 2) {
                if let radius = event.locationRadius {
                    Text("Location-based voting • \(radius)m radius")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if let start = event.timeStart, let end = event.timeEnd {
                    Text("Active: \(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
        }
    }
}

struct TrackListView: View {
    let tracks: [Track]
    let userVotes: [String: VoteType]
    let canVote: Bool
    let onVote: (String, VoteType) -> Void
    let onRefresh: () async -> Void
    let voteService: VoteService
    let onTrackPlay: ((Track) -> Void)?  // Add play action
    
    init(tracks: [Track], userVotes: [String: VoteType], canVote: Bool, onVote: @escaping (String, VoteType) -> Void, onRefresh: @escaping () async -> Void, voteService: VoteService, onTrackPlay: ((Track) -> Void)? = nil) {
        self.tracks = tracks
        self.userVotes = userVotes
        self.canVote = canVote
        self.onVote = onVote
        self.onRefresh = onRefresh
        self.voteService = voteService
        self.onTrackPlay = onTrackPlay
    }
    
    var body: some View {
        List {
            if tracks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No tracks yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Be the first to add a track to the playlist!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(
                        track: track,
                        position: index + 1,
                        userVote: userVotes[track.id],
                        canVote: canVote,
                        onVote: { voteType in
                            onVote(track.id, voteType)
                        },
                        voteCount: voteService.getVoteCount(for: track.id, fallback: track.votes),
                        onPlay: onTrackPlay
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Invite Management Banner
struct InviteManagementBanner: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.blue)
                        Text("Manage Invitations")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Text("Invite people to your private event")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

#Preview {
    NavigationView {
        EventDetailView(event: Event(
            name: "Private Summer Party",
            description: "Let's make the perfect playlist together!",
            hostId: "host-id",
            visibility: .private,
            licenseType: .premium,
            spotifyPlaylistId: "playlist-id"
        ))
    }
}
