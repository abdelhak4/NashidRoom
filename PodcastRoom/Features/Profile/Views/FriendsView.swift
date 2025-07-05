import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @StateObject private var friendsService = FriendsService()
    @State private var friends: [FriendWithUser] = []
    @State private var friendRequests: [FriendRequestWithUser] = []
    @State private var sentRequests: [FriendRequestWithUser] = []
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var showingSearch = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Tab", selection: $selectedTab) {
                    Text("Friends").tag(0)
                    Text("Requests").tag(1)
                    Text("Sent").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Friends tab
                    friendsListView
                        .tag(0)
                    
                    // Received requests tab
                    receivedRequestsView
                        .tag(1)
                    
                    // Sent requests tab
                    sentRequestsView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSearch = true
                    }) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(Color.primaryText)
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                SearchUsersView(friendsService: friendsService)
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    // MARK: - Friends List View
    private var friendsListView: some View {
        List {
            ForEach(friends) { friend in
                FriendRowView(friend: friend) {
                    Task {
                        try? await friendsService.removeFriend(friendId: friend.friendId)
                        await loadFriends()
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await loadFriends()
        }
    }
    
    // MARK: - Received Requests View
    private var receivedRequestsView: some View {
        List {
            ForEach(friendRequests) { request in
                FriendRequestRowView(request: request) { action in
                    Task {
                        do {
                            switch action {
                            case .accept:
                                try await friendsService.acceptFriendRequest(requestId: request.requestId)
                            case .decline:
                                try await friendsService.declineFriendRequest(requestId: request.requestId)
                            }
                            // Refresh all lists after successful action
                            await loadData()
                        } catch {
                            print("Error handling friend request: \(error)")
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await loadFriendRequests()
        }
    }
    
    // MARK: - Sent Requests View
    private var sentRequestsView: some View {
        List {
            ForEach(sentRequests) { request in
                SentRequestRowView(request: request) {
                    Task {
                        try? await friendsService.cancelFriendRequest(requestId: request.requestId)
                        await loadSentRequests()
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await loadSentRequests()
        }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        Task {
            await loadFriends()
            await loadFriendRequests()
            await loadSentRequests()
        }
    }
    
    @MainActor
    private func loadFriends() async {
        do {
            friends = try await friendsService.getFriends()
        } catch {
            print("Failed to load friends: \(error)")
        }
    }
    
    @MainActor
    private func loadFriendRequests() async {
        do {
            friendRequests = try await friendsService.getReceivedFriendRequests()
        } catch {
            print("Failed to load friend requests: \(error)")
        }
    }
    
    @MainActor
    private func loadSentRequests() async {
        do {
            sentRequests = try await friendsService.getSentFriendRequests()
        } catch {
            print("Failed to load sent requests: \(error)")
        }
    }
}

// MARK: - Friend Row View
struct FriendRowView: View {
    let friend: FriendWithUser
    let onRemove: () -> Void
    @State private var showingRemoveAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if let profileImage = friend.profileImageURL, 
                   profileImage.contains("http") {
                    // Display actual image for URLs (Google sign in)
                    AsyncImage(url: URL(string: profileImage)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 46, height: 46)
                                .clipShape(Circle())
                        case .failure:
                            Text(friend.profileImageURL ?? "👤")
                                .font(.system(size: 24))
                        @unknown default:
                            Text(friend.profileImageURL ?? "👤")
                                .font(.system(size: 24))
                        }
                    }
                } else {
                    // Display emoji avatar
                    Text(friend.profileImageURL ?? "👤")
                        .font(.system(size: 24))
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName ?? friend.username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primaryText)
                
                Text("@\(friend.username)")
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondaryText)
            }
            
            Spacer()
            
            // Remove button
            Button(action: {
                showingRemoveAlert = true
            }) {
                Image(systemName: "person.badge.minus")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .alert("Remove Friend", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Are you sure you want to remove this friend?")
        }
    }
}

// MARK: - Friend Request Row View
struct FriendRequestRowView: View {
    let request: FriendRequestWithUser
    let onAction: (FriendRequestAction) -> Void
    
    enum FriendRequestAction {
        case accept, decline
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if let profileImage = request.profileImageURL, 
                   profileImage.contains("http") {
                    // Display actual image for URLs (Google sign in)
                    AsyncImage(url: URL(string: profileImage)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 46, height: 46)
                                .clipShape(Circle())
                        case .failure:
                            Text(request.profileImageURL ?? "👤")
                                .font(.system(size: 24))
                        @unknown default:
                            Text(request.profileImageURL ?? "👤")
                                .font(.system(size: 24))
                        }
                    }
                } else {
                    // Display emoji avatar
                    Text(request.profileImageURL ?? "👤")
                        .font(.system(size: 24))
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.displayName ?? request.username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primaryText)
                
                Text("@\(request.username)")
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondaryText)
            }
            
            Spacer()
            
            // Action buttons with explicit button style
            HStack(spacing: 12) {
                Button(action: {
                    onAction(.decline)
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    onAction(.accept)
                }) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // Limit touch area to prevent accidental taps
    }
}

// MARK: - Sent Request Row View
struct SentRequestRowView: View {
    let request: FriendRequestWithUser
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if let profileImage = request.profileImageURL, 
                   profileImage.contains("http") {
                    // Display actual image for URLs (Google sign in)
                    AsyncImage(url: URL(string: profileImage)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 46, height: 46)
                                .clipShape(Circle())
                        case .failure:
                            Text(request.profileImageURL ?? "👤")
                                .font(.system(size: 24))
                        @unknown default:
                            Text(request.profileImageURL ?? "👤")
                                .font(.system(size: 24))
                        }
                    }
                } else {
                    // Display emoji avatar
                    Text(request.profileImageURL ?? "👤")
                        .font(.system(size: 24))
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.displayName ?? request.username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primaryText)
                
                Text("@\(request.username)")
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondaryText)
                
                Text("Pending")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Search Users View
