import SwiftUI

// MARK: - Shared Event Components

struct EventVisibilityBadge: View {
    let visibility: EventVisibility
    
    var body: some View {
        Text(visibility == .public ? "Public" : "Private")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                visibility == .public 
                    ? Color.green.opacity(0.8) 
                    : Color.orange.opacity(0.8)
            )
            .cornerRadius(8)
    }
}

struct LicenseTypeBadge: View {
    let licenseType: LicenseType
    
    var body: some View {
        Text(licenseTypeText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(licenseTypeColor)
            .cornerRadius(8)
    }
    
    private var licenseTypeText: String {
        switch licenseType {
        case .free:
            return "Open Voting"
        case .premium:
            return "Premium"
        case .locationBased:
            return "Location-based"
        }
    }
    
    private var licenseTypeColor: Color {
        switch licenseType {
        case .free:
            return Color.green.opacity(0.8)
        case .premium:
            return Color.purple.opacity(0.8)
        case .locationBased:
            return Color.blue.opacity(0.8)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        EventVisibilityBadge(visibility: .public)
        EventVisibilityBadge(visibility: .private)
        
        LicenseTypeBadge(licenseType: .free)
        LicenseTypeBadge(licenseType: .premium)
        LicenseTypeBadge(licenseType: .locationBased)
    }
    .padding()
}
