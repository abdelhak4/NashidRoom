import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: String
    @EnvironmentObject var playlistService: PlaylistService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    @State private var showingTrackSearch = false
    @State private var showingInviteUser = false
    @State private var showingSettings = false
    @State private var showingFullPlayer = false
    @State private var draggedTrack: PlaylistTrack?
    
    private var playlist: CollaborativePlaylist? {
        playlistService.playlists.first { $0.id == playlistId }
    }
    
    private var canEdit: Bool {
        guard let playlist = playlist else { return false }
        return playlistService.canEditPlaylist(playlist)
    }
    
    private var shouldShowInviteButton: Bool {
        guard let playlist = playlist else { return false }
        // Don't show invite button if playlist is public and everyone can edit
        return !(playlist.visibility == .public && playlist.editorLicenseType == .everyone)
    }
    
    private var editMenu: some View {
        Menu {
            Button {
                showingTrackSearch = true
            } label: {
                Label("Add Track", systemImage: "plus")
            }
            
            if shouldShowInviteButton {
                Button {
                    showingInviteUser = true
                } label: {
                    Label("Invite Collaborator", systemImage: "person.badge.plus")
                }
            }
            
            Button {
                showingSettings = true
            } label: {
                Label("Playlist Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gear")
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if playlist == nil {
                    ProgressView("Loading playlist...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if playlistService.isLoading {
                    ProgressView("Loading tracks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if playlistService.playlistTracks.isEmpty {
                    emptyTracksView
                } else {
                    tracksList
                }
            }
            .navigationTitle(playlist?.name ?? "Playlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if canEdit {
                        editMenu
                    } else {
                        settingsButton
                    }
                }
            }
            .sheet(isPresented: $showingTrackSearch) {
                if let playlist = playlist {
                    PlaylistTrackSearchView(playlist: playlist)
                        .environmentObject(playlistService)
                }
            }
            .sheet(isPresented: $showingInviteUser) {
                if let playlist = playlist {
                    InviteToPlaylistView(playlist: playlist)
                        .environmentObject(playlistService)
                }
            }
            .sheet(isPresented: $showingSettings) {
                if let playlist = playlist {
                    PlaylistSettingsView(playlist: playlist)
                        .environmentObject(playlistService)
                }
            }
            .fullScreenCover(isPresented: $showingFullPlayer) {
                MusicPlayerView()
            }
            .task {
                await playlistService.fetchPlaylistTracks(playlistId: playlistId)
            }
            .onChange(of: audioPlayer.currentTrack) { newTrack in
                if newTrack != nil,
                   case .playlist(let currentPlaylistId) = audioPlayer.queueSource,
                   currentPlaylistId == playlistId {
                    showingFullPlayer = true
                }
            }
        }
    }
    
    private var emptyTracksView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Tracks Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(canEdit ? "Add some tracks to get started" : "Waiting for collaborators to add tracks")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if canEdit {
                Button {
                    showingTrackSearch = true
                } label: {
                    Label("Add Track", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }
    
    private var tracksList: some View {
        List {
            Section {
                ForEach(playlistService.playlistTracks) { track in
                    PlaylistTrackEditRowView(track: track, canEdit: canEdit, playlistId: playlistId)
                        .environmentObject(playlistService)
                }
                .onMove(perform: canEdit ? moveTrack : nil)
                .onDelete(perform: canEdit ? deleteTrack : nil)
            } header: {
                HStack {
                    Text("\(playlistService.playlistTracks.count) tracks")
                    Spacer()
                    if canEdit {
                        Button {
                            showingTrackSearch = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(canEdit ? .active : .inactive))
    }
    
    private func moveTrack(from source: IndexSet, to destination: Int) {
        guard canEdit else { return }
        
        var reorderedTracks = playlistService.playlistTracks
        reorderedTracks.move(fromOffsets: source, toOffset: destination)
        
        Task {
            try await playlistService.reorderTracks(reorderedTracks)
        }
    }
    
    private func deleteTrack(at offsets: IndexSet) {
        guard canEdit else { return }
        
        for index in offsets {
            let trackToDelete = playlistService.playlistTracks[index]
            Task {
                try await playlistService.removeTrackFromPlaylist(trackToDelete)
            }
        }
    }
}

struct PlaylistTrackEditRowView: View {
    let track: PlaylistTrack
    let canEdit: Bool
    let playlistId: String
    @EnvironmentObject var playlistService: PlaylistService
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    private var playlist: CollaborativePlaylist? {
        playlistService.playlists.first { $0.id == playlistId }
    }
    
    private var isCurrentTrack: Bool {
        guard let currentTrack = audioPlayer.currentTrack else { return false }
        guard case .playlist(let currentPlaylistId) = audioPlayer.queueSource else { return false }
        return currentTrack.id == track.trackId && currentPlaylistId == playlistId
    }
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: track.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown Track")
                    .font(.headline)
                    .fontWeight(isCurrentTrack ? .semibold : .regular)
                    .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                    .lineLimit(1)
                
                Text(track.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(track.album ?? "Unknown Album")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(track.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isCurrentTrack {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            playTrack()
        }
        .contextMenu {
            Button {
                playTrack()
            } label: {
                Label("Play Now", systemImage: "play")
            }
            
            Button {
                addToQueue()
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
        }
        .padding(.vertical, 4)
    }
    
    private func playTrack() {
        guard let playlist = playlist else { return }
        Task {
            await playlistService.playTrackFromPlaylist(track.track, in: playlist)
        }
    }
    
    private func addToQueue() {
        audioPlayer.addToQueue(track.track)
    }
}

#Preview {
    PlaylistDetailView(playlistId: "preview-playlist-id")
        .environmentObject(PlaylistService())
}
