import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

struct IgniteResult: Equatable {
    let xpAwarded: Int
    let newStreak: Int
    let alreadyComplete: Bool
}

@MainActor
@Observable
final class AppSession {
    enum Phase: Equatable {
        case splash
        case login
        case onboarding
        case main
    }

    private enum Keys {
        static let onboarded = "fueg0.native.onboarded"
        static let name = "fueg0.native.displayName"
        static let tribe = "fueg0.native.tribeID"
        static let ignited = "fueg0.native.ignitedDay"
        static let lastBurn = "fueg0.native.lastBurnDate"
        static let completedMissions = "fueg0.native.completedMissions"
        static let xp = "fueg0.native.xp"
        static let level = "fueg0.native.level"
        static let streak = "fueg0.native.streak"
    }

    var phase: Phase = .splash
    var displayName: String
    var tribe: Tribe?
    var streakDays: Int
    var xp: Int
    var level: Int
    var rank: String
    var ignitedToday: Bool
    var completedMissionIDs: Set<Int>
    var userUID: String?
    var userEmail: String?
    var isBusy: Bool = false
    var authError: String?

    private var splashFinished = false
    private var cloudProfileExists = false
    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        let defaults = UserDefaults.standard
        displayName = defaults.string(forKey: Keys.name) ?? "Warrior"
        tribe = Tribe.byID(defaults.string(forKey: Keys.tribe))
        ignitedToday = defaults.string(forKey: Keys.ignited) == Self.dayStamp()
        let stored = defaults.array(forKey: Keys.completedMissions) as? [Int] ?? []
        completedMissionIDs = Set(stored)
        xp = defaults.integer(forKey: Keys.xp)
        let storedLevel = max(1, defaults.object(forKey: Keys.level) as? Int ?? 1)
        level = storedLevel
        streakDays = defaults.integer(forKey: Keys.streak)
        rank = Gamification.rank(forLevel: storedLevel)

