import SwiftUI

struct TrackSearchView: View {
    let title: String
    let subtitle: String?
    let onTrackSelected: (Track) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var youtubeService = YouTubeService.shared
    @State private var searchText = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    private let searchDebouncer = Debouncer(delay: 0.5)
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                    .padding(.horizontal)
                
                // Search results
                if isSearching {
                    VStack {
                        ProgressView()
                        Text("Searching...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else {
                    List(searchResults, id: \.id) { track in
                        SearchResultRowView(track: track) {
                            selectTrack(track)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                searchDebouncer.debounce {
                    performSearch()
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await youtubeService.searchTracks(query: searchText)
                
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }
    
    private func selectTrack(_ track: Track) {
        onTrackSelected(track)
        dismiss()
    }
}

// Debouncer to avoid too many search requests
class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        
        if let workItem = workItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
}

#Preview {
    TrackSearchView(
        title: "Add Track",
        subtitle: "Add tracks to your event"
    ) { track in
        print("Selected track: \(track.title)")
    }
}
