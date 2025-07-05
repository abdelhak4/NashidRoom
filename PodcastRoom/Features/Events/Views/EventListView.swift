import SwiftUI

struct EventListView: View {
    @StateObject private var eventService = EventService()
    @State private var showingCreateEvent = false
    @State private var selectedSegment = 0 // 0 = Public, 1 = My Events
    
    var body: some View {
        VStack {
            // Segmented control to switch between public events and user's events
            Picker("Event Type", selection: $selectedSegment) {
                Text("Public").tag(0)
                Text("My Events").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            if eventService.isLoading {
                Spacer()
                ProgressView("Loading events...")
                Spacer()
            } else if eventService.events.isEmpty {
                ContentUnavailableView(
                    selectedSegment == 0 ? "No Public Events" : "No Events Created",
                    systemImage: "music.note.list",
                    description: Text(selectedSegment == 0 ? "No public events available right now." : "You haven't created any events yet.")
                )
            } else {
                List(eventService.events) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventRowView(event: event, eventService: eventService)
                    }
                }
            }
            
            if let error = eventService.error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("Events")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    showingCreateEvent = true
                }
            }
        }
        .sheet(isPresented: $showingCreateEvent) {
            CreateEventView(eventService: eventService) {
                // Refetch events after creation
                Task {
                    await loadEvents()
                }
            }
        }
        .task {
            await loadEvents()
        }
        .onChange(of: selectedSegment) { _, _ in
            Task {
                await loadEvents()
            }
        }
    }
    
    private func loadEvents() async {
        if selectedSegment == 0 {
            await eventService.fetchPublicEvents()
        } else {
            await eventService.fetchUserEvents()
        }
    }
}

struct EventRowView: View {
    let event: Event
    let eventService: EventService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if !event.description.isEmpty {
                        Text(event.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    EventVisibilityBadge(visibility: event.visibility)
                    LicenseTypeBadge(licenseType: event.licenseType)
                }
            }
            
            HStack {
                Label("\(event.visibility.rawValue.capitalized)", systemImage: event.visibility == .public ? "globe" : "lock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if event.licenseType == .locationBased {
                    Label("Location-based", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if event.licenseType == .premium {
                    Label("Premium", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                
                Text("Tap to join")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    EventListView()
}
