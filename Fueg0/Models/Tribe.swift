import SwiftUI

struct Tribe: Identifiable, Hashable {
    let id: String
    let name: String
    let animal: String
    let motto: String
    let traits: String
    let symbol: String
    let warCry: String

    static let all: [Tribe] = [
        Tribe(
            id: "iron_wolves",
            name: "Iron Wolves",
            animal: "Wolf",
            motto: "Loyalty and pack power",
            traits: "The pack never breaks. Iron discipline, united strength.",
            symbol: "pawprint",
            warCry: "We run together, we rise together."
        ),
        Tribe(
            id: "phoenix_eagles",
            name: "Phoenix Eagles",
            animal: "Eagle",
            motto: "Resilience and vision",
            traits: "From ashes we rise. Soar higher than the storm.",
            symbol: "bird",
            warCry: "The fire refines us. The sky awaits."
        ),
        Tribe(
            id: "shadow_panthers",
            name: "Shadow Panthers",
            animal: "Panther",
            motto: "Focus and precision",
            traits: "Strike from the dark. Silent, lethal execution.",
            symbol: "eye",
            warCry: "Precision is our weapon."
        ),
        Tribe(
            id: "thunder_bears",
            name: "Thunder Bears",
            animal: "Bear",
            motto: "Raw strength and endurance",
            traits: "Ground-shaking power. Unbreakable will.",
            symbol: "mountain.2",
            warCry: "We endure what breaks others."
        ),
        Tribe(
            id: "flame_cobras",
            name: "Flame Cobras",
            animal: "Cobra",
            motto: "Agility and mental strike",
            traits: "Strike fast. Adapt faster. Never miss.",
            symbol: "bolt",
            warCry: "One strike. Total domination."
        ),
        Tribe(
            id: "storm_sharks",
            name: "Storm Sharks",
            animal: "Shark",
            motto: "Fearless domination",
            traits: "Chaos is our ocean. Aggressive and unstoppable.",
            symbol: "water.waves",
            warCry: "Fearless in the storm."
        ),
        Tribe(
            id: "forge_lions",
            name: "Forge Lions",
            animal: "Lion",
            motto: "Leadership and courage",
            traits: "Kings of the forge. Roar louder than fear.",
            symbol: "crown",
            warCry: "Kings are forged in fire."
        )
    ]

    static func byID(_ id: String?) -> Tribe? {
        guard let id else { return nil }
        return all.first { $0.id == id }
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
