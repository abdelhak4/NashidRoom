import SwiftUI

struct PlaylistSettingsView: View {
    @State private var playlist: CollaborativePlaylist
    @EnvironmentObject var playlistService: PlaylistService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isUpdating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    
    private let originalPlaylist: CollaborativePlaylist
    
    init(playlist: CollaborativePlaylist) {
        self.originalPlaylist = playlist
        self._playlist = State(initialValue: playlist)
    }
    
    private var hasChanges: Bool {
        playlist.name != originalPlaylist.name ||
        playlist.description != originalPlaylist.description ||
        playlist.visibility != originalPlaylist.visibility ||
        playlist.editorLicenseType != originalPlaylist.editorLicenseType
    }
    
    private var isOwner: Bool {
        guard let currentUser = SupabaseService.shared.currentUser else { return false }
        return playlist.creatorId == currentUser.id
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Playlist Name", text: $playlist.name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(!isOwner)
                    
                    TextField("Description", text: $playlist.description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .disabled(!isOwner)
                } header: {
                    Text("Basic Information")
                } footer: {
                    if !isOwner {
                        Text("Only the playlist creator can edit basic information.")
                    }
                }
                
                if isOwner {
                    Section {
                        Picker("Visibility", selection: $playlist.visibility) {
                            ForEach(PlaylistVisibility.allCases, id: \.self) { visibility in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(visibility.displayName)
                                        .font(.body)
                                    Text(visibility.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(visibility)
                            }
                        }
                        .pickerStyle(InlinePickerStyle())
                    } header: {
                        Text("Who Can Access")
                    } footer: {
                        Text(playlist.visibility.description)
                    }
                    
                    Section {
                        Picker("Editor Permissions", selection: $playlist.editorLicenseType) {
                            ForEach(PlaylistLicenseType.allCases, id: \.self) { licenseType in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(licenseType.displayName)
                                        .font(.body)
                                    Text(licenseType.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(licenseType)
                            }
                        }
                        .pickerStyle(InlinePickerStyle())
                    } header: {
                        Text("Who Can Edit")
                    } footer: {
                        Text(playlist.editorLicenseType.description)
                    }
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Tracks")
                            Text("\(playlist.trackCount) tracks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(playlist.trackCount)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Created")
                            Text(playlist.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("Updated")
                        Text(playlist.updatedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Information")
                }
                
                if isOwner {
                    Section {
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Playlist")
                            }
                            .foregroundColor(.red)
                        }
                    } footer: {
                        Text("This action cannot be undone. All tracks and collaborations will be permanently deleted.")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Playlist Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if hasChanges && isOwner {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            updatePlaylist()
                        }
                        .disabled(isUpdating)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Playlist", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deletePlaylist()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete \"\(playlist.name)\"? This action cannot be undone.")
            }
        }
    }
    
    private func updatePlaylist() {
        guard hasChanges && isOwner else { return }
        
        isUpdating = true
        
        Task {
            do {
                try await playlistService.updatePlaylist(playlist)
                
                DispatchQueue.main.async {
                    self.isUpdating = false
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isUpdating = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func deletePlaylist() {
        guard isOwner else { return }
        
        Task {
            do {
                try await playlistService.deletePlaylist(playlist)
                
                DispatchQueue.main.async {
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
}

#Preview {
    PlaylistSettingsView(playlist: CollaborativePlaylist(
        name: "Test Playlist",
        description: "A test playlist",
        creatorId: "user123",
        trackCount: 10
    ))
    .environmentObject(PlaylistService())
}
