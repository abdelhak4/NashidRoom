import SwiftUI

struct CreateCollaborativePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var playlistService: PlaylistService
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var visibility: PlaylistVisibility = .public
    @State private var editorLicenseType: PlaylistLicenseType = .everyone
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Playlist Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                } header: {
                    Text("Basic Information")
                }
                
                Section {
                    Picker("Visibility", selection: $visibility) {
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
                    Text(visibility.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Picker("Editor Permissions", selection: $editorLicenseType) {
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
                    Text(editorLicenseType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button {
                        createPlaylist()
                    } label: {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Create Playlist")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding()
                        .background(isFormValid ? Color.accentColor : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(!isFormValid || isCreating)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createPlaylist() {
        guard isFormValid else { return }
        
        isCreating = true
        
        Task {
            do {
                _ = try await playlistService.createPlaylist(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    visibility: visibility,
                    editorLicenseType: editorLicenseType
                )
                
                DispatchQueue.main.async {
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCreating = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
}

#Preview {
    CreateCollaborativePlaylistView()
        .environmentObject(PlaylistService())
}
