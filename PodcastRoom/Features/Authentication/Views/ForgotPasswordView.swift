import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var email = ""
    @State private var showingPasswordResetOTP = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header Section
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Reset Password")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Enter your email address and we'll send you a verification code to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Email Input Section
                VStack(spacing: 24) {
                    TextField("Email Address", text: $email)
                        .font(.system(size: 16))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(authViewModel.isLoading)
                    
                    // Send Reset Button
                    Button(action: {
                        Task {
                            await authViewModel.resetPassword(email: email)
                            
                            // Check if OTP was sent on main thread
                            await MainActor.run {
                                if authViewModel.passwordResetOTPSent {
                                    // Navigate to OTP verification screen
                                    print("🔍 [DEBUG] ForgotPasswordView navigating to OTP screen")
                                    showingPasswordResetOTP = true
                                }
                            }
                        }
                    }) {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Send Reset Code")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!email.isEmpty && email.contains("@") && !authViewModel.isLoading ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || !email.contains("@") || authViewModel.isLoading)
                }
                
                // Error Messages
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
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            authViewModel.clearMessages()
        }
        .fullScreenCover(isPresented: $showingPasswordResetOTP) {
            PasswordResetOTPView(email: email)
                .environmentObject(authViewModel)
        }
        .onChange(of: showingPasswordResetOTP) { isShowing in
            // When the OTP view is dismissed, also dismiss this view if password was successfully reset
            if !isShowing && authViewModel.successMessage != nil {
                dismiss()
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthenticationViewModel())
}
