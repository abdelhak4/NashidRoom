import Foundation
import Combine

@MainActor
class PlaylistEditorViewModel: ObservableObject {
    @Published var playlists: [CollaborativePlaylist] = []
    @Published var currentPlaylist: CollaborativePlaylist?
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""
    
    private let playlistService = PlaylistService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind to playlist service
        playlistService.$playlists
            .assign(to: &$playlists)
        
        playlistService.$currentPlaylist
            .assign(to: &$currentPlaylist)
        
        playlistService.$isLoading
            .assign(to: &$isLoading)
        
        playlistService.$error
            .assign(to: &$error)
    }
    
    var filteredPlaylists: [CollaborativePlaylist] {
        if searchText.isEmpty {
            return playlists
        } else {
            return playlists.filter { playlist in
                playlist.name.localizedCaseInsensitiveContains(searchText) ||
                playlist.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func loadPlaylists() async {
        await playlistService.fetchPlaylists()
    }
    
    func createPlaylist(
        name: String,
        description: String = "",
        visibility: PlaylistVisibility = .public,
        editorLicenseType: PlaylistLicenseType = .everyone
    ) async throws -> CollaborativePlaylist {
        return try await playlistService.createPlaylist(
            name: name,
            description: description,
            visibility: visibility,
            editorLicenseType: editorLicenseType
        )
    }
    
    func updatePlaylist(_ playlist: CollaborativePlaylist) async throws {
        try await playlistService.updatePlaylist(playlist)
    }
    
    func deletePlaylist(_ playlist: CollaborativePlaylist) async throws {
        try await playlistService.deletePlaylist(playlist)
    }
    
    func canEditPlaylist(_ playlist: CollaborativePlaylist) -> Bool {
        return playlistService.canEditPlaylist(playlist)
    }
    
    func canAccessPlaylist(_ playlist: CollaborativePlaylist) -> Bool {
        return playlistService.canAccessPlaylist(playlist)
    }
    
    func clearError() {
        error = nil
    }
    
    func getPlaylistService() -> PlaylistService {
        return playlistService
    }
}
