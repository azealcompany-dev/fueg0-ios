import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn

enum AuthFailure: LocalizedError, Equatable {
    case message(String)
    case requiresRecentLogin(isGoogle: Bool)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        case .requiresRecentLogin:
            return "Confirm it’s you, then delete the account."
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

    static func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthFailure.message("You must be signed in to delete your account.")
        }
        do {
            try await deleteOwnedData(uid: user.uid)
        } catch {
            throw AuthFailure.message(
                "Could not delete your cloud data. Check your connection and try again."
            )
        }
        do {
            try await user.delete()
        } catch {
            let ns = error as NSError
            if ns.domain == AuthErrorDomain,
               AuthErrorCode(rawValue: ns.code) == .requiresRecentLogin {
                throw AuthFailure.requiresRecentLogin(isGoogle: isGoogleUser(user))
            }
            throw map(error)
        }
        GIDSignIn.sharedInstance.signOut()
        if Auth.auth().currentUser != nil {
            try? Auth.auth().signOut()
        }
    }

    static func reauthenticateWithPassword(_ password: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthFailure.message("You must be signed in to confirm your identity.")
        }
        let email = (user.email ?? "").trimmedEmail
        guard !email.isEmpty else {
            throw AuthFailure.message("This account has no email. Confirm with Google Sign-In instead.")
        }
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AuthFailure.message("Enter your password to confirm.")
        }
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: trimmed)
            try await user.reauthenticate(with: credential)
        } catch {
            throw map(error)
        }
    }

    @MainActor
    static func reauthenticateWithGoogle() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthFailure.message("You must be signed in to confirm your identity.")
        }
        guard let presenter = PresentingViewController.top() else {
            throw AuthFailure.message("Unable to present Google Sign-In.")
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthFailure.message("Google confirmation failed. Please try again.")
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await user.reauthenticate(with: credential)
        } catch {
            throw map(error)
        }
    }

    private static func isGoogleUser(_ user: User) -> Bool {
        user.providerData.contains { $0.providerID == GoogleAuthProvider.id }
    }

    private static func deleteOwnedData(uid: String) async throws {
        let userRef = Firestore.firestore().collection("users").document(uid)
        do {
            let awards = try await userRef.collection("tribeGoalAwards").getDocuments()
            for doc in awards.documents {
                try await doc.reference.delete()
            }
        } catch {
            // Still delete the parent user document.
        }
        try await userRef.delete()
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
        case .requiresRecentLogin:
            return "Confirm it’s you, then delete the account."
        case .userMismatch:
            return "That Google account does not match this Fueg0 account."
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
