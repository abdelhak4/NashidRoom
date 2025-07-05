import SwiftUI

struct InvitationManagementView: View {
    let event: Event
    @StateObject private var invitationService = InvitationService()
    @ObservedObject private var supabaseService = SupabaseService.shared
    @State private var showingInviteSheet = false
    @State private var newUserEmail = ""
    @State private var isLoading = false
    
    private var isHost: Bool {
        guard let currentUser = supabaseService.currentUser else {
            return false
        }
        return currentUser.id == event.hostId
    }
    
    var body: some View {
        NavigationView {
            if !isHost {
                // Show access denied view for non-hosts
                VStack(spacing: 20) {
                    Image(systemName: "lock.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Access Denied")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Only the event host can manage invitations.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .navigationTitle("Manage Invitations")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                VStack(spacing: 0) {
                    // Header
                    HeaderView(event: event)
                    
                    // Invitation list
                    if invitationService.sentInvitations.isEmpty && !invitationService.isLoading {
                        EmptyStateView()
                    } else {
                        InvitationListView(
                            invitations: invitationService.sentInvitations,
                            onCancel: { invitation in
                                Task {
                                    await invitationService.cancelInvitation(invitation)
                                }
                            }
                        )
                    }
                    
                    Spacer()
                    
                    // Invite button
                    Button(action: { showingInviteSheet = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Invite People")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding()
                }
                .navigationTitle("Manage Invitations")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showingInviteSheet) {
                    InviteUserSheet(
                        eventId: event.id,
                        onInvite: { email in
                            Task {
                                try await invitationService.sendInvitation(eventId: event.id, userEmail: email)
                            }
                        }
                    )
                }
                .task {
                    await invitationService.fetchSentInvitations()
                }
                .alert("Error", isPresented: .constant(invitationService.error != nil)) {
                    Button("OK") { invitationService.error = nil }
                } message: {
                    if let error = invitationService.error {
                        Text(error)
                    }
                }
            }
        }
    }
}

struct HeaderView: View {
    let event: Event
    
    var body: some View {
        VStack(spacing: 12) {
            Text(event.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            HStack {
                EventVisibilityBadge(visibility: event.visibility)
                LicenseTypeBadge(licenseType: event.licenseType)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Invitations Sent")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Invite people to join your private event")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

struct InvitationListView: View {
    let invitations: [EventInvitation]
    let onCancel: (EventInvitation) -> Void
    
    var body: some View {
        List {
            ForEach(invitations) { invitation in
                InvitationRowView(
                    invitation: invitation,
                    onCancel: { onCancel(invitation) }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct InvitationRowView: View {
    let invitation: EventInvitation
    let onCancel: () -> Void
    @State private var showingCancelAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.userEmail ?? "Unknown User")
                    .font(.headline)
                
                Text("Invited \(formatDate(invitation.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: invitation.status)
                
                if invitation.status == .pending {
                    Button("Cancel") {
                        showingCancelAlert = true
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
        .alert("Cancel Invitation", isPresented: $showingCancelAlert) {
            Button("Cancel", role: .destructive) {
                onCancel()
            }
            Button("Keep", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel this invitation?")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// StatusBadge is now imported from shared InvitationComponents

struct InviteUserSheet: View {
    let eventId: String
    let onInvite: (String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var emailText = ""
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Invite Someone")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.headline)
                    
                    TextField("Enter email address", text: $emailText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal)
                
                Button(action: sendInvitation) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Invitation")
                    }
                }
                .disabled(emailText.isEmpty || isLoading)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(emailText.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
        }
    }
    
    private func sendInvitation() {
        guard !emailText.isEmpty else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                try await onInvite(emailText.trimmingCharacters(in: .whitespacesAndNewlines))
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    InvitationManagementView(event: Event(
        name: "Test Event",
        description: "A test event",
        hostId: "host123",
        visibility: .private,
        licenseType: .premium,
        spotifyPlaylistId: "playlist123"
    ))
}
