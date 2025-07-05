import SwiftUI

// MARK: - Status Badge
struct StatusBadge: View {
    let status: InvitationStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(8)
    }
}

// MARK: - Unified Invitation Card
struct UnifiedInvitationCard<T: UnifiedInvitation>: View {
    let invitation: T
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var showingDeclineAlert = false
    @State private var isResponding = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(invitation.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let inviterName = invitation.inviterName {
                        Text("Invited by \(inviterName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDate(invitation.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    StatusBadge(status: invitation.status)
                }
            }
            
            // Action buttons (only show for pending invitations)
            if invitation.status == .pending {
                HStack(spacing: 12) {
                    Button {
                        showingDeclineAlert = true
                    } label: {
                        Text("Decline")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                    }
                    .disabled(isResponding)
                    
                    Button {
                        respondToInvitation(accept: true)
                    } label: {
                        HStack {
                            if isResponding {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Accept")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                    }
                    .disabled(isResponding)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(invitation.status == .pending ? Color(.systemGray6) : Color(.systemGray6).opacity(0.7))
        .cornerRadius(12)
        .opacity(invitation.status == .pending ? 1.0 : 0.8)
        .alert("Decline Invitation", isPresented: $showingDeclineAlert) {
            Button("Decline", role: .destructive) {
                respondToInvitation(accept: false)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to decline this invitation?")
        }
    }
    
    private func respondToInvitation(accept: Bool) {
        isResponding = true
        
        Task {
            if accept {
                onAccept()
            } else {
                onDecline()
            }
            
            await MainActor.run {
                self.isResponding = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Empty State View
struct EmptyInvitationsView: View {
    let type: InvitationType
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon with background circle
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                    
                    Image(systemName: type.iconName)
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary)
                }
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                VStack(spacing: 12) {
                    Text(type.emptyTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(type.emptyMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}

enum InvitationType {
    case events
    case playlists
    
    var iconName: String {
        switch self {
        case .events: return "envelope.open"
        case .playlists: return "music.note.list"
        }
    }
    
    var emptyTitle: String {
        switch self {
        case .events: return "No Event Invitations"
        case .playlists: return "No Playlist Invitations"
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .events: return "When someone invites you to an event, you'll see it here. Stay tuned for exciting musical gatherings!"
        case .playlists: return "When someone invites you to collaborate on a playlist, you'll see it here. Start creating music together!"
        }
    }
} 