import SwiftUI

struct Tribe: Identifiable, Hashable {
    let id: String
    let name: String
    let animal: String
    let motto: String
    let traits: String
    let symbol: String
    let warCries: [String]

    var warCry: String { dailyWarCry() }

    func dailyWarCry(on date: Date = .now) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return warCries[day % warCries.count]
    }

    static let all: [Tribe] = [
        Tribe(
            id: "iron_wolves",
            name: "Iron Wolves",
            animal: "Wolf",
            motto: "Loyalty and pack power",
            traits: "The pack never breaks. Iron discipline, united strength.",
            symbol: "pawprint",
            warCries: [
                "The pack hunts tonight!",
                "Iron jaws, unbreakable will.",
                "We run together, we rise together.",
                "No wolf fights alone."
            ]
        ),
        Tribe(
            id: "phoenix_eagles",
            name: "Phoenix Eagles",
            animal: "Eagle",
            motto: "Resilience and vision",
            traits: "From ashes we rise. Soar higher than the storm.",
            symbol: "bird",
            warCries: [
                "Rise from the ashes!",
                "Eyes on the horizon. Wings spread wide.",
                "We soar where others fall.",
                "The fire refines us. The sky awaits."
            ]
        ),
        Tribe(
            id: "shadow_panthers",
            name: "Shadow Panthers",
            animal: "Panther",
            motto: "Focus and precision",
            traits: "Strike from the dark. Silent, lethal execution.",
            symbol: "eye",
            warCries: [
                "Silent. Deadly. Unstoppable.",
                "The shadow strikes at dawn.",
                "Precision is our weapon.",
                "They never see us coming."
            ]
        ),
        Tribe(
            id: "thunder_bears",
            name: "Thunder Bears",
            animal: "Bear",
            motto: "Raw strength and endurance",
            traits: "Ground-shaking power. Unbreakable will.",
            symbol: "mountain.2",
            warCries: [
                "Thunder rolls. Bears stand.",
                "Unbreakable. Unstoppable. Unbowed.",
                "We endure what breaks others.",
                "Raw power. Iron will."
            ]
        ),
        Tribe(
            id: "flame_cobras",
            name: "Flame Cobras",
            animal: "Cobra",
            motto: "Agility and mental strike",
            traits: "Strike fast. Adapt faster. Never miss.",
            symbol: "bolt",
            warCries: [
                "Strike fast. Adapt faster.",
                "The cobra never misses.",
                "Agility is our edge.",
                "One strike. Total domination."
            ]
        ),
        Tribe(
            id: "storm_sharks",
            name: "Storm Sharks",
            animal: "Shark",
            motto: "Fearless domination",
            traits: "Chaos is our ocean. Aggressive and unstoppable.",
            symbol: "water.waves",
            warCries: [
                "Chaos is our ocean!",
                "Fearless in the storm.",
                "We dominate the deep.",
                "Aggression wins wars."
            ]
        ),
        Tribe(
            id: "forge_lions",
            name: "Forge Lions",
            animal: "Lion",
            motto: "Leadership and courage",
            traits: "Kings of the forge. Roar louder than fear.",
            symbol: "crown",
            warCries: [
                "Roar louder than your fear!",
                "Kings are forged in fire.",
                "Lead the pack. Own the day.",
                "Courage is our crown."
            ]
        )
    ]

    private static let legacyIDs: [String: String] = [
        "wolf_pack": "iron_wolves",
        "phoenix": "phoenix_eagles",
        "iron_legion": "thunder_bears",
        "flamekeepers": "flame_cobras",
        "stormwalkers": "storm_sharks",
        "the_forged": "forge_lions",
        "shadow_blades": "shadow_panthers"
    ]

    static func normalizeID(_ id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        if all.contains(where: { $0.id == id }) { return id }
        return legacyIDs[id]
    }

    static func byID(_ id: String?) -> Tribe? {
        guard let normalized = normalizeID(id) else { return nil }
        return all.first { $0.id == normalized }
    }

    static func level(fromTotalPoints total: Int) -> Int {
        if total < 100 { return 1 }
        return (total / 500) + 1
    }

    static func pointsToNextLevel(_ total: Int) -> Int {
        let current = level(fromTotalPoints: total)
        return current * 500 - total
    }

    static func xpBonusPercent(forLevel level: Int) -> Int {
        min(20, max(0, (level - 1) * 2))
    }
}

struct TribeLeaderboardEntry: Identifiable, Hashable {
    var id: String { tribe.id }
    let tribe: Tribe
    let weeklyPoints: Int
    let totalPoints: Int
    let level: Int
    let rank: Int
    let isUserTribe: Bool
}

struct TribeActivity: Identifiable, Hashable {
    let id: String
    let userName: String
    let message: String
    let timestamp: Date
    let type: String

    var timeAgo: String {
        let diff = Date().timeIntervalSince(timestamp)
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86_400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86_400))d ago"
    }

    var isKnownType: Bool {
        type == "joined" || type == "goal_completed"
    }
}

struct Mission: Identifiable, Hashable {
    let id: Int
    let title: String
    let detail: String
    let xp: Int
}

enum SampleContent {
    static let quotes = [
        "Who's gonna carry the boats?",
        "Discipline equals freedom.",
        "Stay hard.",
        "Pain is the price of progress.",
        "You vs you.",
        "The fire never dies.",
        "Own the day.",
        "Embrace the suck."
    ]

    static let missions: [Mission] = [
        Mission(id: 0, title: "Zero Dawn", detail: "Wake up before 05:30", xp: 75),
        Mission(id: 1, title: "Ice Forged", detail: "Five minutes of cold exposure", xp: 100),
        Mission(id: 2, title: "Night Ops", detail: "Lights out before 22:00", xp: 60)
    ]

    static func quote(for date: Date = .now) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return quotes[day % quotes.count]
    }
}
