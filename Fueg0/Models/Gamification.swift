import Foundation

enum Gamification {
    static let ranks = [
        "PRIVATE",
        "PRIVATE FIRST CLASS",
        "SPECIALIST",
        "SERGEANT",
        "STAFF SERGEANT",
        "MASTER SERGEANT",
        "COMMAND SERGEANT MAJOR",
        "WARRIOR ELITE"
    ]

    static func rank(forLevel level: Int) -> String {
        let index = min(max((level - 1) / 10, 0), ranks.count - 1)
        return ranks[index]
    }

    static func xpToNextLevel(_ level: Int) -> Int {
        max(level, 1) * 100
    }
}

struct WOD: Hashable {
    let title: String
    let detail: String
}

extension SampleContent {
    static let wods: [WOD] = [
        WOD(title: "MURPH", detail: "1 mile run\n100 Pull-ups\n200 Push-ups\n300 Air Squats\n1 mile run"),
        WOD(title: "DT", detail: "5 rounds:\n12 Deadlift (155/105)\n9 Hang Clean\n6 Push Jerk"),
        WOD(title: "FRAN", detail: "21-15-9\nThrusters (95/65)\nPull-ups"),
        WOD(title: "CINDY", detail: "20-min AMRAP:\n5 Pull-ups\n10 Push-ups\n15 Air Squats"),
        WOD(title: "KING KONG", detail: "3 rounds:\n1 Deadlift (455/205)\n2 Muscle-ups\n3 Squat Cleans (250/175)\n4 HSPU"),
        WOD(title: "FILTHY FIFTY", detail: "50 each: Box Jumps, Jumping Pull-ups, KB Swings (1.5p), Walking Lunges, K2E, Push Press (45/35), Back Ext, Wall Balls, Burpees, Double-unders")
    ]

    static func todaysWOD(for date: Date = .now) -> (title: String, detail: String) {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let wod = wods[day % wods.count]
        return (wod.title, wod.detail)
    }
}
