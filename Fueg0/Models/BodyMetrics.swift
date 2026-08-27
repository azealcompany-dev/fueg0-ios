import Foundation

enum GoalType: String, Codable {
    case weight, bodyFat
}

enum Gender: String, Codable, CaseIterable {
    case male, female, other
}

enum SleepQuality: String, Codable, CaseIterable {
    case poor, fair, good, excellent
}

enum ProgressTrend {
    case improving, stagnant, declining
}

struct UserBodyMetrics: Equatable, Codable {
    var currentWeightKg: Double
    var targetWeightKg: Double?
    var targetBodyFatPercent: Double?
    var currentBodyFatPercent: Double?
    var heightCm: Double
    var age: Int
    var gender: Gender
    var dailyCalorieIntake: Int
    var trainingDaysPerWeek: Int
    var sleepHours: Double?
    var sleepQuality: SleepQuality?
    var goalType: GoalType
    var startingWeightKg: Double?
    var updatedAt: Date

    var hasRequiredInputs: Bool {
        guard currentWeightKg > 0, heightCm > 0, age > 0, dailyCalorieIntake > 0 else { return false }
        if goalType == .weight { return (targetWeightKg ?? 0) > 0 }
        return (targetBodyFatPercent ?? 0) > 0
    }

    var currentWeightLbs: Double { currentWeightKg * 2.20462 }
    var targetWeightLbs: Double? { targetWeightKg.map { $0 * 2.20462 } }
}

struct GoalPrediction: Equatable {
    var predictedDate: Date?
    var daysRemaining: Int?
    var progressPercent: Double
    var weeklyWeightChangeKg: Double
    var dailyCalorieDeficit: Double
    var effectiveTdee: Double
    var targetWeightKg: Double
    var weightRemainingKg: Double
    var improvementTips: [String]
    var headlineMessage: String
    var isAchievable: Bool
}

struct WarriorProgressReport: Equatable {
    var metrics: UserBodyMetrics
    var prediction: GoalPrediction
    var weeklyPercent: Int
    var consistencyScore: Int
    var trend: ProgressTrend
}
