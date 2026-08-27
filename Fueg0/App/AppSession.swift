import Foundation
import Observation

@Observable
final class AppSession {
    enum Phase: Equatable {
        case splash
        case onboarding
        case main
    }

    private enum Keys {
        static let onboarded = "fueg0.native.onboarded"
        static let name = "fueg0.native.displayName"
        static let tribe = "fueg0.native.tribeID"
        static let ignited = "fueg0.native.ignitedDay"
        static let completedMissions = "fueg0.native.completedMissions"
    }

    var phase: Phase = .splash
    var displayName: String
    var tribe: Tribe?
    var streakDays: Int = 7
    var xp: Int = 1_240
    var rank: String = "Specialist"
    var ignitedToday: Bool
    var completedMissionIDs: Set<Int>
    var showIgnite: Bool = false

    init() {
        let defaults = UserDefaults.standard
        displayName = defaults.string(forKey: Keys.name) ?? "Warrior"
        tribe = Tribe.byID(defaults.string(forKey: Keys.tribe))
        ignitedToday = defaults.string(forKey: Keys.ignited) == Self.dayStamp()
        let stored = defaults.array(forKey: Keys.completedMissions) as? [Int] ?? []
        completedMissionIDs = Set(stored)
    }

    var isOnboarded: Bool {
        UserDefaults.standard.bool(forKey: Keys.onboarded)
    }

    func finishSplash() {
        phase = isOnboarded ? .main : .onboarding
    }

    func completeOnboarding(name: String, tribe: Tribe?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = trimmed.isEmpty ? "Warrior" : trimmed
        self.tribe = tribe

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Keys.onboarded)
        defaults.set(displayName, forKey: Keys.name)
        defaults.set(tribe?.id, forKey: Keys.tribe)
        phase = .main
    }

    func ignite() {
        ignitedToday = true
        UserDefaults.standard.set(Self.dayStamp(), forKey: Keys.ignited)
        showIgnite = true
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
        completedMissionIDs = []
        ignitedToday = false
        phase = .onboarding
    }

    private static func dayStamp() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
