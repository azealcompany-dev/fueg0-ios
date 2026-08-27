import SwiftUI

struct LoginView: View {
    @Environment(AppSession.self) private var session

    @State private var isLogin = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var obscure = true
    @State private var resetNotice: String?
    @State private var resetting = false

    private static let emailRegex = /^[\w.\-]+@([\w\-]+\.)+[\w\-]{2,}$/

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("FUEG0")
                    .font(.system(size: 42, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Palette.textPrimary)

                Text(isLogin ? "Welcome back." : "Join the fire.")
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Spacing.sm)

                if let error = session.authError {
                    errorBanner(error)
                        .padding(.top, Spacing.lg)
                } else if let resetNotice {
                    noticeBanner(resetNotice)
                        .padding(.top, Spacing.lg)
                }

                VStack(spacing: Spacing.md) {
                    if !isLogin {
                        Fueg0Field(title: "Name", text: $name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    }

                    Fueg0Field(title: "Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Fueg0Field(title: "Password", text: $password, secure: obscure) {
                        Button {
                            obscure.toggle()
                        } label: {
                            Image(systemName: obscure ? "eye.slash" : "eye")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Palette.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .textContentType(isLogin ? .password : .newPassword)
                }
                .padding(.top, Spacing.xl)
                .disabled(session.isBusy)

                if isLogin {
                    HStack {
                        Spacer()
                        Button(resetting ? "Sending…" : "Forgot password?") {
                            Task { await resetPassword() }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .disabled(session.isBusy || resetting)
                    }
                    .padding(.top, Spacing.sm)
                } else {
                    Spacer().frame(height: Spacing.lg)
                }

                EmberButton(
                    title: isLogin ? "Sign in" : "Sign up",
                    enabled: canSubmit,
                    loading: session.isBusy
                ) {
                    Task { await submit() }
                }
                .padding(.top, isLogin ? Spacing.md : 0)

                Button {
                    isLogin.toggle()
                    session.authError = nil
                    resetNotice = nil
                } label: {
                    Text(isLogin ? "New warrior? Create account" : "Already a warrior? Sign in")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(session.isBusy)

                HStack(spacing: Spacing.md) {
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                    Text("or")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textMuted)
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                }
                .padding(.vertical, Spacing.lg)

                EmberOutlineButton(title: "Continue with Google", enabled: !session.isBusy) {
                    Task { await session.signInWithGoogle() }
                }
            }
            .fueg0ScreenPadding()
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.background.ignoresSafeArea())
    }

    private var canSubmit: Bool {
        !session.isBusy && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 6
            && (isLogin || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func submit() async {
        resetNotice = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.wholeMatch(of: Self.emailRegex) != nil else {
            session.authError = "Enter a valid email address."
            return
        }
        if isLogin {
            await session.signIn(email: trimmedEmail, password: password)
        } else {
            await session.signUp(email: trimmedEmail, password: password, name: name)
        }
    }

    private func resetPassword() async {
        resetNotice = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.wholeMatch(of: Self.emailRegex) != nil else {
            session.authError = "Enter a valid email to reset your password."
            return
        }
        resetting = true
        let message = await session.sendPasswordReset(email: trimmedEmail)
        resetting = false
        resetNotice = message
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Palette.error)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusSm, style: .continuous)
                .fill(Palette.error.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusSm, style: .continuous)
                .stroke(Palette.error.opacity(0.35), lineWidth: 1)
        )
    }

    private func noticeBanner(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Palette.textPrimary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSm, style: .continuous)
                    .fill(Palette.success.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusSm, style: .continuous)
                    .stroke(Palette.success.opacity(0.35), lineWidth: 1)
            )
    }
}
