import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

struct IgniteResult: Equatable {
    let xpAwarded: Int
    let newStreak: Int
    let alreadyComplete: Bool
}

enum TribeJoinResult: Equatable {
    case joined
    case alreadyMember
    case failed(String)
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
        static let tribeContributions = "fueg0.native.tribeContributions"
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
    var tribeContributions: Int = 0
    var tribeSyncError: String?

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
        tribeContributions = defaults.integer(forKey: Keys.tribeContributions)

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
        let previousTribeID = self.tribe?.id
        self.tribe = tribe

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Keys.onboarded)
        if let uid = userUID {
            defaults.set(true, forKey: Self.onboardedKey(uid))
        }
        persistLocal()
        phase = .main
        Task {
            await persistCloud()
            if let tribe {
                _ = await commitTribe(tribe, previousID: previousTribeID)
            }
        }
    }

    @discardableResult
    func joinTribe(_ tribe: Tribe) async -> TribeJoinResult {
        await commitTribe(tribe, previousID: self.tribe?.id)
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

    func applyTribeContributionDelta(_ delta: Int) {
        tribeContributions = max(0, tribeContributions + delta)
        persistLocal()
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

    func deleteAccount() async throws {
        isBusy = true
        authError = nil
        defer { isBusy = false }
        try await AuthGateway.deleteAccount()
        wipeLocalSession()
    }

    func reauthenticateAndDelete(password: String?, google: Bool) async throws {
        isBusy = true
        authError = nil
        defer { isBusy = false }
        if google {
            try await AuthGateway.reauthenticateWithGoogle()
        } else {
            try await AuthGateway.reauthenticateWithPassword(password ?? "")
        }
        try await AuthGateway.deleteAccount()
        wipeLocalSession()
    }

    private func wipeLocalSession() {
        let defaults = UserDefaults.standard
        if let uid = userUID {
            defaults.removeObject(forKey: Self.onboardedKey(uid))
        }
        [
            Keys.onboarded, Keys.name, Keys.tribe, Keys.ignited, Keys.lastBurn,
            Keys.completedMissions, Keys.xp, Keys.level, Keys.streak, Keys.tribeContributions
        ].forEach { defaults.removeObject(forKey: $0) }
        FlutterPrefs.wipeAccountLocalData()
        displayName = "Warrior"
        tribe = nil
        streakDays = 0
        xp = 0
        level = 1
        rank = Gamification.rank(forLevel: 1)
        ignitedToday = false
        completedMissionIDs = []
        tribeContributions = 0
        tribeSyncError = nil
        cloudProfileExists = false
        userUID = nil
        userEmail = nil
        authError = nil
        phase = .login
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

    private func commitTribe(_ tribe: Tribe, previousID: String?) async -> TribeJoinResult {
        guard let normalized = Tribe.normalizeID(tribe.id), let resolved = Tribe.byID(normalized) else {
            tribeSyncError = "Invalid tribe selection. Please try again."
            return .failed("Invalid tribe selection. Please try again.")
        }

        self.tribe = resolved
        persistLocal()

        guard let uid = Auth.auth().currentUser?.uid else {
            tribeSyncError = "Sign in to save your tribe across devices."
            return .failed("Sign in to join a tribe.")
        }

        do {
            try await TribeService().writeMembership(uid: uid, tribeID: normalized)
            tribeSyncError = nil
            if previousID != normalized {
                await TribeService().postJoinedActivity(
                    tribeID: normalized,
                    userName: displayName,
                    userID: uid
                )
                return .joined
            }
            return .alreadyMember
        } catch {
            tribeSyncError = "Could not save your tribe. Check the connection and try again."
            return .failed(tribeSyncError ?? "Could not save your tribe.")
        }
    }

    private func persistLocal() {
        let defaults = UserDefaults.standard
        defaults.set(displayName, forKey: Keys.name)
        defaults.set(tribe?.id, forKey: Keys.tribe)
        defaults.set(tribeContributions, forKey: Keys.tribeContributions)
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
            if let contributions = Self.intValue(data["tribeContributions"]) {
                tribeContributions = max(0, contributions)
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