        let current = Auth.auth().currentUser
        userUID = current?.uid
        userEmail = current?.email
        if let googleName = current?.displayName, displayName == "Warrior", !googleName.isEmpty {
            displayName = googleName
        }

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.handleAuthChange(user)
            }
        }
    }

    var isSignedIn: Bool { userUID != nil }

    var isOnboarded: Bool {
        let defaults = UserDefaults.standard
        if let uid = userUID, defaults.object(forKey: Self.onboardedKey(uid)) != nil {
            return defaults.bool(forKey: Self.onboardedKey(uid))
        }
        if cloudProfileExists { return true }
        return defaults.bool(forKey: Keys.onboarded)
    }

    func finishSplash() {
        splashFinished = true
        Task { await routeFromAuth() }
    }

    func completeOnboarding(name: String, tribe: Tribe?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = trimmed.isEmpty ? (displayName == "Warrior" ? "Warrior" : displayName) : trimmed
        if displayName.isEmpty { displayName = "Warrior" }
        self.tribe = tribe

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Keys.onboarded)
        if let uid = userUID {
            defaults.set(true, forKey: Self.onboardedKey(uid))
        }
        persistLocal()
        phase = .main
        Task { await persistCloud() }
    }

    @discardableResult
    func completeIgnite() -> IgniteResult {
        if ignitedToday {
            return IgniteResult(xpAwarded: 0, newStreak: streakDays, alreadyComplete: true)
        }

        let calendar = Calendar(identifier: .gregorian)
        var newStreak = 1
        if let last = UserDefaults.standard.string(forKey: Keys.lastBurn),
           let lastDate = Self.parseDay(last) {
            if calendar.isDateInYesterday(lastDate) {
                newStreak = max(streakDays, 0) + 1
            } else if calendar.isDateInToday(lastDate) {
                newStreak = max(streakDays, 1)
            }
        }

        streakDays = newStreak
        ignitedToday = true
        let awarded = 150 + newStreak * 10
        applyXP(awarded)
        persistLocal()
        Task { await persistCloud() }
        return IgniteResult(xpAwarded: awarded, newStreak: newStreak, alreadyComplete: false)
    }

    func toggleMission(_ id: Int) {
        if completedMissionIDs.contains(id) {
            completedMissionIDs.remove(id)
        } else {
            completedMissionIDs.insert(id)
        }
        UserDefaults.standard.set(Array(completedMissionIDs), forKey: Keys.completedMissions)
    }

    func replayOnboarding() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: Keys.onboarded)
        if let uid = userUID {
            defaults.set(false, forKey: Self.onboardedKey(uid))
        }
        completedMissionIDs = []
        ignitedToday = false
        phase = .onboarding
    }

    func signIn(email: String, password: String) async {
        await runAuth {
            try await AuthGateway.signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String, name: String) async {
        await runAuth {
            try await AuthGateway.signUp(email: email, password: password, name: name)
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                self.displayName = trimmed
            }
        }
    }

    func signInWithGoogle() async {
        await runAuth {
            try await AuthGateway.signInWithGoogle()
        }
    }

    func sendPasswordReset(email: String) async -> String? {
        authError = nil
        do {
            try await AuthGateway.sendPasswordReset(email: email)
            return "Password reset email sent. Check your inbox (and spam)."
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func signOut() {
        do {
            try AuthGateway.signOut()
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func runAuth(_ work: () async throws -> Void) async {
        isBusy = true
        authError = nil
        defer { isBusy = false }
        do {
            try await work()
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func handleAuthChange(_ user: User?) {
        let previous = userUID
        userUID = user?.uid
        userEmail = user?.email
        if let name = user?.displayName, !name.isEmpty, displayName == "Warrior" {
            displayName = name
        }
        guard splashFinished else { return }
        if previous != userUID {
            Task { await routeFromAuth() }
        }
    }

    private func routeFromAuth() async {
        guard Auth.auth().currentUser != nil else {
            resetEphemeralUser()
            phase = .login
            return
        }
        await hydrateProfile()
        phase = isOnboarded ? .main : .onboarding
    }

    private func resetEphemeralUser() {
        userUID = nil
        userEmail = nil
        cloudProfileExists = false
        authError = nil
    }

    private func applyXP(_ amount: Int) {
        xp += amount
        var needed = Gamification.xpToNextLevel(level)
        while xp >= needed {
            xp -= needed
            level += 1
            needed = Gamification.xpToNextLevel(level)
        }
        rank = Gamification.rank(forLevel: level)
    }

    private func persistLocal() {
        let defaults = UserDefaults.standard
        defaults.set(displayName, forKey: Keys.name)
        defaults.set(tribe?.id, forKey: Keys.tribe)
        defaults.set(xp, forKey: Keys.xp)
        defaults.set(level, forKey: Keys.level)
        defaults.set(streakDays, forKey: Keys.streak)
        if ignitedToday {
            defaults.set(Self.dayStamp(), forKey: Keys.ignited)
            defaults.set(Self.dayStamp(), forKey: Keys.lastBurn)
        }
    }

    private func hydrateProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await Firestore.firestore().collection("users").document(uid).getDocument()
            guard snap.exists, let data = snap.data() else { return }
            cloudProfileExists = true
            if let name = data["name"] as? String, !name.isEmpty {
                displayName = name
            }
            if let tribeId = data["tribeId"] as? String {
                tribe = Tribe.byID(tribeId)
            }
            if let streak = Self.intValue(data["streak"]) {
                streakDays = streak
            }
            if let remoteXP = Self.intValue(data["xp"]) {
                xp = remoteXP
            }
            if let remoteLevel = Self.intValue(data["level"]) {
                level = max(1, remoteLevel)
            }
            if let remoteRank = data["rank"] as? String, !remoteRank.isEmpty {
                rank = remoteRank
            } else {
                rank = Gamification.rank(forLevel: level)
            }
            persistLocal()
        } catch {
            // Offline-first: keep local values.
        }
    }

    private func persistCloud() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var data: [String: Any] = [
            "name": displayName,
            "streak": streakDays,
            "xp": xp,
            "level": level,
            "rank": rank,
            "tribeContributions": 0,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let tribeID = tribe?.id {
            data["tribeId"] = tribeID
        }
        do {
            try await Firestore.firestore().collection("users").document(uid).setData(data, merge: true)
            cloudProfileExists = true
        } catch {
            // Local session still stands.
        }
    }

    private static func onboardedKey(_ uid: String) -> String {
        "\(Keys.onboarded).\(uid)"
    }

    private static func dayStamp() -> String {
        dayFormatter.string(from: Date())
    }

    private static func parseDay(_ value: String) -> Date? {
        dayFormatter.date(from: value)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? Int64 { return Int(n) }
        if let n = any as? NSNumber { return n.intValue }
        return nil
    }
}
