import SwiftUI

struct InviteToPlaylistView: View {
    let playlist: CollaborativePlaylist
    @EnvironmentObject var playlistService: PlaylistService
    @Environment(\.dismiss) private var dismiss
    
    @State private var userEmail = ""
    @State private var selectedRole: PlaylistRole = .collaborator
    @State private var isInviting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    
    var isFormValid: Bool {
        !userEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        userEmail.contains("@")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("User Email", text: $userEmail)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } header: {
                    Text("Invite User")
                } footer: {
                    Text("Enter the email address of the user you want to invite to collaborate on this playlist.")
                }
                
                Section {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(PlaylistRole.allCases, id: \.self) { role in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.displayName)
                                    .font(.body)
                                Text(role.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(role)
                        }
                    }
                    .pickerStyle(InlinePickerStyle())
                } header: {
                    Text("Permission Level")
                } footer: {
                    Text(selectedRole.description)
                }
                
                Section {
                    PlaylistInfoView(playlist: playlist)
                } header: {
                    Text("Playlist Information")
                }
                
                Section {
                    Button {
                        sendInvitation()
                    } label: {
                        HStack {
                            if isInviting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Send Invitation")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding()
                        .background(isFormValid ? Color.accentColor : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(!isFormValid || isInviting)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Invite Collaborator")
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
            .alert("Invitation Sent", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The invitation has been sent successfully!")
            }
        }
    }
    
    private func sendInvitation() {
        guard isFormValid else { return }
        
        isInviting = true
        
        Task {
            do {
                try await playlistService.inviteUserToPlaylist(
                    playlistId: playlist.id,
                    userEmail: userEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: selectedRole
                )
                
                DispatchQueue.main.async {
                    self.isInviting = false
                    self.showingSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInviting = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
}

struct PlaylistInfoView: View {
    let playlist: CollaborativePlaylist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(playlist.name)
                    .font(.headline)
                
                Spacer()
                
                PlaylistVisibilityBadge(visibility: playlist.visibility)
                PlaylistLicenseBadge(licenseType: playlist.editorLicenseType)
            }
            
            if !playlist.description.isEmpty {
                Text(playlist.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Text("\(playlist.trackCount) tracks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    InviteToPlaylistView(playlist: CollaborativePlaylist(
        name: "Test Playlist",
        description: "A test playlist for collaboration",
        creatorId: "user123",
        trackCount: 5
    ))
    .environmentObject(PlaylistService())
}
