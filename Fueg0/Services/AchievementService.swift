import Foundation

enum AchievementTier: String {
    case bronze, silver, gold, platinum
}

enum AchievementCriteria {
    case streakDays(Int)
    case weeklyStreakCount(Int)
    case tribeJoined
    case tribeContributions(Int)
    case perfectDayStreak(Int)
    case userLevel(Int)
    case totalBurnedDays(Int)
}

struct Achievement: Identifiable, Hashable {
    var id: String
    var title: String
    var description: String
    var symbol: String
    var tier: AchievementTier
    var criteria: AchievementCriteria

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }
}

@MainActor
enum AchievementService {
    static let catalog: [Achievement] = [
        Achievement(id: "first_flame", title: "First Flame", description: "Lock your first daily streak.", symbol: "flame.fill", tier: .bronze, criteria: .totalBurnedDays(1)),
        Achievement(id: "week_warrior", title: "Week Warrior", description: "Maintain a 7-day streak.", symbol: "calendar", tier: .bronze, criteria: .streakDays(7)),
        Achievement(id: "fortnight_forge", title: "Fortnight Forge", description: "Maintain a 14-day streak.", symbol: "flame", tier: .silver, criteria: .streakDays(14)),
        Achievement(id: "month_master", title: "Month Master", description: "Maintain a 30-day streak.", symbol: "rosette", tier: .gold, criteria: .streakDays(30)),
        Achievement(id: "weekly_streak_earned", title: "Weekly Streak Earned", description: "Earn your first weekly streak point.", symbol: "bolt.fill", tier: .bronze, criteria: .weeklyStreakCount(1)),
        Achievement(id: "tribe_initiate", title: "Tribe Initiate", description: "Join a tribe.", symbol: "person.3.fill", tier: .bronze, criteria: .tribeJoined),
        Achievement(id: "tribe_contributor", title: "Tribe Contributor", description: "Contribute 100 points to your tribe.", symbol: "handshake.fill", tier: .silver, criteria: .tribeContributions(100)),
        Achievement(id: "tribe_champion", title: "Tribe Champion", description: "Contribute 500 points to your tribe.", symbol: "trophy.fill", tier: .gold, criteria: .tribeContributions(500)),
        Achievement(id: "perfect_week", title: "Perfect Week", description: "Complete all daily laws for 7 perfect days.", symbol: "checkmark.circle.fill", tier: .silver, criteria: .perfectDayStreak(7)),
        Achievement(id: "level_5", title: "Rank Up: Level 5", description: "Reach warrior level 5.", symbol: "star.fill", tier: .silver, criteria: .userLevel(5)),
        Achievement(id: "level_10", title: "Rank Up: Level 10", description: "Reach warrior level 10.", symbol: "star.circle.fill", tier: .platinum, criteria: .userLevel(10)),
        Achievement(id: "century_burn", title: "Century Burn", description: "Forge 100 total burned days.", symbol: "flame.circle.fill", tier: .platinum, criteria: .totalBurnedDays(100))
    ]

    static func unlockedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: FlutterPrefs.unlockedAchievements) ?? [])
    }

    @discardableResult
    static func checkAndUnlock(session: AppSession) -> [Achievement] {
        var unlocked = unlockedIDs()
        var newly: [Achievement] = []
        let goals = GoalsService()
        let overview = goals.overview(goals: goals.loadGoals())
        let weekly = session.streakDays / 7

        for item in catalog where !unlocked.contains(item.id) {
            if meets(item.criteria, session: session, weekly: weekly, perfect: overview.perfectDayStreak) {
                unlocked.insert(item.id)
                newly.append(item)
            }
        }
        UserDefaults.standard.set(Array(unlocked).sorted(), forKey: FlutterPrefs.unlockedAchievements)
        return newly
    }

    private static func meets(
        _ criteria: AchievementCriteria,
        session: AppSession,
        weekly: Int,
        perfect: Int
    ) -> Bool {
        switch criteria {
        case .streakDays(let n): return session.streakDays >= n
        case .weeklyStreakCount(let n): return weekly >= n
        case .tribeJoined: return session.tribe != nil
        case .tribeContributions(let n): return session.tribeContributions >= n
        case .perfectDayStreak(let n): return perfect >= n
        case .userLevel(let n): return session.level >= n
        case .totalBurnedDays(let n): return session.burnedDays.count >= n
        }
    }
}
