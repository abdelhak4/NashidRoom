import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var verificationCode = ""
    @State private var showPassword = false
    @State private var requireEmailVerification = true
    @State private var showingOTPVerification = false
    @Environment(\.dismiss) private var dismiss
    
    private var passwordsMatch: Bool {
        return password == confirmPassword && !password.isEmpty
    }
    
    private var isPasswordValid: Bool {
        return password.count >= 6
    }
    
    private var isFormValid: Bool {
        return !email.isEmpty && 
               !username.isEmpty && 
               passwordsMatch && 
               isPasswordValid &&
               email.contains("@")
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Create Account")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            VStack(spacing: 16) {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disabled(authViewModel.isLoading)
                
                TextField("Email Address", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disabled(authViewModel.isLoading)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(authViewModel.isLoading)
                    
                    if !password.isEmpty && !isPasswordValid {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        if showPassword {
                            TextField("Confirm Password", text: $confirmPassword)
                        } else {
                            SecureField("Confirm Password", text: $confirmPassword)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(authViewModel.isLoading)
                    
                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Toggle("Require email verification", isOn: $requireEmailVerification)
                    .disabled(authViewModel.isLoading)
                
                Button("Create Account") {
                    Task {
                        print("🔍 [DEBUG] SignUp button pressed - requireEmailVerification: \(requireEmailVerification)")
                        if requireEmailVerification {
                            print("🔍 [DEBUG] Calling signUpWithEmailVerification")
                            await authViewModel.signUpWithEmailVerification(
                                email: email,
                                password: password,
                                username: username
                            )
                            
                            // Check if email verification was sent (not auto-confirmed) on main thread
                            await MainActor.run {
                                if authViewModel.emailVerificationSent {
                                    // Navigate to OTP verification screen
                                    print("🔍 [DEBUG] Navigating to OTP verification screen")
                                    showingOTPVerification = true
                                }
                            }
                            // If auto-confirmed, user will be automatically signed in via onChange
                        } else {
                            print("🔍 [DEBUG] Calling regular signUp")
                            await authViewModel.signUp(
                                email: email,
                                password: password,
                                username: username
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(!isFormValid ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(!isFormValid || authViewModel.isLoading)
            }
            
            // Remove the old email verification UI section since we navigate to OTP screen
            
            if let successMessage = authViewModel.successMessage, !authViewModel.emailVerificationSent {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let error = authViewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            HStack {
                Text("Already have an account?")
                    .foregroundColor(.secondary)
                
                Button("Sign In") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(authViewModel.isLoading)
        .overlay {
            if authViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .onAppear {
            authViewModel.clearMessages()
        }
        .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // User is now authenticated, dismiss the signup view
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showingOTPVerification) {
            OTPVerificationView(email: email, username: username)
                .environmentObject(authViewModel)
        }
    }
}

#Preview {
    NavigationView {
        SignUpView()
    }
    .environmentObject(AuthenticationViewModel())
}
