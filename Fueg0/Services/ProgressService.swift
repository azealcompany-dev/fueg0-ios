import Foundation

enum ProgressService {
    static func loadMetrics() -> UserBodyMetrics? {
        guard let raw = UserDefaults.standard.string(forKey: FlutterPrefs.bodyMetrics),
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return decode(json)
    }

    static func saveMetrics(_ metrics: UserBodyMetrics) {
        var toSave = metrics
        if let existing = loadMetrics() {
            toSave.startingWeightKg = existing.startingWeightKg ?? metrics.currentWeightKg
        } else {
            toSave.startingWeightKg = metrics.startingWeightKg ?? metrics.currentWeightKg
        }
        toSave.updatedAt = Date()
        guard let data = try? JSONSerialization.data(withJSONObject: encode(toSave)),
              let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: FlutterPrefs.bodyMetrics)
    }

    static func buildReport() -> WarriorProgressReport? {
        guard let metrics = loadMetrics(), metrics.hasRequiredInputs else { return nil }
        let prediction = predict(metrics)
        let overview = GoalsService().overview(goals: GoalsService().loadGoals())
        let score = min(100, Int((overview.weeklyCompletionRate * 70 + Double(min(overview.perfectDayStreak, 7)) / 7 * 30).rounded()))
        let trend: ProgressTrend
        if overview.weeklyPercent >= 70 { trend = .improving }
        else if overview.weeklyPercent >= 40 { trend = .stagnant }
        else { trend = .declining }
        return WarriorProgressReport(
            metrics: metrics,
            prediction: prediction,
            weeklyPercent: overview.weeklyPercent,
            consistencyScore: score,
            trend: trend
        )
    }

    private static func predict(_ metrics: UserBodyMetrics) -> GoalPrediction {
        let bmrBase = 10 * metrics.currentWeightKg + 6.25 * metrics.heightCm - 5 * Double(metrics.age)
        let bmr: Double
        switch metrics.gender {
        case .male: bmr = bmrBase + 5
        case .female: bmr = bmrBase - 161
        case .other: bmr = bmrBase - 78
        }
        let activity: Double
        switch metrics.trainingDaysPerWeek {
        case ...1: activity = 1.2
        case 2...3: activity = 1.375
        case 4...5: activity = 1.55
        default: activity = 1.725
        }
        var sleepMult = 1.0
        if let hours = metrics.sleepHours {
            if hours < 6 { sleepMult *= 0.9 }
            else if hours >= 8 { sleepMult *= 1.05 }
        }
        if metrics.sleepQuality == .poor { sleepMult *= 0.92 }
        if metrics.sleepQuality == .excellent { sleepMult *= 1.03 }

        let tdee = bmr * activity * sleepMult
        let dailyDeficit = tdee - Double(metrics.dailyCalorieIntake)
        var weeklyChange = (dailyDeficit * 7) / 7700
        weeklyChange = min(1, max(-1, weeklyChange))
        let target = resolveTarget(metrics)
        let remaining = metrics.currentWeightKg - target
        let start = metrics.startingWeightKg ?? metrics.currentWeightKg
        let totalDelta = start - target
        var percent = 100.0
        if abs(totalDelta) >= 0.1, abs(remaining) > 0.1 {
            percent = min(100, max(0, ((start - metrics.currentWeightKg) / totalDelta) * 100))
        }

        var tips: [String] = []
        let isLosing = remaining > 0.1
        if isLosing && dailyDeficit <= 0 {
            tips.append("Lower daily calories below \(Int(tdee.rounded())) to enter fat-loss mode.")
        } else if isLosing && dailyDeficit > 0 && dailyDeficit < 300 {
            tips.append("Trim \(Int((350 - dailyDeficit).rounded())) more daily calories to accelerate progress.")
        }
        if metrics.trainingDaysPerWeek < 4 {
            tips.append("Increase training to 4+ days per week to raise your burn rate.")
        }
        if let hours = metrics.sleepHours, hours < 7 {
            tips.append("Prioritize 7–8 hours of sleep — recovery fuels fat loss.")
        }
        if tips.isEmpty && isLosing {
            tips.append("Stay locked in — your current pace is dialed in. Keep forging daily laws.")
        }

        if !isLosing && abs(remaining) <= 0.1 {
            return GoalPrediction(
                predictedDate: Date(), daysRemaining: 0, progressPercent: 100,
                weeklyWeightChangeKg: weeklyChange, dailyCalorieDeficit: dailyDeficit,
                effectiveTdee: tdee, targetWeightKg: target, weightRemainingKg: 0,
                improvementTips: tips,
                headlineMessage: "TARGET ACHIEVED. You forged the body you set out to build.",
                isAchievable: true
            )
        }
        if !isLosing || weeklyChange <= 0.01 {
            return GoalPrediction(
                predictedDate: nil, daysRemaining: nil, progressPercent: percent,
                weeklyWeightChangeKg: weeklyChange, dailyCalorieDeficit: dailyDeficit,
                effectiveTdee: tdee, targetWeightKg: target, weightRemainingKg: remaining,
                improvementTips: tips,
                headlineMessage: "At your current pace, fat loss is stalled. Adjust calories or training to reignite progress.",
                isAchievable: false
            )
        }
        let days = max(1, Int(ceil((remaining / weeklyChange) * 7)))
        let date = Calendar.current.date(byAdding: .day, value: min(days, 3650), to: Date()) ?? Date()
        let label = date.formatted(.dateTime.month(.wide).day())
        return GoalPrediction(
            predictedDate: date, daysRemaining: days, progressPercent: percent,
            weeklyWeightChangeKg: weeklyChange, dailyCalorieDeficit: dailyDeficit,
            effectiveTdee: tdee, targetWeightKg: target, weightRemainingKg: remaining,
            improvementTips: tips,
            headlineMessage: "At your current pace, you'll reach your goal around \(label).",
            isAchievable: true
        )
    }

    private static func resolveTarget(_ metrics: UserBodyMetrics) -> Double {
        if metrics.goalType == .weight {
            return metrics.targetWeightKg ?? metrics.currentWeightKg
        }
        let currentBf = metrics.currentBodyFatPercent ?? {
            let heightM = metrics.heightCm / 100
            let bmi = metrics.currentWeightKg / (heightM * heightM)
            return min(45, max(8, 1.2 * bmi + 0.23 * Double(metrics.age) - 10.8))
        }()
        let targetBf = metrics.targetBodyFatPercent ?? currentBf
        let lean = metrics.currentWeightKg * (1 - currentBf / 100)
        return lean / (1 - targetBf / 100)
    }

    private static func encode(_ metrics: UserBodyMetrics) -> [String: Any] {
        var json: [String: Any] = [
            "currentWeightKg": metrics.currentWeightKg,
            "heightCm": metrics.heightCm,
            "age": metrics.age,
            "gender": metrics.gender.rawValue,
            "dailyCalorieIntake": metrics.dailyCalorieIntake,
            "trainingDaysPerWeek": metrics.trainingDaysPerWeek,
            "goalType": metrics.goalType.rawValue,
            "updatedAt": ISO8601DateFormatter().string(from: metrics.updatedAt)
        ]
        if let v = metrics.targetWeightKg { json["targetWeightKg"] = v }
        if let v = metrics.targetBodyFatPercent { json["targetBodyFatPercent"] = v }
        if let v = metrics.currentBodyFatPercent { json["currentBodyFatPercent"] = v }
        if let v = metrics.sleepHours { json["sleepHours"] = v }
        if let v = metrics.sleepQuality { json["sleepQuality"] = v.rawValue }
        if let v = metrics.startingWeightKg { json["startingWeightKg"] = v }
        return json
    }

    private static func decode(_ json: [String: Any]) -> UserBodyMetrics {
        func d(_ key: String) -> Double? { (json[key] as? NSNumber)?.doubleValue ?? (json[key] as? Double) }
        func i(_ key: String) -> Int { (json[key] as? NSNumber)?.intValue ?? (json[key] as? Int) ?? 0 }
        return UserBodyMetrics(
            currentWeightKg: d("currentWeightKg") ?? 0,
            targetWeightKg: d("targetWeightKg"),
            targetBodyFatPercent: d("targetBodyFatPercent"),
            currentBodyFatPercent: d("currentBodyFatPercent"),
            heightCm: d("heightCm") ?? 0,
            age: i("age"),
            gender: Gender(rawValue: json["gender"] as? String ?? "") ?? .male,
            dailyCalorieIntake: i("dailyCalorieIntake"),
            trainingDaysPerWeek: i("trainingDaysPerWeek") == 0 ? 3 : i("trainingDaysPerWeek"),
            sleepHours: d("sleepHours"),
            sleepQuality: (json["sleepQuality"] as? String).flatMap(SleepQuality.init(rawValue:)),
            goalType: GoalType(rawValue: json["goalType"] as? String ?? "") ?? .weight,
            startingWeightKg: d("startingWeightKg"),
            updatedAt: ISO8601DateFormatter().date(from: json["updatedAt"] as? String ?? "") ?? Date()
        )
    }
}
