import Foundation
import SwiftUI
import Supabase
import GoogleSignIn

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentUser: User?
    @Published var emailVerificationSent = false
    @Published var passwordResetSent = false
    @Published var passwordResetOTPSent = false
    @Published var passwordResetOTPVerified = false
    @Published var successMessage: String?
    
    private let supabaseService = SupabaseService.shared
    
    init() {
        // Initialize state from SupabaseService
        isAuthenticated = supabaseService.isAuthenticated
        currentUser = supabaseService.currentUser
        
        // Observe changes from SupabaseService
        Task {
            for await isAuth in supabaseService.$isAuthenticated.values {
                await MainActor.run {
                    self.isAuthenticated = isAuth
                    self.currentUser = supabaseService.currentUser
                    print("🔍 [DEBUG] AuthViewModel - isAuthenticated changed to: \(isAuth)")
                }
            }
        }
        
        Task {
            for await user in supabaseService.$currentUser.values {
                await MainActor.run {
                    self.currentUser = user
                    print("🔍 [DEBUG] AuthViewModel - currentUser changed to: \(user?.username ?? "nil")")
                }
            }
        }
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        error = nil
        
        do {
            let user = try await supabaseService.signIn(email: email, password: password)
            // State will be updated automatically through the observers
            print("🔍 [DEBUG] Login completed for user: \(user.username)")
        } catch let supabaseError as SupabaseError {
            print("Login SupabaseError: \(supabaseError)")
            self.error = supabaseError.localizedDescription
        } catch {
            print("Login error: \(error)")
            self.error = "Login failed. Please try again."
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, username: String) async {
        isLoading = true
        error = nil
        
        do {
            let user = try await supabaseService.signUp(email: email, password: password, username: username)
            // State will be updated automatically through the observers
            successMessage = "Account created successfully! Welcome, \(user.username)!"
            print("🔍 [DEBUG] Sign up completed for user: \(user.username)")
        } catch let supabaseError as SupabaseError {
            print("Sign up SupabaseError: \(supabaseError)")
            self.error = supabaseError.localizedDescription
        } catch {
            print("Sign up error: \(error)")
            self.error = "Failed to create account. Please try again."
        }
        
        isLoading = false
    }
    
    func signUpWithEmailVerification(email: String, password: String, username: String) async {
        print("🔍 [DEBUG] signUpWithEmailVerification called for email: \(email)")
        isLoading = true
        error = nil
        emailVerificationSent = false
        successMessage = nil
        
        do {
            let redirectURL = "podcast-room://auth/verify" // Your app's custom URL scheme
            let emailSent = try await supabaseService.signUpWithEmailVerification(
                email: email,
                password: password,
                username: username,
                redirectURL: redirectURL
            )
            
            print("🔍 [DEBUG] signUpWithEmailVerification result - emailSent: \(emailSent)")
            
            if emailSent {
                emailVerificationSent = true
                print("🔍 [DEBUG] Email verification code sent to: \(email) - will navigate to OTP screen")
                print("🔍 [DEBUG] emailVerificationSent state: \(emailVerificationSent)")
                // Don't set success message here, let the OTP screen handle it
            } else {
                // User was created and auto-confirmed - they should be automatically signed in
                successMessage = "Account created successfully! Welcome!"
                print("🔍 [DEBUG] Account created and user automatically signed in")
                
                // Clear the form by triggering a small delay then clearing messages
                // This allows the UI to update and show success before potentially navigating
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.clearMessages()
                }
            }
        } catch let supabaseError as SupabaseError {
            print("Sign up SupabaseError: \(supabaseError)")
            self.error = supabaseError.localizedDescription
        } catch {
            print("Sign up with email verification error: \(error)")
            self.error = "Failed to create account. Please try again."
        }
        
        isLoading = false
    }
    
    func resendEmailVerification(email: String) async {
        isLoading = true
        error = nil
        
        do {
            try await supabaseService.resendEmailVerification(email: email)
            successMessage = "Verification email sent again. Please check your email."
            print("🔍 [DEBUG] Email verification resent to: \(email)")
        } catch let supabaseError as SupabaseError {
            print("Resend email SupabaseError: \(supabaseError)")
            self.error = supabaseError.localizedDescription
        } catch {
            print("Resend email verification error: \(error)")
            self.error = "Failed to send verification email. Please try again."
        }
        
        isLoading = false
    }
    
    func resetPassword(email: String) async {
        isLoading = true
        error = nil
        passwordResetOTPSent = false
        
        do {
            let otpSent = try await supabaseService.resetPasswordWithOTP(email: email)
            if otpSent {
                passwordResetOTPSent = true
                print("🔍 [DEBUG] Password reset OTP sent to: \(email)")
            }
        } catch let supabaseError as SupabaseError {
            print("Password reset SupabaseError: \(supabaseError)")
            self.error = supabaseError.localizedDescription
        } catch {
            print("Password reset error: \(error)")
            self.error = "Failed to send password reset code. Please try again."
        }
        
        isLoading = false
    }
    
    func verifyPasswordResetOTP(email: String, code: String) async {
        isLoading = true
        error = nil
        
        do {
            let verified = try await supabaseService.verifyPasswordResetOTP(email: email, code: code)
            if verified {
                passwordResetOTPVerified = true
                print("🔍 [DEBUG] Password reset OTP verified for: \(email)")
            }
        } catch let supabaseError as SupabaseError {
            print("Password reset OTP verification SupabaseError: \(supabaseError)")
            self.error = supabaseError.localizedDescription
        } catch {
            print("Password reset OTP verification error: \(error)")
            self.error = "Failed to verify code. Please check the verification code and try again."
        }
        
        isLoading = false
    }
    
    func updatePassword(newPassword: String) async {
        isLoading = true
        error = nil
        
        do {
            try await supabaseService.updatePassword(newPassword: newPassword)
            successMessage = "Password updated successfully!"
            print("🔍 [DEBUG] Password updated successfully")
            
            // Clear the success message after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.clearMessages()
            }
        } catch let supabaseError as SupabaseError {
            print("Update password SupabaseError: \(supabaseError)")
            self.error = supabaseError.localizedDescription
        } catch {
            print("Update password error: \(error)")
            self.error = "Failed to update password. Please try again."
        }
        
        isLoading = false
    }
    
    func verifyEmailWithCode(email: String, code: String) async {
        isLoading = true
        error = nil
        
        do {
            let user = try await supabaseService.verifyEmailWithCode(email: email, code: code)
            successMessage = "🎉 Email verified successfully! Welcome, \(user.username)!"
            print("🔍 [DEBUG] Email verification with code completed for user: \(user.username)")
            
            // Clear the success message after a few seconds since user will be navigated to main app
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.clearMessages()
            }
        } catch let supabaseError as SupabaseError {
            print("Email verification with code SupabaseError: \(supabaseError)")
            self.error = supabaseError.localizedDescription
        } catch {
            print("Email verification with code error: \(error)")
            self.error = "Failed to verify email code. Please check the code and try again."
        }
        
        isLoading = false
    }
    
    func clearMessages() {
        error = nil
        successMessage = nil
        emailVerificationSent = false
        passwordResetSent = false
        passwordResetOTPSent = false
        passwordResetOTPVerified = false
    }
    
    func logout() async {
        do {
            try await supabaseService.signOut()
            // State will be updated automatically through the observers
            print("🔍 [DEBUG] Logout completed")
        } catch let supabaseError as SupabaseError {
            print("Logout SupabaseError: \(supabaseError)")
            self.error = supabaseError.localizedDescription
        } catch {
            print("Logout error: \(error)")
            self.error = "Failed to logout. Please try again."
        }
    }

    func signInWithGoogle(presenting: UIViewController) async {
        isLoading = true
        error = nil
        
        do {
            // Call the SupabaseService method to handle Google Sign In
            let user = try await supabaseService.signInWithGoogle(presenting: presenting)
            
            // State will be updated automatically through the observers
            successMessage = "Successfully signed in with Google!"
            print("🔍 [DEBUG] Google Sign In completed successfully for user: \(user.username)")
            
        } catch let supabaseError as SupabaseError {
            print("Google Sign In SupabaseError: \(supabaseError)")
            
            switch supabaseError {
            case .custom(let message):
                if message.contains("audience") {
                    self.error = "Google Sign In is not properly configured. Please contact support."
                } else if message.contains("network") || message.contains("connection") {
                    self.error = "Network error. Please check your internet connection and try again."
                } else if message.contains("cancelled") || message.contains("canceled") {
                    self.error = nil // Don't show error for user cancellation
                } else {
                    self.error = "Google Sign In failed: \(message)"
                }
            default:
                self.error = "Google Sign In failed. Please try again."
            }
        } catch {
            print("Google Sign In general error: \(error)")
            
            // Handle specific error patterns
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("audience") {
                self.error = "Google Sign In is not properly configured. Please contact support."
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                self.error = "Network error. Please check your internet connection and try again."
            } else if errorMessage.contains("cancelled") || errorMessage.contains("canceled") {
                self.error = nil // Don't show error for user cancellation
            } else {
                self.error = "Google Sign In failed. Please try again."
            }
        }
        
        isLoading = false
    }
}
