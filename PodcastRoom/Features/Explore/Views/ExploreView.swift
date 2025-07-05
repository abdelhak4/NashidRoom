import SwiftUI

struct ExploreView: View {
    @State private var searchText = ""
    @StateObject private var eventService = EventService()
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBarView(searchText: $searchText)
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Events content
            EventsTabView(eventService: eventService, searchText: searchText)
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search events...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EventsTabView: View {
    @ObservedObject var eventService: EventService
    let searchText: String
    @State private var showingCreateEvent = false
    
    var filteredEvents: [Event] {
        if searchText.isEmpty {
            return eventService.events
        } else {
            return eventService.events.filter { event in
                event.name.localizedCaseInsensitiveContains(searchText) ||
                event.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            // Create event button
            Button(action: { showingCreateEvent = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Event")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            if eventService.isLoading {
                VStack {
                    ProgressView()
                    Text("Loading events...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEvents.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Events" : "No Results",
                    systemImage: searchText.isEmpty ? "music.note.list" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "No events available right now." : "Try a different search term")
                )
            } else {
                List(filteredEvents) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        ExploreEventRowView(event: event)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showingCreateEvent) {
            CreateEventView(eventService: eventService) {
                // Refetch events after creation
                Task {
                    await eventService.fetchPublicEvents()
                }
            }
        }
        .task {
            await eventService.fetchPublicEvents()
        }
    }
}

struct ExploreEventRowView: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    if !event.description.isEmpty {
                        Text(event.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    EventVisibilityBadge(visibility: event.visibility)
                    LicenseTypeBadge(licenseType: event.licenseType)
                }
            }
            
            HStack {
                Label("Live", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Spacer()
                
                if event.licenseType == .locationBased {
                    Label("Location-based", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text("Tap to join")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    ExploreView()
} 