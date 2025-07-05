import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @Environment(\.dismiss) private var dismiss
    
    private var passwordsMatch: Bool {
        return newPassword == confirmPassword && !newPassword.isEmpty
    }
    
    private var isPasswordValid: Bool {
        return newPassword.count >= 6
    }
    
    private var isFormValid: Bool {
        return passwordsMatch && isPasswordValid
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header Section
                VStack(spacing: 16) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Set New Password")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Create a strong password for your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Password Input Section
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("New Password", text: $newPassword)
                                } else {
                                    SecureField("New Password", text: $newPassword)
                                }
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .font(.system(size: 16))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .disabled(authViewModel.isLoading)
                        
                        if !newPassword.isEmpty && !isPasswordValid {
                            Text("Password must be at least 6 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Group {
                            if showPassword {
                                TextField("Confirm New Password", text: $confirmPassword)
                            } else {
                                SecureField("Confirm New Password", text: $confirmPassword)
                            }
                        }
                        .font(.system(size: 16))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .disabled(authViewModel.isLoading)
                        
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Update Password Button
                    Button(action: {
                        Task {
                            await authViewModel.updatePassword(newPassword: newPassword)
                        }
                    }) {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Update Password")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid && !authViewModel.isLoading ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || authViewModel.isLoading)
                }
                
                // Success/Error Messages
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
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
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
        .onChange(of: authViewModel.successMessage) { successMessage in
            if successMessage != nil {
                // Password updated successfully, dismiss after a delay to show success message
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Clear the password reset states to ensure clean navigation back to login
                    authViewModel.clearMessages()
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    ChangePasswordView()
        .environmentObject(AuthenticationViewModel())
}
