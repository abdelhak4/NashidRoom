import Foundation
import UIKit

// MARK: - Data Structures
struct MobileLogData: Codable {
    let actionType: String
    let platform: String
    let device: String
    let applicationVersion: String
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case platform
        case device
        case applicationVersion = "application_version"
        case timestamp
    }
}

class MobileLoggingService {
    static let shared = MobileLoggingService()
    
    private init() {}
    
    // MARK: - Required Information
    
    private func getPlatform() -> String {
        return "iOS"
    }
    
    private func getDevice() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(Character(UnicodeScalar(UInt8(value))))
        }
        
        return mapToDeviceName(identifier)
    }
    
    private func getApplicationVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    private func mapToDeviceName(_ identifier: String) -> String {
        switch identifier {
        // iPhone models
        case "iPhone14,7": return "iPhone 13 mini"
        case "iPhone14,8": return "iPhone 13"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone15,4": return "iPhone 14"
        case "iPhone15,5": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone16,1": return "iPhone 15"
        case "iPhone16,2": return "iPhone 15 Plus"
        case "iPhone16,3": return "iPhone 15 Pro"
        case "iPhone16,4": return "iPhone 15 Pro Max"
        // iPad models
        case "iPad14,1", "iPad14,2": return "iPad mini 6G"
        case "iPad13,1", "iPad13,2": return "iPad Air 5G"
        case "iPad13,16", "iPad13,17": return "iPad Air 5G"
        case "iPad14,3", "iPad14,4": return "iPad Pro 11-inch 4G"
        case "iPad14,5", "iPad14,6": return "iPad Pro 12.9-inch 6G"
        default: return identifier
        }
    }
    
    // MARK: - Logging
    
    func logAction(_ actionType: String) {
        let logData = MobileLogData(
            actionType: actionType,
            platform: getPlatform(),
            device: getDevice(),
            applicationVersion: getApplicationVersion(),
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        
        sendToBackend(logData)
    }
    
    private func sendToBackend(_ data: MobileLogData) {
        Task {
            do {
                print("🔍 [MOBILE LOG] Attempting to log: \(data)")
                
                let response = try await SupabaseService.shared.client
                    .from("mobile_logs")
                    .insert(data)
                    .execute()
                
                print("✅ [MOBILE LOG] Successfully logged action: \(data.actionType)")
                print("🔍 [MOBILE LOG] Response: \(response)")
                
            } catch {
                print("❌ [MOBILE LOG] Failed to log action: \(data.actionType)")
                print("❌ [MOBILE LOG] Error: \(error)")
                
                // If it's a Supabase error, print more details
                if let supabaseError = error as? NSError {
                    print("❌ [MOBILE LOG] Error domain: \(supabaseError.domain)")
                    print("❌ [MOBILE LOG] Error code: \(supabaseError.code)")
                    print("❌ [MOBILE LOG] Error userInfo: \(supabaseError.userInfo)")
                }
            }
        }
    }
    
    // MARK: - Device Info for Supabase Calls
    
    func getDeviceInfo() -> [String: String] {
        return [
            "platform": getPlatform(),
            "device": getDevice(),
            "application_version": getApplicationVersion()
        ]
    }
    
    // MARK: - Testing
    
    func testLogging() {
        print("🧪 [MOBILE LOG TEST] Starting logging test...")
        print("🧪 [MOBILE LOG TEST] Platform: \(getPlatform())")
        print("🧪 [MOBILE LOG TEST] Device: \(getDevice())")
        print("🧪 [MOBILE LOG TEST] App Version: \(getApplicationVersion())")
        
        logAction("test_log_action")
        print("🧪 [MOBILE LOG TEST] Test log sent")
    }
}
