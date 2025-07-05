import SwiftUI

struct PasswordResetOTPView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    let email: String
    
    @State private var verificationCode = ""
    @State private var showingChangePassword = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header Section
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Verify Reset Code")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        Text("We've sent a 6-digit verification code to:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text(email)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                // OTP Input Section
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("Enter Verification Code")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("000000", text: $verificationCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(verificationCode.count == 6 ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .disabled(authViewModel.isLoading)
                            .onChange(of: verificationCode) { newValue in
                                // Limit to 6 digits
                                if newValue.count > 6 {
                                    verificationCode = String(newValue.prefix(6))
                                }
                            }
                        
                        Text("Enter the 6-digit code from your email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Verify Button
                    Button(action: {
                        Task {
                            await authViewModel.verifyPasswordResetOTP(email: email, code: verificationCode)
                        }
                    }) {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Verify Code")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(verificationCode.count == 6 && !authViewModel.isLoading ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(verificationCode.count != 6 || authViewModel.isLoading)
                }
                
                // Resend Section
                VStack(spacing: 16) {
                    Text("Didn't receive the code?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Button("Resend Code") {
                            Task {
                                await authViewModel.resetPassword(email: email)
                                verificationCode = ""
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(authViewModel.isLoading)
                        
                        Button("Change Email") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
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
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            authViewModel.clearMessages()
        }
        .onChange(of: authViewModel.passwordResetOTPVerified) { isVerified in
            if isVerified {
                // Navigate to change password screen
                print("🔍 [DEBUG] OTP verified, navigating to change password screen")
                showingChangePassword = true
            }
        }
        .fullScreenCover(isPresented: $showingChangePassword) {
            ChangePasswordView()
                .environmentObject(authViewModel)
        }
        .onChange(of: showingChangePassword) { isShowing in
            // When the change password view is dismissed, also dismiss this view
            if !isShowing && authViewModel.successMessage != nil {
                dismiss()
            }
        }
    }
}

#Preview {
    PasswordResetOTPView(email: "user@example.com")
        .environmentObject(AuthenticationViewModel())
}
