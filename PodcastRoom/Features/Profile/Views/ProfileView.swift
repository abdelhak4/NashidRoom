import SwiftUI



struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var showChangeProfile = false
    @State private var showThemeSettings = false
    @State private var showPrivacySettings = false
    @State private var showAbout = false
    @State private var showFriends = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Profile section
                    profileSection
                    
                    // Menu options
                    menuOptionsSection
                    
                    Spacer(minLength: 100) // Space for tab bar
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }
        }
        .sheet(isPresented: $showChangeProfile) {
            ChangeProfileView()
        }
        .sheet(isPresented: $showThemeSettings) {
            ThemeSettingsView()
        }
        .sheet(isPresented: $showPrivacySettings) {
            PrivacySettingsView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showFriends) {
            FriendsView()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {            
            Text("Profile")
                .font(Font.system(size: 22, weight: .bold))
                .foregroundColor(ThemeColor.primaryText.color)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(Font.system(size: 24, weight: .medium))
                    .foregroundColor(ThemeColor.primaryText.color)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: 20) {
            // Profile avatar (emoji style like in image or actual image if available)
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                if let profileImage = authViewModel.currentUser?.profileImageURL,
                   profileImage.contains("http") {
                    // Display actual image for URLs (Google sign in)
                    AsyncImage(url: URL(string: profileImage)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                        case .failure:
                            Text("👩‍🦰") // Fallback emoji
                                .font(Font.system(size: 60))
                        @unknown default:
                            Text("👩‍🦰") // Fallback emoji
                                .font(Font.system(size: 60))
                        }
                    }
                } else {
                    // Display emoji avatar
                    Text(authViewModel.currentUser?.profileImageURL ?? "👩‍🦰")
                        .font(Font.system(size: 60))
                }
            }
            
            // User info
            VStack(spacing: 8) {
                Text(authViewModel.currentUser?.displayName ?? authViewModel.currentUser?.username ?? "User")
                    .font(Font.system(size: 20, weight: .semibold))
                    .foregroundColor(ThemeColor.primaryText.color)
                
                if let username = authViewModel.currentUser?.username {
                    Text("@\(username)")
                        .font(Font.system(size: 16))
                        .foregroundColor(ThemeColor.secondaryText.color)
                }
                
                if let bio = authViewModel.currentUser?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Font.system(size: 14))
                        .foregroundColor(ThemeColor.primaryText.color)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
                // Location and website
                HStack(spacing: 16) {
                    if let location = authViewModel.currentUser?.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(Font.system(size: 12))
                                .foregroundColor(ThemeColor.secondaryText.color)
                            Text(location)
                                .font(Font.system(size: 14))
                                .foregroundColor(ThemeColor.secondaryText.color)
                        }
                    }
                    
                    if let website = authViewModel.currentUser?.website, !website.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(Font.system(size: 12))
                                .foregroundColor(ThemeColor.secondaryText.color)
                            Text(website)
                                .font(Font.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Change Profile button
            Button(action: {
                showChangeProfile = true
            }) {
                Text("Edit Profile")
                    .font(Font.system(size: 16, weight: .medium))
                    .foregroundColor(ThemeColor.primaryText.color)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ThemeColor.inputBackground.color)
                    .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Menu Options Section
    private var menuOptionsSection: some View {
        VStack(spacing: 20) {
            // Friends
            ProfileMenuButton(
                iconName: "person.2.fill",
                iconColor: .green,
                title: "Friends",
                action: {
                    showFriends = true
                }
            )
            
            // Change Theme
            ProfileMenuButton(
                iconName: "paintbrush.fill",
                iconColor: .orange,
                title: "Change Theme",
                action: {
                    showThemeSettings = true
                }
            )
            
            // Privacy
            ProfileMenuButton(
                iconName: "lock.fill",
                iconColor: .purple,
                title: "Privacy",
                action: {
                    showPrivacySettings = true
                }
            )
            
            // About
            ProfileMenuButton(
                iconName: "info.circle.fill",
                iconColor: .blue,
                title: "About",
                action: {
                    showAbout = true
                }
            )
            
            // Logout
            ProfileMenuButton(
                iconName: "rectangle.portrait.and.arrow.right.fill",
                iconColor: .red,
                title: "Logout",
                action: {
                    Task {
                        await authViewModel.logout()
                    }
                }
            )
        }
    }
}

