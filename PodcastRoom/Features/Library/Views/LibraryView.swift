import SwiftUI

struct LibraryView: View {
    @State private var showCreatePlaylist = false
    
    // Mock data for recently played podcasts
    let recentlyPlayed = [
        PodcastEpisode(
            title: "Podcast Medoan",
            author: "Claire Malone",
            duration: "34:00",
            currentTime: "Today",
            imageURL: "podcast1",
            backgroundColor: Color.orange,
            isRecentlyPlayed: true,
            playProgress: 0.7
        ),
        PodcastEpisode(
            title: "Podcast Antono",
            author: "Unknown Artist",
            duration: "28:15",
            currentTime: "Yesterday",
            imageURL: "podcast2",
            backgroundColor: Color.blue,
            isRecentlyPlayed: true,
            playProgress: 0.3
        ),
        PodcastEpisode(
            title: "Podcast Medoan",
            author: "Ty McDuff",
            duration: "45:22",
            currentTime: "Yesterday",
            imageURL: "podcast3",
            backgroundColor: Color.orange,
            isRecentlyPlayed: true,
            playProgress: 0.9
        )
    ]
    
    // Mock playlists
    let playlists = [
        Playlist(
            name: "Kumpulan Kocakers",
            description: "4 Channel • 20 Playlist",
            imageURL: "playlist1",
            backgroundColor: Color.blue,
            episodeCount: 20
        ),
        Playlist(
            name: "Membagongkan",
            description: "6 Channel • 15 Playlist",
            imageURL: "playlist2",
            backgroundColor: Color.red,
            episodeCount: 15
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    // Recently played section
                    recentlyPlayedSection
                    
                    // Your playlist section
                    yourPlaylistSection
                    
                    Spacer(minLength: 100) // Space for tab bar
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showCreatePlaylist) {
            CreatePlaylistView()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("Library")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.primaryText)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color.primaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Recently Played Section
    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Played recently")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            VStack(spacing: 16) {
                ForEach(recentlyPlayed) { episode in
                    RecentlyPlayedCard(episode: episode)
                }
            }
        }
    }
    
    // MARK: - Your Playlist Section
    private var yourPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your playlist")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            
            // Create Playlist Button
            Button(action: {
                showCreatePlaylist = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color.primaryText)
                        .frame(width: 40, height: 40)
                        .background(Color.inputBackground)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create Playlist")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.primaryText)
                        
                        Text("Make your own playlist")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.secondaryText)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Playlists
            VStack(spacing: 16) {
                ForEach(playlists) { playlist in
                    PlaylistCard(playlist: playlist)
                }
            }
        }
    }
}

// MARK: - Recently Played Card
struct RecentlyPlayedCard: View {
    let episode: PodcastEpisode
    
    var body: some View {
        HStack(spacing: 12) {
            // Episode artwork
            ZStack {
                Rectangle()
                    .fill(episode.backgroundColor)
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Episode info
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.primaryText)
                    .lineLimit(1)
                
                Text(episode.currentTime)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.secondaryText)
            }
            
            Spacer()
            
            // More button
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Playlist Card
struct PlaylistCard: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 12) {
            // Playlist artwork
            ZStack {
                Rectangle()
                    .fill(playlist.backgroundColor)
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.primaryText)
                    .lineLimit(1)
                
                Text(playlist.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.secondaryText)
            }
            
            Spacer()
            
            // More button
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Playlist View
struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playlistName = ""
    @State private var playlistDescription = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Playlist Name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.primaryText)
                        
                        TextField("Enter playlist name", text: $playlistName)
                            .foregroundColor(Color.primaryText)
                            .padding()
                            .background(Color.inputBackground)
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Description")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.primaryText)
                        
                        TextField("Enter description", text: $playlistDescription)
                            .foregroundColor(Color.primaryText)
                            .padding()
                            .background(Color.inputBackground)
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Create Playlist")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Create Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.primaryText)
                }
            }
        }
    }
}

#Preview {
    LibraryView()
} 