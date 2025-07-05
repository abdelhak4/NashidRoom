import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false
    @State private var showingOTPVerification = false
    @State private var showingForgotPassword = false
    
    var body: some View {
        ZStack {
            // Dark background matching the app
            Color.appBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    Spacer(minLength: 30)
                    
                    // App branding section
                    VStack(spacing: 20) {
                        // App icon placeholder
                        ZStack {
                            Circle()
                                .fill(Color.inputBackground)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "waveform")
                                .font(.system(size: 35, weight: .medium))
                                .foregroundColor(Color.primaryText)
                        }
                        
                        // App title
                        Text("PodRoom")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color.primaryText)
                        
                        // Subtitle
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color.secondaryText)
                    }
                    
                    // Form section
                    VStack(spacing: 20) {
                        if isSignUp {
                            CustomTextField(
                                placeholder: "Username",
                                text: $username,
                                isSecure: false
                            )
                        }
                        
                        CustomTextField(
                            placeholder: "Email",
                            text: $email,
                            isSecure: false
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                        CustomTextField(
                            placeholder: "Password",
                            text: $password,
                            isSecure: true
                        )
                        
                        if let error = authViewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.system(size: 14, weight: .medium))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        if let successMessage = authViewModel.successMessage {
                            Text(successMessage)
                                .foregroundColor(.green)
                                .font(.system(size: 14, weight: .medium))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Main action button
                        Button(action: {
                            Task {
                                if isSignUp {
                                    print("🔍 [DEBUG] LoginView signup button pressed")
                                    await authViewModel.signUpWithEmailVerification(
                                        email: email,
                                        password: password,
                                        username: username
                                    )
                                    
                                    // Check if email verification was sent (not auto-confirmed) on main thread
                                    await MainActor.run {
                                        if authViewModel.emailVerificationSent {
                                            // Navigate to OTP verification screen
                                            print("🔍 [DEBUG] LoginView navigating to OTP verification screen")
                                            showingOTPVerification = true
                                        }
                                    }
                                } else {
                                    await authViewModel.login(email: email, password: password)
                                }
                            }
                        }) {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                }
                                
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                        }
                        .disabled(authViewModel.isLoading)
                        
                        // Google Sign In button
                        Button(action: {
                            Task {
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first,
                                   let rootViewController = window.rootViewController {
                                    await authViewModel.signInWithGoogle(presenting: rootViewController)
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color.primaryText)
                                
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.primaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.secondaryBackground)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.inputBorder, lineWidth: 1)
                            )
                        }
                        
                        // OR divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("OR")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.tertiaryText)
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 20)
                        
                        // Toggle between login/signup
                        Button(action: {
                            isSignUp.toggle()
                            email = ""
                            password = ""
                            username = ""
                        }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Forgot password button (only show in login mode)
                        if !isSignUp {
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: $showingOTPVerification) {
            OTPVerificationView(email: email, username: username)
                .environmentObject(authViewModel)
        }
    }
}

// Custom text field component
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Placeholder text
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color.tertiaryText)
                    .padding(.leading, 20)
            }
            
            // Input field
            Group {
                if isSecure {
                    SecureField("", text: $text)
                        .foregroundColor(Color.primaryText)
                } else {
                    TextField("", text: $text)
                        .foregroundColor(Color.primaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.inputBackground)
        .cornerRadius(25)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.inputBorder, lineWidth: 1)
        )
    }
}

#Preview {
    LoginView() 
        .environmentObject(AuthenticationViewModel())
}