// MARK: - Profile Menu Button
struct ProfileMenuButton: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(Font.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                // Title
                Text(title)
                    .font(Font.system(size: 16, weight: .medium))
                    .foregroundColor(ThemeColor.primaryText.color)
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(Font.system(size: 14, weight: .medium))
                    .foregroundColor(ThemeColor.tertiaryText.color)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Change Profile View
struct ChangeProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var website = ""
    @State private var phoneNumber = ""
    @State private var dateOfBirth = Date()
    @State private var selectedEmoji = "👩‍🦰"
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showDatePicker = false
    
    let emojiOptions = ["👩‍🦰", "👨‍💼", "👩‍💻", "👨‍🎨", "👩‍🚀", "👨‍🔬", "👩‍⚕️", "👨‍🏫"]
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColor.appBackground.color
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Current avatar
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                
                                if selectedEmoji.contains("http") {
                                    // Display actual image for URLs (Google sign in)
                                    AsyncImage(url: URL(string: selectedEmoji)) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 110, height: 110)
                                                .clipShape(Circle())
                                        case .failure:
                                            Text("👩‍🦰") // Fallback emoji
                                                .font(Font.system(size: 60))
                                        @unknown default:
                                            Text("👩‍🦰") // Fallback emoji
                                                .font(Font.system(size: 60))
                                        }
                                    }
                                } else {
                                    // Display emoji avatar
                                    Text(selectedEmoji)
                                        .font(Font.system(size: 60))
                                }
                            }
                            Spacer()
                        }
                        
                        // Emoji selection - Only show if not using a Google profile image
                        if !selectedEmoji.contains("http") {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Choose Avatar")
                                    .font(Font.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeColor.primaryText.color)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(emojiOptions, id: \.self) { emoji in
                                        Button(action: {
                                            selectedEmoji = emoji
                                        }) {
                                            Text(emoji)
                                                .font(Font.system(size: 30))
                                                .frame(width: 60, height: 60)
                                                .background(
                                                    selectedEmoji == emoji ?
                                                    Color.white.opacity(0.2) : Color.clear
                                                )
                                                .cornerRadius(15)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Form fields
                        VStack(spacing: 20) {
                            // Username field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(Font.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeColor.primaryText.color)
                                
                                TextField("Enter username", text: $username)
                                    .foregroundColor(ThemeColor.primaryText.color)
                                    .padding()
                                    .background(ThemeColor.inputBackground.color)
                                    .cornerRadius(12)
                            }
                            
                            // Display Name field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(Font.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeColor.primaryText.color)
                                
                                TextField("Enter display name", text: $displayName)
                                    .foregroundColor(ThemeColor.primaryText.color)
                                    .padding()
                                    .background(ThemeColor.inputBackground.color)
                                    .cornerRadius(12)
                            }
                            
                            // Bio field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bio")
                                    .font(Font.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeColor.primaryText.color)
                                
                                TextField("Tell us about yourself", text: $bio, axis: .vertical)
                                    .foregroundColor(ThemeColor.primaryText.color)
                                    .padding()
                                    .background(ThemeColor.inputBackground.color)
                                    .cornerRadius(12)
                                    .lineLimit(3...6)
                            }
                            
                            // Location field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location")
                                    .font(Font.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeColor.primaryText.color)
                                
                                TextField("Enter your location", text: $location)
                                    .foregroundColor(ThemeColor.primaryText.color)
                                    .padding()
                                    .background(ThemeColor.inputBackground.color)
                                    .cornerRadius(12)
                            }
                            
                            // Website field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Website")
                                    .font(Font.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeColor.primaryText.color)
                                
                                TextField("Enter your website URL", text: $website)
                                    .foregroundColor(ThemeColor.primaryText.color)
                                    .padding()
                                    .background(ThemeColor.inputBackground.color)
                                    .cornerRadius(12)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }
                            
                            // Phone Number field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone Number")
                                    .font(Font.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeColor.primaryText.color)
                                
                                TextField("Enter your phone number", text: $phoneNumber)
                                    .foregroundColor(ThemeColor.primaryText.color)
                                    .padding()
                                    .background(ThemeColor.inputBackground.color)
                                    .cornerRadius(12)
                                    .keyboardType(.phonePad)
                            }
                            
                            // Date of Birth field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date of Birth")
                                    .font(Font.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeColor.primaryText.color)
                                
                                Button(action: {
                                    showDatePicker.toggle()
                                }) {
                                    HStack {
                                        Text(dateOfBirth, style: .date)
                                            .foregroundColor(ThemeColor.primaryText.color)
                                        Spacer()
                                        Image(systemName: "calendar")
                                            .foregroundColor(ThemeColor.secondaryText.color)
                                    }
                                    .padding()
                                    .background(ThemeColor.inputBackground.color)
                                    .cornerRadius(12)
                                }
                                .sheet(isPresented: $showDatePicker) {
                                    DatePickerView(selectedDate: $dateOfBirth)
                                }
                            }
                        }
                        
                        // Error message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(Font.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        // Save button
                        Button(action: {
                            Task {
                                await saveProfile()
                            }
                        }) {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: ThemeColor.primaryBackground.color))
                                        .scaleEffect(0.8)
                                    Text("Saving...")
                                        .font(Font.system(size: 16, weight: .semibold))
                                        .foregroundColor(ThemeColor.primaryBackground.color)
                                }
                            } else {
                                Text("Save Changes")
                                    .font(Font.system(size: 16, weight: .semibold))
                                    .foregroundColor(ThemeColor.primaryBackground.color)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ThemeColor.primaryText.color)
                        .cornerRadius(12)
                        .disabled(isLoading)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColor.primaryText.color)
                }
            })
            .onAppear {
                loadCurrentUserData()
            }
        }
    }
    
    private func loadCurrentUserData() {
        guard let user = authViewModel.currentUser else { return }
        
        username = user.username
        displayName = user.displayName ?? ""
        bio = user.bio ?? ""
        location = user.location ?? ""
        website = user.website ?? ""
        phoneNumber = user.phoneNumber ?? ""
        selectedEmoji = user.profileImageURL ?? "👩‍🦰"
        
        if let birthDate = user.dateOfBirth {
            dateOfBirth = birthDate
        }
    }
    
    private func saveProfile() async {
        isLoading = true
        errorMessage = ""
        
        do {
            // Preserve existing profile image URL if it's a Google URL
            let profileImageURL: String? 
            if let currentImageURL = authViewModel.currentUser?.profileImageURL, 
               currentImageURL.contains("http") {
                profileImageURL = currentImageURL // Keep Google image URL
            } else {
                profileImageURL = selectedEmoji // Use selected emoji
            }
            
            // Update user profile using SupabaseService
            let updatedUser = User(
                id: authViewModel.currentUser?.id ?? "",
                username: username,
                email: authViewModel.currentUser?.email ?? "",
                profileImageURL: profileImageURL,
                displayName: displayName.isEmpty ? nil : displayName,
                bio: bio.isEmpty ? nil : bio,
                location: location.isEmpty ? nil : location,
                dateOfBirth: dateOfBirth,
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                website: website.isEmpty ? nil : website,
                spotifyConnected: authViewModel.currentUser?.spotifyConnected ?? false,
                youtubeConnected: authViewModel.currentUser?.youtubeConnected ?? true,
                licenseType: authViewModel.currentUser?.licenseType ?? .free,
                createdAt: authViewModel.currentUser?.createdAt ?? Date(),
                updatedAt: Date()
            )
            
            try await SupabaseService.shared.updateUserProfile(user: updatedUser)
            
            // Update the current user in auth view model
            await MainActor.run {
                authViewModel.currentUser = updatedUser
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
}

// MARK: - Date Picker View
struct DatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(WheelDatePickerStyle())
                .padding()
                
                Spacer()
            }
            .navigationTitle("Date of Birth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColor.primaryText.color)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColor.primaryText.color)
                }
            })
        }
    }
}

