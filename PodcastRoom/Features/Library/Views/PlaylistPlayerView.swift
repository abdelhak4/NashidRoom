import SwiftUI

struct PlaylistPlayerView: View {
    let playlist: CollaborativePlaylist
    @StateObject private var playlistService = PlaylistService()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var tracks: [PlaylistTrack] = []
    @State private var isLoading = false
    @State private var showAddTrack = false
    @State private var showingFullPlayer = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Playlist Header
                    playlistHeader
                    
                    // Play Controls
                    playControls
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Tracks List
                    if isLoading {
                        ProgressView("Loading tracks...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if tracks.isEmpty {
                        ContentUnavailableView(
                            "No tracks yet",
                            systemImage: "music.note.list",
                            description: Text("Add some tracks to get started")
                        )
                        .frame(minHeight: 200)
                    } else {
                        tracksList
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddTrack = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTrack) {
            AddTrackView(playlistId: playlist.id) {
                Task {
                    await loadTracks()
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullPlayer) {
            MusicPlayerView()
        }
        .task {
            await loadTracks()
        }
    }
    
    private var playlistHeader: some View {
        VStack(spacing: 12) {
            // Playlist artwork or placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.8))
                )
            
            VStack(spacing: 4) {
                Text(playlist.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if !playlist.description.isEmpty {
                    Text(playlist.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Text("\(tracks.count) tracks")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding()
    }
    
    private var playControls: some View {
        HStack(spacing: 20) {
            // Shuffle & Play
            Button {
                Task {
                    await playlistService.playPlaylist(playlist)
                    audioPlayer.shuffleQueue()
                }
            } label: {
                HStack {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .disabled(tracks.isEmpty)
            
            // Play All
            Button {
                Task {
                    await playlistService.playPlaylist(playlist)
                    // Navigate to full player after starting playback
                    showingFullPlayer = true
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Play All")
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Capsule())
            }
            .disabled(tracks.isEmpty)
        }
        .padding()
    }
    
    private var tracksList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, playlistTrack in
                let track = playlistTrack.track
                let isCurrentTrack = audioPlayer.currentTrack?.id == track.id &&
                                   (audioPlayer.queueSource == .playlist(playlist.id))
                
                PlaylistTrackRowView(
                    track: track,
                    isCurrentTrack: isCurrentTrack,
                    onPlay: {
                        Task {
                            await playlistService.playTrackFromPlaylist(track, in: playlist)
                            // Navigate to full player after starting playback
                            showingFullPlayer = true
                        }
                    },
                    onAddToQueue: {
                        playlistService.addTrackToQueue(track)
                    },
                    onRemove: {
                        Task {
                            await removeTrack(playlistTrack)
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if index < tracks.count - 1 {
                    Divider()
                        .padding(.leading, 82)
                }
            }
            .onMove(perform: moveTrack)
        }
    }
    
    private func loadTracks() async {
        isLoading = true
        do {
            tracks = try await playlistService.getPlaylistTracks(playlistId: playlist.id)
        } catch {
            print("Failed to load tracks: \(error)")
        }
        isLoading = false
    }
    
    private func moveTrack(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        
        var newTracks = tracks
        let movedTrack = newTracks.remove(at: sourceIndex)
        newTracks.insert(movedTrack, at: destination > sourceIndex ? destination - 1 : destination)
        tracks = newTracks
        
        Task {
            do {
                try await playlistService.moveTrack(
                    in: playlist.id,
                    from: sourceIndex,
                    to: destination > sourceIndex ? destination - 1 : destination
                )
            } catch {
                // Revert on error
                await loadTracks()
            }
        }
    }
    
    private func removeTrack(_ playlistTrack: PlaylistTrack) async {
        do {
            try await playlistService.removeTrackFromPlaylist(playlistTrack)
            await loadTracks()
        } catch {
            print("Failed to remove track: \(error)")
        }
    }
}

struct AddTrackView: View {
    let playlistId: String
    let onTrackAdded: () -> Void
    
    @StateObject private var youTubeService = YouTubeService.shared
    @StateObject private var playlistService = PlaylistService()
    @State private var searchText = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                    .padding()
                
                // Search Results
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No results found",
                        systemImage: "magnifyingglass",
                        description: Text("Try searching with different keywords")
                    )
                } else {
                    List(searchResults) { track in
                        SearchResultRowView(
                            track: track,
                            onSelect: {
                                Task {
                                    await addTrack(track)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Add Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        Task {
            do {
                let results = try await youTubeService.searchTracks(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
    
    private func addTrack(_ track: Track) async {
        do {
            try await playlistService.addTrackToPlaylist(playlistId: playlistId, track: track)
            await MainActor.run {
                onTrackAdded()
                dismiss()
            }
        } catch {
            print("Failed to add track: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        PlaylistPlayerView(
            playlist: CollaborativePlaylist(
                name: "My Awesome Playlist",
                description: "Great songs for any occasion",
                creatorId: "user123"
            )
        )
    }
}
