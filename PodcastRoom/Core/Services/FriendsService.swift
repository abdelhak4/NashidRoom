import Foundation
import Supabase

class FriendsService: ObservableObject {
    private let supabase = SupabaseService.shared.client
    
    // MARK: - Friend Requests
    
    /// Send a friend request to another user
    func sendFriendRequest(to userId: String) async throws {
        guard let currentUserId = SupabaseService.shared.currentUser?.id else {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Prevent users from sending friend requests to themselves
        guard currentUserId != userId else {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You cannot send a friend request to yourself"])
        }
        
        // Check if friendship already exists
        let existingFriendshipResponse = try await supabase
            .from("friends")
            .select("id")
            .eq("user_id", value: currentUserId)
            .eq("friend_id", value: userId)
            .execute()
        
        let existingFriendshipData = existingFriendshipResponse.data
        let friendshipJsonArray = try JSONSerialization.jsonObject(with: existingFriendshipData, options: [])
        let existingFriendships = friendshipJsonArray as? [[String: Any]] ?? []
        
        if !existingFriendships.isEmpty {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You are already friends with this user"])
        }
        
        // Check if active (pending or accepted) friend request already exists
        let existingRequestResponse = try await supabase
            .from("friend_requests")
            .select("id, status")
            .or("requester_id.eq.\(currentUserId),recipient_id.eq.\(currentUserId)")
            .or("requester_id.eq.\(userId),recipient_id.eq.\(userId)")
            .neq("status", value: "declined")
            .execute()
        
        let existingRequestData = existingRequestResponse.data
        let requestJsonArray = try JSONSerialization.jsonObject(with: existingRequestData, options: [])
        let existingRequests = requestJsonArray as? [[String: Any]] ?? []
        
        if !existingRequests.isEmpty {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "A friend request already exists between you and this user"])
        }
        
        // Delete any declined friend requests between these users before creating a new one
        try await supabase
            .from("friend_requests")
            .delete()
            .or("requester_id.eq.\(currentUserId),recipient_id.eq.\(currentUserId)")
            .or("requester_id.eq.\(userId),recipient_id.eq.\(userId)")
            .eq("status", value: "declined")
            .execute()
        
        let friendRequest = FriendRequest(
            id: UUID().uuidString,
            requesterId: currentUserId,
            recipientId: userId,
            status: .pending,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await supabase
            .from("friend_requests")
            .insert(friendRequest)
            .execute()
    }
    
