import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = true
    @State private var currentTime: Double = 24.53 // 24:32 in minutes
    @State private var totalTime: Double = 34.0 // 34:00 in minutes
    @State private var waveformData: [Double] = Array(repeating: 0, count: 50)
    
    // Current podcast data
    let currentPodcast = Podcast(
        title: "The missing 96 percent of the universe",
        author: "Claire Malone",
        description: "Space and Science",
        imageURL: "podcast1",
        backgroundColor: Color.purple,
        category: "Science",
        duration: "34:00",
        isPlaying: true
    )
    
    var body: some View {
        ZStack {
            // Background gradient matching the album art
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.8),
                    Color.appBackground
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Spacer()
                
                // Album art
                albumArtView
                
                // Song info
                songInfoView
                
                // Waveform
                waveformView
                
                // Time stamps
                timeStampsView
                
                // Controls
                controlsView
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            generateWaveformData()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color.primaryText)
            }
            
            Spacer()
            
            Text("Now Playing")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.primaryText)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color.primaryText)
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Album Art View
    private var albumArtView: some View {
        ZStack {
            Rectangle()
                .fill(currentPodcast.backgroundColor)
                .frame(width: 280, height: 280)
                .cornerRadius(20)
            
            // Placeholder image
            Image(systemName: "person.fill")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.8))
        }
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Song Info View
    private var songInfoView: some View {
        VStack(spacing: 8) {
            Text(currentPodcast.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(currentPodcast.author)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.secondaryText)
        }
        .padding(.top, 30)
    }
    
    // MARK: - Waveform View
    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(0..<waveformData.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < Int(currentTime / totalTime * Double(waveformData.count)) ? Color.primaryText : Color.tertiaryText)
                    .frame(width: 3, height: CGFloat(waveformData[index] * 60 + 10))
            }
        }
        .frame(height: 80)
        .padding(.top, 30)
    }
    
    // MARK: - Time Stamps View
    private var timeStampsView: some View {
        HStack {
            Text(formatTime(currentTime))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(formatTime(totalTime))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Controls View
    private var controlsView: some View {
        HStack(spacing: 40) {
            Button(action: {}) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color.primaryText)
            }
            
            Button(action: {
                isPlaying.toggle()
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color.primaryText)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.inputBackground))
            }
            
            Button(action: {}) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color.primaryText)
            }
        }
        .padding(.top, 30)
    }
    
    // MARK: - Helper Functions
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time)
        let seconds = Int((time - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func generateWaveformData() {
        waveformData = (0..<50).map { _ in
            Double.random(in: 0.2...1.0)
        }
    }
}

#Preview {
    NowPlayingView()
} 