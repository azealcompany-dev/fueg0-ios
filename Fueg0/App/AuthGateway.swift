import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn

enum AuthFailure: LocalizedError, Equatable {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

enum AuthGateway {
    static func signIn(email: String, password: String) async throws {
        do {
            _ = try await Auth.auth().signIn(withEmail: email.trimmedEmail, password: password)
        } catch {
            throw map(error)
        }
    }

    static func signUp(email: String, password: String, name: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email.trimmedEmail, password: password)
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let request = result.user.createProfileChangeRequest()
                request.displayName = trimmed
                try await request.commitChanges()
            }
        } catch {
            throw map(error)
        }
    }

    @MainActor
    static func signInWithGoogle() async throws {
        guard let presenter = PresentingViewController.top() else {
            throw AuthFailure.message("Unable to present Google Sign-In.")
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthFailure.message(
                    "Google sign in failed. Check Firebase and Google Sign-In configuration."
                )
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            throw map(error)
        }
    }

    static func sendPasswordReset(email: String) async throws {
        let trimmed = email.trimmedEmail
        guard !trimmed.isEmpty else {
            throw AuthFailure.message("Enter your email to reset your password.")
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmed)
        } catch {
            let mapped = map(error)
            if case .message(let text) = mapped, text.contains("No account found") {
                return
            }
            throw mapped
        }
    }

    static func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    private static func map(_ error: Error) -> AuthFailure {
        if let failure = error as? AuthFailure {
            return failure
        }
        if let gid = error as? GIDSignInError {
            if gid.code == .canceled {
                return .message("Google sign in was cancelled.")
            }
            return .message("Google sign in failed. Please try again.")
        }
        let ns = error as NSError
        if ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) {
            return .message(message(for: code, fallback: ns.localizedDescription))
        }
        return .message("Authentication failed. Check your connection and try again.")
    }

    private static func message(for code: AuthErrorCode, fallback: String) -> String {
        switch code {
        case .userNotFound:
            return "No account found for that email."
        case .wrongPassword:
            return "Incorrect password. Try again."
        case .invalidCredential:
            return "Invalid email or password. Check your credentials and try again."
        case .invalidEmail, .missingEmail:
            return "Enter a valid email address."
        case .emailAlreadyInUse:
            return "An account already exists for that email."
        case .weakPassword:
            return "Password is too weak. Use at least 6 characters."
        case .userDisabled:
            return "This account has been disabled."
        case .tooManyRequests:
            return "Too many attempts. Wait a moment and try again."
        case .operationNotAllowed:
            return "Email/password sign in is not enabled. Contact support."
        case .networkError:
            return "Network error. Check your connection and try again."
        default:
            return fallback.isEmpty ? "Authentication failed. Please try again." : fallback
        }
    }
}

private extension String {
    var trimmedEmail: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