    /// Accept a friend request
    func acceptFriendRequest(requestId: String) async throws {
        guard let currentUserId = SupabaseService.shared.currentUser?.id else {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the friend request details first
        let response = try await supabase
            .from("friend_requests")
            .select("*")
            .eq("id", value: requestId)
            .single()
            .execute()
        
        let data = response.data
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let requestDict = jsonObject as? [String: Any] else {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse friend request"])
        }
        
        let requesterId = requestDict["requester_id"] as? String ?? ""
        let recipientId = requestDict["recipient_id"] as? String ?? ""
        
        // Verify that the current user is the recipient
        guard recipientId == currentUserId else {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You can only accept friend requests sent to you"])
        }
        
        // First, create the friendships manually (instead of relying on trigger)
        let friendship1 = Friend(
            id: UUID().uuidString,
            userId: requesterId,
            friendId: recipientId,
            status: .accepted,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let friendship2 = Friend(
            id: UUID().uuidString,
            userId: recipientId,
            friendId: requesterId,
            status: .accepted,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Insert friendships first
        try await supabase
            .from("friends")
            .insert([friendship1, friendship2])
            .execute()
        
        // Then update the request status to accepted
        try await supabase
            .from("friend_requests")
            .update(["status": "accepted", "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: requestId)
            .execute()
    }
    
    /// Decline a friend request
    func declineFriendRequest(requestId: String) async throws {
        // Delete the friend request instead of just updating its status
        try await supabase
            .from("friend_requests")
            .delete()
            .eq("id", value: requestId)
            .execute()
    }
    
    /// Cancel a friend request (for sender)
    func cancelFriendRequest(requestId: String) async throws {
        try await supabase
            .from("friend_requests")
            .delete()
            .eq("id", value: requestId)
            .execute()
    }
    
    /// Get received friend requests
    func getReceivedFriendRequests() async throws -> [FriendRequestWithUser] {
        guard let currentUserId = SupabaseService.shared.currentUser?.id else {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let response = try await supabase
            .from("friend_requests")
            .select("*, requester:requester_id(id, username, display_name, profile_image_url)")
            .eq("recipient_id", value: currentUserId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        
        // Parse the JSON data
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
            guard let requestDictionaries = jsonArray as? [[String: Any]] else {
                print("JSON is not an array of dictionaries: \(jsonArray)")
                return []
            }
            
            return try requestDictionaries.compactMap { dict in
                guard let requesterDict = dict["requester"] as? [String: Any] else { return nil }
                
                return FriendRequestWithUser(
                    requestId: dict["id"] as? String ?? "",
                    userId: requesterDict["id"] as? String ?? "",
                    username: requesterDict["username"] as? String ?? "",
                    displayName: requesterDict["display_name"] as? String,
                    profileImageURL: requesterDict["profile_image_url"] as? String,
                    createdAt: parseDate(from: dict["created_at"]) ?? Date()
                )
            }
        } catch {
            print("JSON parsing error: \(error)")
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse friend requests JSON: \(error.localizedDescription)"])
        }
    }
    
    /// Get sent friend requests
    func getSentFriendRequests() async throws -> [FriendRequestWithUser] {
        guard let currentUserId = SupabaseService.shared.currentUser?.id else {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let response = try await supabase
            .from("friend_requests")
            .select("*, recipient:recipient_id(id, username, display_name, profile_image_url)")
            .eq("requester_id", value: currentUserId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        
        // Parse the JSON data
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
            guard let requestDictionaries = jsonArray as? [[String: Any]] else {
                print("JSON is not an array of dictionaries: \(jsonArray)")
                return []
            }
            
            return try requestDictionaries.compactMap { dict in
                guard let recipientDict = dict["recipient"] as? [String: Any] else { return nil }
                
                return FriendRequestWithUser(
                    requestId: dict["id"] as? String ?? "",
                    userId: recipientDict["id"] as? String ?? "",
                    username: recipientDict["username"] as? String ?? "",
                    displayName: recipientDict["display_name"] as? String,
                    profileImageURL: recipientDict["profile_image_url"] as? String,
                    createdAt: parseDate(from: dict["created_at"]) ?? Date()
                )
            }
        } catch {
            print("JSON parsing error: \(error)")
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse friend requests JSON: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - Friends
    
    /// Get user's friends list
    func getFriends() async throws -> [FriendWithUser] {
        guard let currentUserId = SupabaseService.shared.currentUser?.id else {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let response = try await supabase
            .from("friends")
            .select("*, friend:friend_id(id, username, display_name, profile_image_url)")
            .eq("user_id", value: currentUserId)
            .eq("status", value: "accepted")
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        
        // Parse the JSON data
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
            guard let friendDictionaries = jsonArray as? [[String: Any]] else {
                print("JSON is not an array of dictionaries: \(jsonArray)")
                return []
            }
            
            return try friendDictionaries.compactMap { dict in
                guard let friendDict = dict["friend"] as? [String: Any] else { return nil }
                
                return FriendWithUser(
                    friendId: friendDict["id"] as? String ?? "",
                    username: friendDict["username"] as? String ?? "",
                    displayName: friendDict["display_name"] as? String,
                    profileImageURL: friendDict["profile_image_url"] as? String,
                    createdAt: parseDate(from: dict["created_at"]) ?? Date()
                )
            }
        } catch {
            print("JSON parsing error: \(error)")
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse friends JSON: \(error.localizedDescription)"])
        }
    }
    
    /// Remove a friend
    func removeFriend(friendId: String) async throws {
        guard let currentUserId = SupabaseService.shared.currentUser?.id else {
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Remove both directions of the friendship from the friends table
        try await supabase
            .from("friends")
            .delete()
            .or("user_id.eq.\(currentUserId),friend_id.eq.\(currentUserId)")
            .or("user_id.eq.\(friendId),friend_id.eq.\(friendId)")
            .execute()
            
        // Also remove any friend request entries between these two users from the friend_requests table
        try await supabase
            .from("friend_requests")
            .delete()
            .or("requester_id.eq.\(currentUserId),recipient_id.eq.\(currentUserId)")
            .or("requester_id.eq.\(friendId),recipient_id.eq.\(friendId)")
            .execute()
    }
    
    /// Search for users by username
    func searchUsers(query: String) async throws -> [User] {
        let response = try await supabase
            .from("users")
            .select("*")
            .ilike("username", pattern: "%\(query)%")
            .limit(20)
            .execute()
        
        let data = response.data
        
        // Parse the JSON data
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data, options: [])
            guard let userDictionaries = jsonArray as? [[String: Any]] else {
                print("JSON is not an array of dictionaries: \(jsonArray)")
                return []
            }
            
            return try userDictionaries.map { try User.from(dictionary: $0) }
        } catch {
            print("JSON parsing error: \(error)")
            throw NSError(domain: "FriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse users JSON: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseDate(from value: Any?) -> Date? {
        guard let dateString = value as? String else { return nil }
        
        let isoFormatter = ISO8601DateFormatter()
        let isoFormatterWithFractionalSeconds = ISO8601DateFormatter()
        isoFormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatterWithFractionalSeconds.date(from: dateString) {
            return date
        } else if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
}

// MARK: - Helper Models

struct FriendRequestWithUser: Codable, Identifiable {
    let requestId: String
    let userId: String
    let username: String
    let displayName: String?
    let profileImageURL: String?
    let createdAt: Date
    
    var id: String { requestId }
    
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case userId = "requester_id"
        case username
        case displayName = "display_name"
        case profileImageURL = "profile_image_url"
        case createdAt = "created_at"
    }
}

struct FriendWithUser: Codable, Identifiable {
    let friendId: String
    let username: String
    let displayName: String?
    let profileImageURL: String?
    let createdAt: Date
    
    var id: String { friendId }
    
    enum CodingKeys: String, CodingKey {
        case friendId = "friend_id"
        case username
        case displayName = "display_name"
        case profileImageURL = "profile_image_url"
        case createdAt = "created_at"
    }
}
