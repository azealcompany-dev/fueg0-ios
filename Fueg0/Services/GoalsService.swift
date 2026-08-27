import Foundation

struct GoalsService {
    private var defaults: UserDefaults { .standard }

    static let pointsPerGoal = 15

    static let defaultGoals: [DailyGoal] = [
        DailyGoal(
            id: "default_ignite",
            title: "IGNITE",
            description: "Watched the full daily fire video",
            createdAt: "2024-01-01T00:00:00.000"
        ),
        DailyGoal(
            id: "default_wod",
            title: "WOD",
            description: "Completed today’s savage WOD",
            createdAt: "2024-01-01T00:00:00.000"
        ),
        DailyGoal(
            id: "default_cold",
            title: "COLD EXPOSURE",
            description: "3+ min ice bath OR 2+ min ice-cold shower",
            createdAt: "2024-01-01T00:00:00.000"
        ),
        DailyGoal(
            id: "default_no_pmo",
            title: "NO PMO",
            description: "Zero porn, zero masturbation, zero edging",
            createdAt: "2024-01-01T00:00:00.000"
        ),
        DailyGoal(
            id: "default_no_junk",
            title: "NO JUNK",
            description: "Zero sugar, zero processed food, zero alcohol",
            createdAt: "2024-01-01T00:00:00.000"
        ),
        DailyGoal(
            id: "default_lock",
            title: "LOCK THE STREAK",
            description: "All laws completed – now seal it",
            createdAt: "2024-01-01T00:00:00.000"
        )
    ]

    func checkableGoals(_ goals: [DailyGoal]) -> [DailyGoal] {
        guard goals.count > 1 else { return goals }
        return Array(goals.dropLast())
    }

    func todayKey(_ date: Date = Date()) -> String {
        Self.dayFormatter.string(from: date)
    }

    func generateId() -> String {
        "goal_\(Int(Date().timeIntervalSince1970 * 1000))_\(Int.random(in: 1000...9999))"
    }

