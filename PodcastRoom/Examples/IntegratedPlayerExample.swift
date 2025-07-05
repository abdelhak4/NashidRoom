import SwiftUI

// Example of how to integrate the music player into your existing views
// Note: These are example implementations - use your actual views in production

struct ExampleMainTabView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    var body: some View {
        TabView {
            ExampleExploreView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Explore")
                }
            
            ExampleLibraryView()
                .tabItem {
                    Image(systemName: "music.note.list")
                    Text("Library")
                }
            
            ExampleEventsView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Events")
                }
            
            ExampleProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
        }
    }
}

struct ExampleExploreView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                Text("Explore Content")
                    .padding()
            }
            .navigationTitle("Explore")
        }
    }
}

struct ExampleLibraryView: View {
    @StateObject private var playlistService = PlaylistService()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(playlistService.playlists) { playlist in
                    NavigationLink(destination: PlaylistPlayerView(playlist: playlist)) {
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "music.note.list")
                                        .foregroundColor(.blue)
                                )
                            
                            VStack(alignment: .leading) {
                                Text(playlist.name)
                                    .font(.headline)
                                Text("\(playlist.trackCount) tracks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Library")
        }
        .task {
            await playlistService.fetchPlaylists()
        }
    }
}

struct ExampleEventsView: View {
    @StateObject private var eventService = EventService()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(eventService.events) { event in
                    ExampleEventRowView(event: event)
                }
            }
            .navigationTitle("Events")
        }
        .task {
            await eventService.fetchPublicEvents()
        }
    }
}

struct ExampleEventRowView: View {
    let event: Event
    @StateObject private var eventService = EventService()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(event.name)
                        .font(.headline)
                    Text(event.description ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await eventService.playEvent(event)
                    }
                } label: {
                    Image(systemName: "play.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            
            // Show current track if this event is playing
            if case .event(let eventId) = audioPlayer.queueSource,
               eventId == event.id,
               let currentTrack = audioPlayer.currentTrack {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Now playing: \(currentTrack.title)")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExampleProfileView: View {
    var body: some View {
        NavigationView {
            Text("Profile Content")
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Usage Examples

struct ExamplePlaylistRowWithPlayButton: View {
    let playlist: CollaborativePlaylist
    @StateObject private var playlistService = PlaylistService()
    
    var body: some View {
        HStack {
            // Playlist info
            VStack(alignment: .leading) {
                Text(playlist.name)
                    .font(.headline)
                Text("\(playlist.trackCount) tracks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quick play button
            Button {
                Task {
                    await playlistService.playPlaylist(playlist)
                }
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        }
    }
}

struct ExampleTrackRowWithControls: View {
    let track: Track
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    var body: some View {
        HStack {
            // Track info
            VStack(alignment: .leading) {
                Text(track.title)
                    .font(.subheadline)
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quick actions
            HStack {
                Button {
                    audioPlayer.playTrack(track)
                } label: {
                    Image(systemName: "play")
                }
                
                Button {
                    audioPlayer.addToQueue(track)
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                
                Button {
                    audioPlayer.insertNext(track)
                } label: {
                    Image(systemName: "text.insert")
                }
            }
            .font(.caption)
            .foregroundColor(.accentColor)
        }
    }
}

#Preview {
    ExampleMainTabView()
}
