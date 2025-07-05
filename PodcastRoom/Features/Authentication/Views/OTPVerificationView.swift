import SwiftUI

struct OTPVerificationView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    let email: String
    let username: String
    
    @State private var verificationCode = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header Section
                VStack(spacing: 16) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Verify Your Email")
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
                            await authViewModel.verifyEmailWithCode(email: email, code: verificationCode)
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
                                await authViewModel.resendEmailVerification(email: email)
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
                
                // Error/Success Messages
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
                
                if let successMessage = authViewModel.successMessage {
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
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .navigationTitle("Verify Email")
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
        .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // User is now authenticated, dismiss to go to home
                dismiss()
            }
        }
    }
}

#Preview {
    OTPVerificationView(email: "user@example.com", username: "TestUser")
        .environmentObject(AuthenticationViewModel())
}
