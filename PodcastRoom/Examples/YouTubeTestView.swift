import SwiftUI

struct YouTubeTestView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var showingFullPlayer = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("YouTube Player Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Test buttons for different YouTube videos
                VStack(spacing: 16) {
                    Button("Test Video 1 (Music)") {
                        playTestTrack(
                            title: "Test Song 1",
                            artist: "Test Artist",
                            videoId: "dQw4w9WgXcQ" // Rick Roll for testing
                        )
                        showingFullPlayer = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test Video 2 (Music)") {
                        playTestTrack(
                            title: "Test Song 2", 
                            artist: "Test Artist 2",
                            videoId: "kJQP7kiw5Fk" // Despacito
                        )
                        showingFullPlayer = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Clear Player") {
                        audioPlayer.stop()
                        audioPlayer.currentTrack = nil
                        audioPlayer.currentQueue = []
                    }
                    .buttonStyle(.bordered)
                }
                
                // Show current track info
                if let track = audioPlayer.currentTrack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Track:")
                            .font(.headline)
                        Text("Title: \(track.title)")
                        Text("Artist: \(track.artist)")
                        Text("YouTube ID: \(track.youtubeVideoId ?? "none")")
                        Text("State: \(stateString(audioPlayer.playbackState))")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("YouTube Test")
        }
        .fullScreenCover(isPresented: $showingFullPlayer) {
            MusicPlayerView()
        }
    }
    
    private func playTestTrack(title: String, artist: String, videoId: String) {
        let track = Track(
            id: UUID().uuidString,
            title: title,
            artist: artist,
            album: "Test Album",
            duration: 180,
            artworkURL: nil,
            previewURL: nil,
            youtubeVideoId: videoId,
            youtubeURL: "https://www.youtube.com/watch?v=\(videoId)"
        )
        
        audioPlayer.setQueue([track], startIndex: 0, source: .none)
        audioPlayer.playTrack(track)
    }
    
    private func stateString(_ state: PlaybackState) -> String {
        switch state {
        case .stopped: return "Stopped"
        case .loading: return "Loading"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .buffering: return "Buffering"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

#Preview {
    YouTubeTestView()
}
