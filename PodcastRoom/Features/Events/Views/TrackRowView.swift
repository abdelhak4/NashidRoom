import SwiftUI

struct TrackRowView: View {
    let track: Track
    let position: Int
    let userVote: VoteType?
    let canVote: Bool
    let onVote: (VoteType) -> Void
    let voteCount: Int?  // Optional vote count override
    let onPlay: ((Track) -> Void)?  // Optional play action
    
    @State private var isVoting = false
    
    init(track: Track, position: Int, userVote: VoteType?, canVote: Bool, onVote: @escaping (VoteType) -> Void, voteCount: Int? = nil, onPlay: ((Track) -> Void)? = nil) {
        self.track = track
        self.position = position
        self.userVote = userVote
        self.canVote = canVote
        self.onVote = onVote
        self.voteCount = voteCount
        self.onPlay = onPlay
    }
    
    var displayVoteCount: Int {
        return voteCount ?? track.votes
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Position indicator
            ZStack {
                Circle()
                    .fill(positionColor)
                    .frame(width: 32, height: 32)
                
                Text("\(position)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Track artwork
            AsyncImage(url: URL(string: track.artworkURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let album = track.album {
                        Text(album)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text(formatDuration(track.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Vote count and buttons
            VStack(spacing: 8) {
                VoteCountView(votes: displayVoteCount)
                
                if canVote {
                    VoteButtonsView(
                        userVote: userVote,
                        isVoting: isVoting,
                        onVote: handleVote
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .background(track.isPlayed ? Color.green.opacity(0.1) : Color.clear)
        .overlay(
            track.isPlayed ? 
            HStack {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .padding(.trailing, 8)
            } : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay?(track)
        }
        .contextMenu {
            if let onPlay = onPlay {
                Button {
                    onPlay(track)
                } label: {
                    Label("Play Track", systemImage: "play.fill")
                }
            }
        }
    }
    
    private var positionColor: Color {
        switch position {
        case 1:
            return Color.yellow
        case 2:
            return Color.gray
        case 3:
            return Color.orange
        default:
            return Color.blue.opacity(0.7)
        }
    }
    
    private func handleVote(_ voteType: VoteType) {
        guard !isVoting else { return }
        isVoting = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        onVote(voteType)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isVoting = false
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VoteCountView: View {
    let votes: Int
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(votes)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(votes > 0 ? .blue : .gray)
            
            Text(votes == 1 ? "vote" : "votes")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct VoteButtonsView: View {
    let userVote: VoteType?
    let isVoting: Bool
    let onVote: (VoteType) -> Void
    
    @State private var lastTappedVote: VoteType?
    
    var body: some View {
        VStack(spacing: 16) {
            // UP VOTE BUTTON
            Button(action: { 
                lastTappedVote = .up
                onVote(.up) 
            }) {
                VStack(spacing: 3) {
                    Image(systemName: userVote == .up ? "chevron.up.circle.fill" : "chevron.up.circle")
                        .font(.title2)
                        .foregroundColor(userVote == .up ? .blue : .gray)
                    Text("UP")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(userVote == .up ? .blue : .gray)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(userVote == .up ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(8)
                .scaleEffect(isVoting && lastTappedVote == .up ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isVoting)
            }
            .disabled(isVoting)
            .buttonStyle(PlainButtonStyle())
            
            // DOWN VOTE BUTTON  
            Button(action: { 
                lastTappedVote = .down
                onVote(.down) 
            }) {
                VStack(spacing: 3) {
                    Image(systemName: userVote == .down ? "chevron.down.circle.fill" : "chevron.down.circle")
                        .font(.title2)
                        .foregroundColor(userVote == .down ? .red : .gray)
                    Text("DOWN")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(userVote == .down ? .red : .gray)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(userVote == .down ? Color.red.opacity(0.1) : Color.clear)
                .cornerRadius(8)
                .scaleEffect(isVoting && lastTappedVote == .down ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isVoting)
            }
            .disabled(isVoting)
            .buttonStyle(PlainButtonStyle())
        }
        .onChange(of: isVoting) { newValue in
            if !newValue {
                lastTappedVote = nil
            }
        }
    }
}

// Alternative compact vote buttons for smaller screens
struct CompactVoteButtonsView: View {
    let userVote: VoteType?
    let isVoting: Bool
    let onVote: (VoteType) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: { onVote(.up) }) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                    if userVote == .up {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4)
                    }
                }
                .foregroundColor(userVote == .up ? .blue : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    userVote == .up ? Color.blue.opacity(0.1) : Color.clear
                )
                .cornerRadius(8)
            }
            .disabled(isVoting)
            
            Button(action: { onVote(.down) }) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                    if userVote == .down {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                    }
                }
                .foregroundColor(userVote == .down ? .red : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    userVote == .down ? Color.red.opacity(0.1) : Color.clear
                )
                .cornerRadius(8)
            }
            .disabled(isVoting)
        }
    }
}

#Preview {
    VStack {
        TrackRowView(
            track: Track(
                id: "1",
                title: "Bohemian Rhapsody",
                artist: "Queen",
                album: "A Night at the Opera",
                duration: 355,
                artworkURL: nil,
                votes: 12,
                position: 1
            ),
            position: 1,
            userVote: .up,
            canVote: true,
            onVote: { _ in }
        )
        
        TrackRowView(
            track: Track(
                id: "2", 
                title: "Stairway to Heaven",
                artist: "Led Zeppelin",
                album: "Led Zeppelin IV",
                duration: 482,
                artworkURL: nil,
                votes: 8,
                position: 2
            ),
            position: 2,
            userVote: nil,
            canVote: true,
            onVote: { _ in }
        )
        
        TrackRowView(
            track: Track(
                id: "3",
                title: "Hotel California",
                artist: "Eagles",
                album: "Hotel California",
                duration: 391,
                artworkURL: nil,
                votes: 5,
                position: 3,
                isPlayed: true
            ),
            position: 3,
            userVote: .down,
            canVote: false,
            onVote: { _ in }
        )
    }
    .padding()
}
