import SwiftUI

struct LoginView: View {
    let authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showPassword = false

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        email.contains("@")
    }

    var body: some View {
        ZStack {
            Image("Splash Page Gradient")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.xl) {
                    Spacer(minLength: 60)

                    // Logo
                    VStack(spacing: HarvestTheme.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(HarvestTheme.Colors.primary)
                                .frame(width: 80, height: 80)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }

                        Text("Harvest")
                            .font(HarvestTheme.Typography.h1)
                            .foregroundStyle(.primary)

                        Text("Grow meaningful connections")
                            .font(HarvestTheme.Typography.bodyRegular)
                            .foregroundStyle(.secondary)
                    }

                    // Form
                    VStack(spacing: HarvestTheme.Spacing.md) {
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(HarvestTheme.Typography.h3)
                            .foregroundStyle(.primary)

                        VStack(spacing: HarvestTheme.Spacing.sm) {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(.primary)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .overlay {
                                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                        .stroke(Color(.separator), lineWidth: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.md))

                            HStack {
                                ZStack(alignment: .leading) {
                                    if password.isEmpty {
                                        Text("Password")
                                            .foregroundStyle(.gray)
                                    }

                                    if showPassword {
                                        TextField("", text: $password)
                                    } else {
                                        SecureField("", text: $password)
                                    }
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .textContentType(isSignUp ? .newPassword : .password)
                            .foregroundStyle(.primary)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                                    .stroke(Color(.separator), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.md))
                        }

                        if let error = authViewModel.error {
                            Text(error)
                                .font(HarvestTheme.Typography.bodySmall)
                                .foregroundStyle(HarvestTheme.Colors.error)
                                .multilineTextAlignment(.center)
                        }

                        GlassButton(
                            title: isSignUp ? "Create Account" : "Sign In",
                            icon: isSignUp ? "person.badge.plus" : "arrow.right",
                            style: .primary
                        ) {
                            Task {
                                if isSignUp {
                                    await authViewModel.register(email: email, password: password)
                                } else {
                                    await authViewModel.login(email: email, password: password)
                                }
                            }
                        }
                        .disabled(!isFormValid || authViewModel.isLoading)
                        .opacity(isFormValid ? 1 : 0.6)

                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(HarvestTheme.Colors.primary)
                        }
                    }
                    .padding(HarvestTheme.Spacing.lg)
                    .background {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.12), radius: 20, y: 12)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: HarvestTheme.Radius.xl)
                            .stroke(Color(.separator), lineWidth: 1)
                    }
                    .padding(.horizontal, HarvestTheme.Spacing.lg)

                    // Toggle sign up / sign in
                    Button {
                        withAnimation(.easeInOut(duration: HarvestTheme.Animation.normal)) {
                            isSignUp.toggle()
                            authViewModel.error = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundStyle(.secondary)
                            Text(isSignUp ? "Sign In" : "Sign Up")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        .font(HarvestTheme.Typography.bodySmall)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
    }
}
