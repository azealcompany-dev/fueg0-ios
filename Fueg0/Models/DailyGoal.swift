import Foundation

struct DailyGoal: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var description: String
    var createdAt: String
}

struct GoalCompletionStats: Hashable {
    var goalId: String
    var weekCompletions: Int
    var monthCompletions: Int
    var weekDaysElapsed: Int
    var monthDaysElapsed: Int

    var weekRate: Double {
        weekDaysElapsed > 0 ? Double(weekCompletions) / Double(weekDaysElapsed) : 0
    }

    var monthRate: Double {
        monthDaysElapsed > 0 ? Double(monthCompletions) / Double(monthDaysElapsed) : 0
    }

    var weekPercent: Int { Int((weekRate * 100).rounded()) }
    var monthPercent: Int { Int((monthRate * 100).rounded()) }
}

struct ProgressOverview: Hashable {
    var todayCompleted: Int
    var todayTotal: Int
    var weeklyCompletionRate: Double
    var perfectDayStreak: Int

    var todayRate: Double {
        todayTotal > 0 ? Double(todayCompleted) / Double(todayTotal) : 0
    }

    var todayPercent: Int { Int((todayRate * 100).rounded()) }
    var weeklyPercent: Int { Int((weeklyCompletionRate * 100).rounded()) }
}

enum FlutterPrefs {
    static let customDailyGoals = "custom_daily_goals"
    static let goalsMigrated = "goals_id_migrated_v1"
    static let tribeUserContributions = "tribe_user_total_contributions"

    static func goalCompletion(_ date: String) -> String {
        "goal_completion_\(date)"
    }

    static func tribeGoalAward(date: String, goalId: String) -> String {
        "tribe_goal_awarded_\(date)_\(goalId)"
    }

    static func wipeAccountLocalData() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: customDailyGoals)
        defaults.removeObject(forKey: goalsMigrated)
        defaults.removeObject(forKey: tribeUserContributions)
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("goal_completion_") || key.hasPrefix("tribe_goal_awarded_") {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