struct SearchUsersView: View {
    @Environment(\.dismiss) private var dismiss
    let friendsService: FriendsService
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.secondaryText)
                    
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                }
                .padding()
                .background(Color.inputBackground)
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Search results
                if isSearching {
                    ProgressView()
                        .padding()
                } else {
                    List(searchResults) { user in
                        UserSearchRowView(user: user, friendsService: friendsService)
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        Task {
            do {
                let results = try await friendsService.searchUsers(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                }
                print("Search failed: \(error)")
            }
        }
    }
}

// MARK: - User Search Row View
struct UserSearchRowView: View {
    let user: User
    let friendsService: FriendsService
    @State private var requestSent = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if let profileImage = user.profileImageURL, 
                   profileImage.contains("http") {
                    // Display actual image for URLs (Google sign in)
                    AsyncImage(url: URL(string: profileImage)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 46, height: 46)
                                .clipShape(Circle())
                        case .failure:
                            Text(user.profileImageURL ?? "👤")
                                .font(.system(size: 24))
                        @unknown default:
                            Text(user.profileImageURL ?? "👤")
                                .font(.system(size: 24))
                        }
                    }
                } else {
                    // Display emoji avatar
                    Text(user.profileImageURL ?? "👤")
                        .font(.system(size: 24))
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? user.username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primaryText)
                
                Text("@\(user.username)")
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondaryText)
            }
            
            Spacer()
            
            // Add friend button
            Button(action: {
                sendFriendRequest()
            }) {
                if requestSent {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Sent")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }
                } else {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.blue)
                }
            }
            .disabled(requestSent)
        }
        .padding(.vertical, 8)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sendFriendRequest() {
        Task {
            do {
                try await friendsService.sendFriendRequest(to: user.id)
                await MainActor.run {
                    requestSent = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
                print("Failed to send friend request: \(error)")
            }
        }
    }
}

#Preview {
    FriendsView()
        .environmentObject(AuthenticationViewModel())
}
