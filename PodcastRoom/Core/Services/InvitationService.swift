import Foundation
import SwiftUI

@MainActor
class InvitationService: ObservableObject {
    @Published var sentInvitations: [EventInvitation] = []
    @Published var receivedInvitations: [EventInvitation] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let supabaseService = SupabaseService.shared
    
    // MARK: - Sending Invitations
    
    func sendInvitation(eventId: String, userEmail: String) async throws {
        isLoading = true
        error = nil
        
        do {
            try await supabaseService.sendEventInvitation(eventId: eventId, userEmail: userEmail)
            await fetchSentInvitations() // Refresh the list
        } catch {
            self.error = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func cancelInvitation(_ invitation: EventInvitation) async {
        isLoading = true
        error = nil
        
        do {
            try await supabaseService.cancelInvitation(invitationId: invitation.id)
            await fetchSentInvitations() // Refresh the list
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Receiving Invitations
    
    func acceptInvitation(_ invitation: EventInvitation) async {
        isLoading = true
        error = nil
        
        do {
            try await supabaseService.respondToInvitation(invitationId: invitation.id, status: InvitationStatus.accepted)
            await fetchReceivedInvitations() // Refresh the list
            
            // Notify that user events should be refreshed since the user now has access to a new private event
            NotificationCenter.default.post(
                name: NSNotification.Name("UserEventsNeedRefresh"), 
                object: nil
            )
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func declineInvitation(_ invitation: EventInvitation) async {
        isLoading = true
        error = nil
        
        do {
            try await supabaseService.respondToInvitation(invitationId: invitation.id, status: InvitationStatus.declined)
            await fetchReceivedInvitations() // Refresh the list
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Data Loading
    
    func fetchSentInvitations() async {
        isLoading = true
        error = nil
        
        do {
            sentInvitations = try await supabaseService.fetchSentInvitations()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func fetchReceivedInvitations() async {
        isLoading = true
        error = nil
        
        do {
            receivedInvitations = try await supabaseService.fetchReceivedInvitations()
            print("Debug - Successfully fetched \(receivedInvitations.count) received invitations")
        } catch {
            let errorMessage = "Failed to load invitations: \(error.localizedDescription)"
            print("Debug - \(errorMessage)")
            self.error = errorMessage
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    
    func getPendingInvitationsCount() -> Int {
        return receivedInvitations.filter { $0.status == .pending }.count
    }
    
    func hasPendingInvitations() -> Bool {
        return getPendingInvitationsCount() > 0
    }
    
    func getSentInvitationsFor(eventId: String) -> [EventInvitation] {
        return sentInvitations.filter { $0.eventId == eventId }
    }
    
    func getInvitationStatus(for eventId: String, userId: String) -> InvitationStatus? {
        return sentInvitations.first { $0.eventId == eventId && $0.userId == userId }?.status
    }
}