// MARK: - Theme Settings View
struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColor.appBackground.color
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(theme.rawValue)
                                    .font(Font.system(size: 16, weight: .medium))
                                    .foregroundColor(ThemeColor.primaryText.color)
                                
                                Text(themeDescription(for: theme))
                                    .font(Font.system(size: 14))
                                    .foregroundColor(ThemeColor.secondaryText.color)
                            }
                            
                            Spacer()
                            
                            if themeManager.selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                                    .font(Font.system(size: 16, weight: .semibold))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            themeManager.setTheme(theme)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Theme Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColor.primaryText.color)
                }
            })
        }
    }
    
    private func themeDescription(for theme: AppTheme) -> String {
        switch theme {
        case .light:
            return "Always use light mode"
        case .dark:
            return "Always use dark mode"
        case .auto:
            return "Follow system setting"
        }
    }
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColor.appBackground.color
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy settings and data management options would be implemented here.")
                        .font(Font.system(size: 16))
                        .foregroundColor(ThemeColor.primaryText.color)
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColor.primaryText.color)
                }
            })
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColor.appBackground.color
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("PodRoom")
                            .font(Font.system(size: 24, weight: .bold))
                            .foregroundColor(ThemeColor.primaryText.color)
                        
                        Text("Version 1.0.0")
                            .font(Font.system(size: 16))
                            .foregroundColor(ThemeColor.secondaryText.color)
                        
                        Text("A modern podcast app designed for seamless listening experiences.")
                            .font(Font.system(size: 16))
                            .foregroundColor(ThemeColor.primaryText.color)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColor.primaryText.color)
                }
            })
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationViewModel())
}
