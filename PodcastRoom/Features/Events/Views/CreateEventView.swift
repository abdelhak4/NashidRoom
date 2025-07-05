import SwiftUI
import CoreLocation

struct CreateEventView: View {
    @ObservedObject var eventService: EventService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    
    var onEventCreated: (() -> Void)?
    
    @State private var name = ""
    @State private var description = ""
    @State private var visibility: EventVisibility = .public
    @State private var licenseType: LicenseType = .free
    @State private var enableLocation = false
    @State private var locationRadius: Double = 100
    @State private var enableTimeRestriction = false
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(7200) // 2 hours later
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    private var isAuthenticated: Bool {
        SupabaseService.shared.currentUser != nil
    }
    
    private var isLocationPermissionRequired: Bool {
        licenseType == .locationBased && enableLocation
    }
    
    private var hasLocationPermission: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse || 
        locationManager.authorizationStatus == .authorizedAlways
    }
    
    private var isLocationPermissionDenied: Bool {
        locationManager.authorizationStatus == .denied || 
        locationManager.authorizationStatus == .restricted
    }
    
    private var canCreateEvent: Bool {
        !name.isEmpty && 
        !isCreating && 
        isAuthenticated && 
        (!isLocationPermissionRequired || hasLocationPermission)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Visibility") {
                    Picker("Visibility", selection: $visibility) {
                        Text("Public").tag(EventVisibility.public)
                        Text("Private").tag(EventVisibility.private)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if visibility == .private {
                        Text("Only invited users can find and join this event")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("License Type") {
                    Picker("License Type", selection: $licenseType) {
                        Text("Free - Anyone can vote").tag(LicenseType.free)
                        Text("Premium - Invited only").tag(LicenseType.premium)
                        Text("Location-based").tag(LicenseType.locationBased)
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    switch licenseType {
                    case .free:
                        Text("Anyone can vote for tracks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .premium:
                        Text("Only invited users can vote")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .locationBased:
                        Text("Users must be at the event location to vote")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if licenseType == .locationBased {
                    Section("Location Settings") {
                        Toggle("Enable Location Restriction", isOn: $enableLocation)
                        
                        if enableLocation {
                            // Check location permission status
                            switch locationManager.authorizationStatus {
                            case .notDetermined:
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Location permission not determined")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    
                                    Button("Request Location Permission") {
                                        locationManager.requestPermission()
                                    }
                                    .foregroundColor(.blue)
                                }
                                
                            case .denied, .restricted:
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Location permission is required for location-based events")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    
                                    Text("Please enable location access in Settings > Privacy & Security > Location Services")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button("Open Settings") {
                                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(settingsURL)
                                        }
                                    }
                                    .foregroundColor(.blue)
                                }
                                
                            case .authorizedWhenInUse, .authorizedAlways:
                                if let location = locationManager.currentLocation {
                                    Text("Current Location: \(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text("Voting Radius")
                                        Spacer()
                                        Text("\(Int(locationRadius))m")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Slider(value: $locationRadius, in: 10...1000, step: 10)
                                        .accentColor(.blue)
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Getting your current location...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Button("Refresh Location") {
                                            locationManager.requestLocation()
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                                
                            @unknown default:
                                Text("Unknown location permission status")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Toggle("Time Restriction", isOn: $enableTimeRestriction)
                        
                        if enableTimeRestriction {
                            DatePicker("Start Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            DatePicker("End Time", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                if !isAuthenticated {
                    Section {
                        Text("You must be logged in to create an event")
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { createEvent() }) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Creating...")
                            } else {
                                Text("Create")
                            }
                        }
                    }
                    .disabled(!canCreateEvent)
                }
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }
    
    private func createEvent() {
        guard !name.isEmpty else { return }
        
        // Check if user is authenticated
        guard let currentUser = SupabaseService.shared.currentUser else {
            errorMessage = "You must be logged in to create an event"
            return
        }
        
        // Check location permission for location-based events
        if isLocationPermissionRequired && !hasLocationPermission {
            errorMessage = "Location permission is required for location-based events"
            return
        }
        
        // Check if location is available when required
        if isLocationPermissionRequired && locationManager.currentLocation == nil {
            errorMessage = "Current location is required for location-based events"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let event = Event(
                    name: name,
                    description: description,
                    hostId: currentUser.id,
                    visibility: visibility,
                    licenseType: licenseType,
                    locationLat: enableLocation ? locationManager.currentLocation?.latitude : nil,
                    locationLng: enableLocation ? locationManager.currentLocation?.longitude : nil,
                    locationRadius: enableLocation ? Int(locationRadius) : nil,
                    timeStart: enableTimeRestriction ? startTime : nil,
                    timeEnd: enableTimeRestriction ? endTime : nil,
                    spotifyPlaylistId: UUID().uuidString 
                )
                
                try await eventService.createEvent(event)
                
                await MainActor.run {
                    // Notify parent view to refetch
                    onEventCreated?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            requestLocation()
        }
    }
}

#Preview {
    CreateEventView(eventService: EventService())
}
