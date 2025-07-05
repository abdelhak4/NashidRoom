import SwiftUI

struct ReceivedInvitationsView: View {
    @StateObject private var invitationService = InvitationService()
    @StateObject private var playlistService = PlaylistService()
    @State private var selectedSegment = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("Invitation Type", selection: $selectedSegment) {
                Text("Events").tag(0)
                Text("Playlists").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content
            Group {
                if selectedSegment == 0 {
                    eventInvitationsView
                } else {
                    playlistInvitationsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Invitations")
        .refreshable {
            await refreshInvitations()
        }
        .task {
            await loadInvitations()
        }
        .alert("Error", isPresented: .constant(hasError)) {
            Button("OK") { 
                clearErrors()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Event Invitations
    private var eventInvitationsView: some View {
        Group {
            if invitationService.isLoading {
                ProgressView("Loading invitations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if invitationService.receivedInvitations.isEmpty {
                EmptyInvitationsView(type: .events)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(invitationService.receivedInvitations) { invitation in
                            UnifiedInvitationCard(
                                invitation: invitation,
                                onAccept: { 
                                    Task { await invitationService.acceptInvitation(invitation) }
                                },
                                onDecline: { 
                                    Task { await invitationService.declineInvitation(invitation) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Playlist Invitations
    private var playlistInvitationsView: some View {
        Group {
            if playlistService.isLoading {
                ProgressView("Loading invitations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if playlistService.playlistInvitations.isEmpty {
                EmptyInvitationsView(type: .playlists)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(playlistService.playlistInvitations) { invitation in
                            UnifiedInvitationCard(
                                invitation: invitation,
                                onAccept: { 
                                    Task { 
                                        try await playlistService.respondToPlaylistInvitation(invitation, accept: true)
                                    }
                                },
                                onDecline: { 
                                    Task { 
                                        try await playlistService.respondToPlaylistInvitation(invitation, accept: false)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadInvitations() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await invitationService.fetchReceivedInvitations() }
            group.addTask { await playlistService.fetchPlaylistInvitations() }
        }
    }
    
    private func refreshInvitations() async {
        if selectedSegment == 0 {
            await invitationService.fetchReceivedInvitations()
        } else {
            await playlistService.fetchPlaylistInvitations()
        }
    }
    
    private var hasError: Bool {
        invitationService.error != nil || playlistService.error != nil
    }
    
    private var errorMessage: String {
        invitationService.error ?? playlistService.error ?? ""
    }
    
    private func clearErrors() {
        invitationService.error = nil
        playlistService.error = nil
    }
}

// This view is now handled by the shared InvitationComponents.swift file

#Preview {
    ReceivedInvitationsView()
}