    func saveGoals(_ goals: [DailyGoal]) {
        let payload: [[String: String]] = goals.map {
            [
                "id": $0.id,
                "title": $0.title,
                "description": $0.description,
                "createdAt": $0.createdAt
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let raw = String(data: data, encoding: .utf8) else { return }
        defaults.set(raw, forKey: FlutterPrefs.customDailyGoals)
    }

    func resetToDefaults() {
        saveGoals(Self.defaultGoals)
    }

    func loadGoals() -> [DailyGoal] {
        guard let raw = defaults.string(forKey: FlutterPrefs.customDailyGoals),
              let data = raw.data(using: .utf8) else {
            return Self.defaultGoals
        }
        do {
            let decoded = try JSONSerialization.jsonObject(with: data)
            guard let list = decoded as? [[String: Any]] else { return Self.defaultGoals }
            let goals: [DailyGoal] = list.compactMap { item in
                let title = (item["title"] as? String) ?? ""
                guard !title.isEmpty else { return nil }
                let id = (item["id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? "legacy_\(title.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression))"
                return DailyGoal(
                    id: id,
                    title: title,
                    description: (item["description"] as? String) ?? "",
                    createdAt: (item["createdAt"] as? String) ?? "2024-01-01T00:00:00.000"
                )
            }
            return goals.isEmpty ? Self.defaultGoals : goals
        } catch {
            return Self.defaultGoals
        }
    }

    func completions(for date: String, goals: [DailyGoal]) -> [String: Bool] {
        guard let raw = defaults.string(forKey: FlutterPrefs.goalCompletion(date)),
              let data = raw.data(using: .utf8) else {
            return [:]
        }
        do {
            let decoded = try JSONSerialization.jsonObject(with: data)
            if let map = decoded as? [String: Any] {
                return map.reduce(into: [:]) { result, pair in
                    result[pair.key] = (pair.value as? Bool) ?? (pair.value as? NSNumber)?.boolValue == true
                }
            }
            if let list = decoded as? [Any] {
                let checkable = checkableGoals(goals)
                var legacy: [String: Bool] = [:]
                for (index, value) in list.enumerated() where index < checkable.count {
                    let flag = (value as? Bool) ?? (value as? NSNumber)?.boolValue == true
                    legacy[checkable[index].id] = flag
                }
                if date == todayKey() {
                    saveCompletions(legacy, date: date)
                }
                return legacy
            }
        } catch {
            return [:]
        }
        return [:]
    }

    func saveCompletions(_ completions: [String: Bool], date: String) {
        do {
            let data = try JSONSerialization.data(withJSONObject: completions, options: [])
            if let raw = String(data: data, encoding: .utf8) {
                defaults.set(raw, forKey: FlutterPrefs.goalCompletion(date))
            }
        } catch {
            // Keep last good local value.
        }
    }

    func setCompletion(goalId: String, completed: Bool, goals: [DailyGoal]) -> [String: Bool] {
        var current = completions(for: todayKey(), goals: goals)
        current[goalId] = completed
        saveCompletions(current, date: todayKey())
        return current
    }

    func overview(goals: [DailyGoal], now: Date = Date()) -> ProgressOverview {
        let checkable = checkableGoals(goals)
        let calendar = Calendar(identifier: .gregorian)
        let weekStart = startOfWeek(now)
        let cached = completions(from: weekStart, to: now, goals: goals)
        let today = cached[todayKey(now)] ?? [:]
        let todayCompleted = checkable.filter { today[$0.id] == true }.count

        var weekCompleted = 0
        var weekTotal = 0
        var day = weekStart
        while day <= now {
            let dayMap = cached[todayKey(day)] ?? [:]
            weekTotal += checkable.count
            weekCompleted += checkable.filter { dayMap[$0.id] == true }.count
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? now.addingTimeInterval(86_400)
            if day > now { break }
        }

        let weeklyRate = weekTotal > 0 ? Double(weekCompleted) / Double(weekTotal) : 0
        return ProgressOverview(
            todayCompleted: todayCompleted,
            todayTotal: checkable.count,
            weeklyCompletionRate: weeklyRate,
            perfectDayStreak: perfectStreak(goals: goals, reference: now, cached: cached)
        )
    }

    func stats(goals: [DailyGoal], now: Date = Date()) -> [String: GoalCompletionStats] {
        let checkable = checkableGoals(goals)
        let weekStart = startOfWeek(now)
        let monthStart = Calendar(identifier: .gregorian).date(from: Calendar(identifier: .gregorian).dateComponents([.year, .month], from: now)) ?? now
        let rangeStart = min(weekStart, monthStart)
        let cached = completions(from: rangeStart, to: now, goals: goals)
        var result: [String: GoalCompletionStats] = [:]
        let weekElapsed = max(1, (Calendar.current.dateComponents([.day], from: weekStart, to: now).day ?? 0) + 1)
        let monthElapsed = Calendar(identifier: .gregorian).component(.day, from: now)

        for goal in checkable {
            var weekCount = 0
            var monthCount = 0
            var day = weekStart
            while day <= now {
                if cached[todayKey(day)]?[goal.id] == true { weekCount += 1 }
                day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? now.addingTimeInterval(86_400)
                if day > now { break }
            }
            day = monthStart
            while day <= now {
                if cached[todayKey(day)]?[goal.id] == true { monthCount += 1 }
                day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? now.addingTimeInterval(86_400)
                if day > now { break }
            }
            result[goal.id] = GoalCompletionStats(
                goalId: goal.id,
                weekCompletions: weekCount,
                monthCompletions: monthCount,
                weekDaysElapsed: weekElapsed,
                monthDaysElapsed: monthElapsed
            )
        }
        return result
    }

    private func completions(from start: Date, to end: Date, goals: [DailyGoal]) -> [String: [String: Bool]] {
        var result: [String: [String: Bool]] = [:]
        var day = start
        while day <= end {
            let key = todayKey(day)
            result[key] = completions(for: key, goals: goals)
            day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? end.addingTimeInterval(86_400)
            if day > end { break }
        }
        return result
    }

    private func perfectStreak(goals: [DailyGoal], reference: Date, cached: [String: [String: Bool]]) -> Int {
        let checkable = checkableGoals(goals)
        guard !checkable.isEmpty else { return 0 }
        var streak = 0
        var date = reference
        let today = todayKey(reference)
        while streak < 365 {
            let key = todayKey(date)
            let map = cached[key] ?? completions(for: key, goals: goals)
            let allDone = checkable.allSatisfy { map[$0.id] == true }
            if !allDone {
                if key == today {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                    continue
                }
                break
            }
            streak += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return streak
    }

    private func startOfWeek(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: start) ?? start
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
