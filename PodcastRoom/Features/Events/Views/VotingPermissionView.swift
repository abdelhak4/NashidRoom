import SwiftUI
import CoreLocation

struct VotingPermissionView: View {
    let event: Event
    let errorMessage: String?
    @StateObject private var locationService = LocationService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon based on restriction type
            restrictionIcon
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            // Title
            Text(restrictionTitle)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text(restrictionDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Action button if applicable
            Group {
                if event.licenseType == .locationBased && locationService.authorizationStatus == .denied {
                    Button("Enable Location") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                } else if event.licenseType == .locationBased && locationService.authorizationStatus == .notDetermined {
                    Button("Allow Location Access") {
                        locationService.requestLocationPermission()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
        }
        .padding(30)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding()
    }
    
    private var restrictionIcon: Image {
        switch event.licenseType {
        case .premium:
            return Image(systemName: "person.badge.key")
        case .locationBased:
            if event.timeStart != nil || event.timeEnd != nil {
                return Image(systemName: "clock.badge.exclamationmark")
            } else {
                return Image(systemName: "location.circle")
            }
        case .free:
            return Image(systemName: "exclamationmark.triangle")
        }
    }
    
    private var restrictionTitle: String {
        switch event.licenseType {
        case .premium:
            return "Invitation Required"
        case .locationBased:
            if errorMessage?.contains("time") == true {
                return "Event Not Active"
            } else {
                return "Location Required"
            }
        case .free:
            return "Voting Restricted"
        }
    }
    
    private var restrictionDescription: String {
        if let errorMessage = errorMessage {
            return errorMessage
        }
        
        switch event.licenseType {
        case .premium:
            return "This is a private event. You need an invitation from the host to participate and vote."
        case .locationBased:
            if let startTime = event.timeStart, let endTime = event.timeEnd {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "You can only vote during the event time: \(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
            } else if event.locationLat != nil && event.locationLng != nil {
                return "You need to be at the event location to vote for tracks."
            } else {
                return "This event has location and time restrictions for voting."
            }
        case .free:
            return "There was an issue checking your voting permissions. Please try again."
        }
    }
}

struct LocationStatusView: View {
    let event: Event
    @StateObject private var locationService = LocationService.shared
    @State private var distance: Double?
    
    var body: some View {
        if event.licenseType == .locationBased,
           let eventLat = event.locationLat,
           let eventLng = event.locationLng,
           let radius = event.locationRadius,
           let userLocation = locationService.currentLocation {
            
            HStack(spacing: 8) {
                Image(systemName: (distance ?? 99999) <= Double(radius) ? "location.circle.fill" : "location.circle")
                    .foregroundColor((distance ?? 99999) <= Double(radius) ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Distance: \(distance != nil ? "\(Int(distance!))m" : "Calculating...")")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("Required: within \(radius)m")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if (distance ?? 99999) <= Double(radius) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .task {
                distance = locationService.calculateDistance(
                    from: userLocation.coordinate,
                    to: CLLocationCoordinate2D(latitude: eventLat, longitude: eventLng)
                )
            }
        }
    }
}

struct TimeStatusView: View {
    let event: Event
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        if event.licenseType == .locationBased,
           let startTime = event.timeStart,
           let endTime = event.timeEnd {
            
            let isActive = currentTime >= startTime && currentTime <= endTime
            
            HStack(spacing: 8) {
                Image(systemName: isActive ? "clock.fill" : "clock")
                    .foregroundColor(isActive ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isActive ? "Event Active" : "Event Inactive")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(formatTimeRange(start: startTime, end: endTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .onReceive(timer) { _ in
                currentTime = Date()
            }
        }
    }
    
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

#Preview {
    VStack(spacing: 20) {
        VotingPermissionView(
            event: Event(
                name: "Private Party",
                description: "Test event",
                hostId: "host123",
                visibility: .private,
                licenseType: .premium,
                spotifyPlaylistId: "playlist123"
            ),
            errorMessage: nil
        )
        
        VotingPermissionView(
            event: Event(
                name: "Location Event",
                description: "Test event",
                hostId: "host123",
                visibility: .public,
                licenseType: .locationBased,
                locationLat: 37.7749,
                locationLng: -122.4194,
                locationRadius: 100,
                timeStart: Calendar.current.date(byAdding: .hour, value: -1, to: Date()),
                timeEnd: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
                spotifyPlaylistId: "playlist123"
            ),
            errorMessage: nil
        )
    }
}
