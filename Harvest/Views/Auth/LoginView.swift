import SwiftUI

struct LoginView: View {
    let authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

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

            // Subtle dark veil so form text stays legible over the gradient.
            HarvestTheme.Colors.deepPlum.opacity(0.35)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: HarvestTheme.Spacing.xl) {
                    Spacer(minLength: 72)

                    logo

                    formCard

                    toggleAuthMode

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, HarvestTheme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .dismissKeyboardOnTap()
    }

    // MARK: - Logo

    private var logo: some View {
        VStack(spacing: HarvestTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(HarvestTheme.Colors.glowGradient)
                    .frame(width: 160, height: 160)
                    .blur(radius: 4)

                Circle()
                    .fill(HarvestTheme.Colors.primaryGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: HarvestTheme.Colors.rose.opacity(0.5), radius: 18, y: 6)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: HarvestTheme.Spacing.xs) {
                Text("Harvest")
                    .font(HarvestTheme.Typography.display)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                Text("Understand what you bring.\nGrow connection that lasts.")
                    .font(HarvestTheme.Typography.bodyRegular)
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(spacing: HarvestTheme.Spacing.md) {
            Text(isSignUp ? "Create your account" : "Welcome back")
                .font(HarvestTheme.Typography.h3)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            authField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                isSecure: false
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }

            authField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $password,
                isSecure: !showPassword,
                trailing: {
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    }
                }
            )
            .textContentType(isSignUp ? .newPassword : .password)
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit { if isFormValid { submit() } }

            if isSignUp {
                Text("Use at least 6 characters.")
                    .font(HarvestTheme.Typography.caption)
                    .foregroundStyle(HarvestTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = authViewModel.error {
                Text(error)
                    .font(HarvestTheme.Typography.bodySmall)
                    .foregroundStyle(HarvestTheme.Colors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassButton(
                title: isSignUp ? "Create Account" : "Sign In",
                icon: isSignUp ? "person.badge.plus" : "arrow.right",
                style: .primary
            ) {
                submit()
            }
            .disabled(!isFormValid || authViewModel.isLoading)
            .opacity(isFormValid ? 1 : 0.55)
            .overlay {
                if authViewModel.isLoading {
                    ProgressView().tint(.white)
                }
            }
            .padding(.top, HarvestTheme.Spacing.xs)
        }
        .padding(HarvestTheme.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.xxl)
                .fill(HarvestTheme.Colors.glassFillStrong.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.xxl)
                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
        }
    }

    private var toggleAuthMode: some View {
        Button {
            withAnimation(.easeInOut(duration: HarvestTheme.Animation.normal)) {
                isSignUp.toggle()
                authViewModel.error = nil
            }
        } label: {
            HStack(spacing: HarvestTheme.Spacing.xs) {
                Text(isSignUp ? "Already have an account?" : "New to Harvest?")
                    .foregroundStyle(HarvestTheme.Colors.textSecondary)
                Text(isSignUp ? "Sign In" : "Create one")
                    .fontWeight(.semibold)
                    .foregroundStyle(HarvestTheme.Colors.rose)
            }
            .font(HarvestTheme.Typography.bodySmall)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Field builder

    @ViewBuilder
    private func authField<Trailing: View>(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(HarvestTheme.Colors.rose.opacity(0.9))
                .frame(width: 22)

            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(HarvestTheme.Colors.textTertiary)
                }
                Group {
                    if isSecure {
                        SecureField("", text: text)
                    } else {
                        TextField("", text: text)
                    }
                }
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .tint(HarvestTheme.Colors.rose)
            }

            trailing()
        }
        .padding(HarvestTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                .fill(HarvestTheme.Colors.fieldFill)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.lg)
                        .stroke(HarvestTheme.Colors.border, lineWidth: 1)
                }
        }
    }

    private func submit() {
        Task {
            if isSignUp {
                await authViewModel.register(email: email, password: password)
            } else {
                await authViewModel.login(email: email, password: password)
            }
        }
    }
}
