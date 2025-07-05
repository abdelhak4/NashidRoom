import SwiftUI

struct PlaylistEditorView: View {
    @StateObject private var playlistService = PlaylistService()
    @State private var showingCreatePlaylist = false
    @State private var showingInviteUser = false
    @State private var selectedPlaylist: CollaborativePlaylist?
    @State private var searchText = ""
    
    var filteredPlaylists: [CollaborativePlaylist] {
        if searchText.isEmpty {
            return playlistService.playlists
        } else {
            return playlistService.playlists.filter { playlist in
                playlist.name.localizedCaseInsensitiveContains(searchText) ||
                playlist.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            if playlistService.isLoading {
                ProgressView("Loading playlists...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPlaylists.isEmpty {
                emptyStateView
            } else {
                playlistsList
            }
        }
        .navigationTitle("Playlists")
        .searchable(text: $searchText, prompt: "Search playlists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCreatePlaylist = true
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Create new playlist")
                }
            }
        }
        .sheet(isPresented: $showingCreatePlaylist, onDismiss: {
            // Refresh playlists when the create sheet is dismissed
            Task {
                await playlistService.fetchPlaylists()
            }
            // Clear any errors when the sheet is dismissed
            playlistService.error = nil
        }) {
            CreateCollaborativePlaylistView()
                .environmentObject(playlistService)
        }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistDetailView(playlistId: playlist.id)
                .environmentObject(playlistService)
        }
        .alert("Error", isPresented: .constant(playlistService.error != nil)) {
            Button("OK") {
                playlistService.error = nil
            }
        } message: {
            Text(playlistService.error ?? "")
        }
        .task {
            await playlistService.fetchPlaylists()
            await playlistService.fetchPlaylistInvitations()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Playlists Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first collaborative playlist or wait for invitations from friends")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingCreatePlaylist = true
            } label: {
                Label("Create Playlist", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private var playlistsList: some View {
        List {
            ForEach(filteredPlaylists) { playlist in
                PlaylistRowView(playlist: playlist) {
                    selectedPlaylist = playlist
                }
                .environmentObject(playlistService)
            }
        }
        .refreshable {
            await playlistService.fetchPlaylists()
        }
    }
}

struct PlaylistRowView: View {
    let playlist: CollaborativePlaylist
    let onTap: () -> Void
    @EnvironmentObject var playlistService: PlaylistService
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(playlist.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        PlaylistVisibilityBadge(visibility: playlist.visibility)
                        PlaylistLicenseBadge(licenseType: playlist.editorLicenseType)
                    }
                    
                    if !playlist.description.isEmpty {
                        Text(playlist.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text("\(playlist.trackCount) tracks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if playlistService.canEditPlaylist(playlist) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PlaylistVisibilityBadge: View {
    let visibility: PlaylistVisibility
    
    var body: some View {
        Text(visibility.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(visibility == .public ? .green : .orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(visibility == .public ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            )
    }
}

struct PlaylistLicenseBadge: View {
    let licenseType: PlaylistLicenseType
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: licenseType == .everyone ? "person.2.fill" : "person.crop.circle.fill.badge.checkmark")
            Text(licenseType == .everyone ? "Open" : "Invite")
        }
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundColor(licenseType == .everyone ? .blue : .purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(licenseType == .everyone ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
        )
    }
}

#Preview {
    PlaylistEditorView()
}
