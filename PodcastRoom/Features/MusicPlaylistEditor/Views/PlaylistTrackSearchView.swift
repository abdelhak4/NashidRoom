import SwiftUI

struct PlaylistTrackSearchView: View {
    let playlist: CollaborativePlaylist
    @EnvironmentObject var playlistService: PlaylistService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        TrackSearchView(
            title: "Add Tracks",
            subtitle: "Find songs to add to \"\(playlist.name)\""
        ) { track in
            addTrackToPlaylist(track)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func addTrackToPlaylist(_ track: Track) {
        Task {
            do {
                try await playlistService.addTrackToPlaylist(playlistId: playlist.id, track: track)
                
                DispatchQueue.main.async {
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to add track: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
}

#Preview {
    PlaylistTrackSearchView(playlist: CollaborativePlaylist(
        name: "Test Playlist",
        creatorId: "user123"
    ))
    .environmentObject(PlaylistService())
}
