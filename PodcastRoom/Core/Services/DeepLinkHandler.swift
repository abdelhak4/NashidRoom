import Foundation
import SwiftUI

class DeepLinkHandler: ObservableObject {
    @Published var activeDeepLink: DeepLink?
    
    enum DeepLink: Equatable {
        case emailVerification(token: String, type: String)
        case passwordReset(token: String, type: String)
    }
    
    func handleURL(_ url: URL) {
        print("🔗 [DEBUG] Handling deep link: \(url)")
        
        guard url.scheme == "podcast-room" else {
            print("❌ [DEBUG] Invalid URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        switch url.host {
        case "auth":
            handleAuthDeepLink(url: url, components: components)
        default:
            print("❌ [DEBUG] Unknown deep link host: \(url.host ?? "nil")")
        }
    }
    
    private func handleAuthDeepLink(url: URL, components: URLComponents?) {
        let pathComponents = url.pathComponents
        
        guard pathComponents.count > 1 else {
            print("❌ [DEBUG] Invalid auth path: \(pathComponents)")
            return
        }
        
        let action = pathComponents[1] // First component is "/"
        
        switch action {
        case "verify":
            handleEmailVerification(components: components)
        case "reset-password":
            handlePasswordReset(components: components)
        default:
            print("❌ [DEBUG] Unknown auth action: \(action)")
        }
    }
    
    private func handleEmailVerification(components: URLComponents?) {
        guard let queryItems = components?.queryItems else {
            print("❌ [DEBUG] No query items for email verification")
            return
        }
        
        var token: String?
        var type: String?
        
        for item in queryItems {
            switch item.name {
            case "token":
                token = item.value
            case "type":
                type = item.value
            default:
                break
            }
        }
        
        guard let token = token, let type = type else {
            print("❌ [DEBUG] Missing token or type for email verification")
            return
        }
        
        activeDeepLink = .emailVerification(token: token, type: type)
        print("✅ [DEBUG] Email verification deep link processed")
    }
    
    private func handlePasswordReset(components: URLComponents?) {
        guard let queryItems = components?.queryItems else {
            print("❌ [DEBUG] No query items for password reset")
            return
        }
        
        var token: String?
        var type: String?
        
        for item in queryItems {
            switch item.name {
            case "token":
                token = item.value
            case "type":
                type = item.value
            default:
                break
            }
        }
        
        guard let token = token, let type = type else {
            print("❌ [DEBUG] Missing token or type for password reset")
            return
        }
        
        activeDeepLink = .passwordReset(token: token, type: type)
        print("✅ [DEBUG] Password reset deep link processed")
    }
    
    func clearActiveDeepLink() {
        activeDeepLink = nil
        print("🔗 [DEBUG] Active deep link cleared")
    }
}
