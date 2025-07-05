import Foundation

// MARK: - Data Structures
struct SupabaseLogData: Codable {
    let actionType: String
    let platform: String
    let device: String
    let applicationVersion: String
    let timestamp: String
    let table: String?
    
    enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case platform
        case device
        case applicationVersion = "application_version"
        case timestamp
        case table
    }
}

extension SupabaseService {
    
    // MARK: - Logging Helper
    
    private func logSupabaseCall(_ action: String, additionalData: [String: String]? = nil) {
        let deviceInfo = MobileLoggingService.shared.getDeviceInfo()
        
        let logData = SupabaseLogData(
            actionType: action,
            platform: deviceInfo["platform"] ?? "iOS",
            device: deviceInfo["device"] ?? "Unknown",
            applicationVersion: deviceInfo["application_version"] ?? "Unknown",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            table: additionalData?["table"]
        )
        
        Task {
            do {
                _ = try await client
                    .from("mobile_logs")
                    .insert(logData)
                    .execute()
            } catch {
                print("Failed to log Supabase call: \(error)")
            }
        }
    }
    
    // MARK: - Logged Database Operations
    
    func loggedInsert<T: Encodable>(table: String, data: T, action: String) async throws {
        logSupabaseCall("supabase_\(action)", additionalData: ["table": table])
        _ = try await client.from(table).insert(data).execute()
    }
    
    func loggedUpdate<T: Encodable>(table: String, data: T, action: String) async throws {
        logSupabaseCall("supabase_\(action)", additionalData: ["table": table])
        _ = try await client.from(table).update(data).execute()
    }
    
    func loggedSelect<T: Decodable>(table: String, action: String, type: T.Type) async throws -> [T] {
        logSupabaseCall("supabase_\(action)", additionalData: ["table": table])
        let response: [T] = try await client.from(table).select().execute().value
        return response
    }
}


