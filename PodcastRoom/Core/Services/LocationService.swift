import Foundation
import CoreLocation
import SwiftUI

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var error: String?
    
    private let locationManager = CLLocationManager()
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10 // Update location every 10 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        // Check authorization status asynchronously to avoid blocking the main thread
        Task {
            await checkLocationAuthorizationAndStart()
        }
    }
    
    private func checkLocationAuthorizationAndStart() async {
        await MainActor.run {
            guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
                error = "Location permission not granted"
                return
            }
            
            guard CLLocationManager.locationServicesEnabled() else {
                error = "Location services not enabled"
                return
            }
            
            // Move location manager calls to background queue
            Task {
                locationManager.startUpdatingLocation()
            }
            isLocationEnabled = true
            error = nil
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLocationEnabled = false
    }
    
    func getCurrentCoordinates() async -> (latitude: Double, longitude: Double)? {
        // If we already have a current location, return it
        if let location = currentLocation {
            return (latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        
        // If location updates are not enabled, try to start them
        if !isLocationEnabled && (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) {
            startLocationUpdates()
        }
        
        // Wait for location with timeout
        let timeout: TimeInterval = 10.0
        let startTime = Date()
        
        while currentLocation == nil && Date().timeIntervalSince(startTime) < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        guard let location = currentLocation else {
            return nil
        }
        
        return (latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) // Returns distance in meters
    }
    
    func isWithinRadius(eventLocation: CLLocationCoordinate2D, radius: Double) -> Bool {
        guard let currentLocation = currentLocation else {
            return false
        }
        
        let distance = calculateDistance(
            from: currentLocation.coordinate,
            to: eventLocation
        )
        
        return distance <= radius
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            currentLocation = location
            error = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error.localizedDescription
        }
        print("Location error: \(error)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                startLocationUpdates()
            case .denied, .restricted:
                error = "Location access denied"
                stopLocationUpdates()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}
