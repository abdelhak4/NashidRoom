import SwiftUI

struct MusicPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var showQueue = false
    @State private var isDraggingSlider = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main Player Area
                if let track = audioPlayer.currentTrack {
                    playerContent(track: track)
                } else {
                    emptyPlayerContent
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
    }
    
    @ViewBuilder
    private func playerContent(track: Track) -> some View {
        VStack(spacing: 20) {
            // YouTube Player
            if let videoId = track.youtubeVideoId {
                YouTubePlayerView(videoId: videoId)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .id("youtube-player-\(videoId)") // Force recreate when video ID changes
            } else {
                // Fallback artwork view for tracks without YouTube video
                AsyncImage(url: URL(string: track.artworkURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        )
                }
                .frame(height: 200)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Track Info
            VStack(spacing: 8) {
                Text(track.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .padding(.horizontal)
            
            // Progress Slider
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { audioPlayer.currentTime },
                        set: { newValue in
                            if !isDraggingSlider {
                                audioPlayer.seek(to: newValue)
                            }
                        }
                    ),
                    in: 0...max(audioPlayer.duration, 1),
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            audioPlayer.seek(to: audioPlayer.currentTime)
                        }
                    }
                )
                .accentColor(.primary)
                
                HStack {
                    Text(formatTime(audioPlayer.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTime(audioPlayer.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Playback Controls
            HStack(spacing: 40) {
                // Previous
                Button {
                    audioPlayer.playPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundColor(.primary)
                }
                
                // Play/Pause
                Button {
                    print("🎵 MusicPlayerView: Play/Pause button tapped - current state: \(audioPlayer.playbackState)")
                    switch audioPlayer.playbackState {
                    case .playing:
                        print("🎵 MusicPlayerView: Calling pause()")
                        audioPlayer.pause()
                    case .paused, .stopped:
                        print("🎵 MusicPlayerView: Calling play()")
                        audioPlayer.play()
                    default:
                        print("🎵 MusicPlayerView: Playback state not handled: \(audioPlayer.playbackState)")
                        break
                    }
                } label: {
                    Group {
                        switch audioPlayer.playbackState {
                        case .playing:
                            Image(systemName: "pause.circle.fill")
                        case .loading, .buffering:
                            ProgressView()
                                .scaleEffect(0.8)
                        default:
                            Image(systemName: "play.circle.fill")
                        }
                    }
                    .font(.system(size: 50))
                }
                .disabled(audioPlayer.playbackState == .loading || audioPlayer.playbackState == .buffering)
                
                // Next
                Button {
                    audioPlayer.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            // Queue Control
            HStack {
                Spacer()
                
                // Queue
                Button {
                    showQueue = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                        Text("\(audioPlayer.currentQueue.count)")
                    }
                    .font(.title3)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private var emptyPlayerContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No track selected")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Choose a track from your playlists or events")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct QueueView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if audioPlayer.currentQueue.isEmpty {
                    ContentUnavailableView(
                        "No tracks in queue",
                        systemImage: "music.note.list",
                        description: Text("Add tracks to your queue to see them here")
                    )
                } else {
                    ForEach(Array(audioPlayer.currentQueue.enumerated()), id: \.element.id) { index, track in
                        QueueRowView(
                            track: track,
                            isCurrentTrack: index == audioPlayer.currentIndex,
                            onTap: {
                                audioPlayer.currentIndex = index
                                audioPlayer.playTrack(track)
                            },
                            onRemove: {
                                audioPlayer.removeFromQueue(at: index)
                            }
                        )
                    }
                    .onMove { source, destination in
                        audioPlayer.moveTrack(from: source.first!, to: destination)
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .disabled(audioPlayer.currentQueue.isEmpty)
                }
            }
        }
    }
}

struct QueueRowView: View {
    let track: Track
    let isCurrentTrack: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            // Artwork or placeholder
            AsyncImage(url: URL(string: track.artworkURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline)
                    .fontWeight(isCurrentTrack ? .semibold : .regular)
                    .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isCurrentTrack {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing) {
            Button("Remove", role: .destructive) {
                onRemove()
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MusicPlayerView()
}
