import SwiftUI

struct PlaylistTrackRowView: View {
    let track: Track
    let isCurrentTrack: Bool
    let onPlay: () -> Void
    let onAddToQueue: () -> Void
    let onRemove: (() -> Void)?
    
    var body: some View {
        HStack {
            // Artwork
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
                    .lineLimit(2)
                
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let album = track.album {
                    Text(album)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if isCurrentTrack {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            
            VStack {
                Text(formatDuration(track.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if track.votes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                        Text("\(track.votes)")
                    }
                    .font(.caption2)
                    .foregroundColor(.green)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
        .contextMenu {
            Button {
                onPlay()
            } label: {
                Label("Play Now", systemImage: "play")
            }
            
            Button {
                onAddToQueue()
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            
            if let onRemove = onRemove {
                Divider()
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
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
    PlaylistTrackRowView(
        track: Track(
            id: "1",
            title: "Sample Track",
            artist: "Sample Artist",
            duration: 180,
            artworkURL: nil
        ),
        isCurrentTrack: false,
        onPlay: {},
        onAddToQueue: {},
        onRemove: nil
    )
    .padding()
}
