import SwiftUI

// The single source of truth for runner questions: options, labels and inputs.
// Onboarding and the You tab both use these, so a question only changes here.

extension GoalKind {
    var title: String {
        switch self {
        case .start: "Start running"
        case .race: "Train for a race"
        case .faster: "Get faster"
        case .fit: "Stay fit & consistent"
        }
    }

    var subtitle: String {
        switch self {
        case .start: "Run 30 minutes non-stop"
        case .race: "Get ready for race day"
        case .faster: "Improve your time"
        case .fit: "Run regularly and enjoy it"
        }
    }

    var icon: String {
        switch self {
        case .start: "figure.walk"
        case .race: "flag.checkered"
        case .faster: "stopwatch"
        case .fit: "heart"
        }
    }
}

extension Experience {
    var title: String {
        switch self {
        case .new: "Beginner"
        case .beginner: "Intermediate"
        case .intermediate: "Advanced"
        case .advanced: "Elite"
        }
    }

    func subtitle(units: Units) -> String {
        let miles = units == .mi
        return switch self {
        case .new: miles ? "New to running or can run less than half a mile without stopping." : "New to running or can run less than 1 km without stopping."
        case .beginner: miles ? "Can run 1–3 miles continuously." : "Can run 1.5–5 km continuously."
        case .intermediate: miles ? "Can comfortably run 3–6 miles without stopping." : "Can comfortably run 5–10 km without stopping."
        case .advanced: miles ? "Regularly runs 6+ miles without stopping." : "Regularly runs 10+ km without stopping."
        }
    }

    var level: Int {
        switch self {
        case .new: 1
        case .beginner: 2
        case .intermediate: 3
        case .advanced: 4
        }
    }

    /// Rough longest recent run, used as a plan input.
    var typicalLongestRunM: Int {
        switch self {
        case .new: 1000
        case .beginner: 5000
        case .intermediate: 10000
        case .advanced: 16000
        }
    }
}

extension CoachingStyle {
    var title: String {
        switch self {
        case .gentle: "Gentle"
        case .balanced: "Balanced"
        case .push: "Push me"
        }
    }

    var subtitle: String {
        switch self {
        case .gentle: "Build slowly with extra rest and lots of encouragement"
        case .balanced: "Steady progress with a supportive coach"
        case .push: "Challenge me and keep me accountable"
        }
    }

    var icon: String {
        switch self {
        case .gentle: "leaf"
        case .balanced: "circle.lefthalf.filled"
        case .push: "flame"
        }
    }
}

extension Units {
    var title: String { self == .mi ? "Miles" : "Kilometers" }
}

enum Questions {
    static let goals: [ChoiceList<GoalKind>.Option] = GoalKind.allCases.map {
        .init(value: $0, title: $0.title, subtitle: $0.subtitle, icon: $0.icon)
    }

    static let units: [ChoiceList<Units>.Option] = [
        .init(value: .mi, title: Units.mi.title),
        .init(value: .km, title: Units.km.title),
    ]

    static func distances(units: Units) -> [ChoiceList<RaceDistance>.Option] {
        let miles = units == .mi
        return [
            .init(value: .fiveK, title: "5K", subtitle: miles ? "3.1 miles" : "5 kilometers"),
            .init(value: .tenK, title: "10K", subtitle: miles ? "6.2 miles" : "10 kilometers"),
            .init(value: .half, title: "Half Marathon", subtitle: miles ? "13.1 miles" : "21.1 kilometers"),
            .init(value: .marathon, title: "Marathon", subtitle: miles ? "26.2 miles" : "42.2 kilometers"),
            .init(value: .other, title: "Another distance"),
        ]
    }

    static func experience(units: Units) -> [ChoiceList<Experience>.Option] {
        Experience.allCases.map { .init(value: $0, title: $0.title, subtitle: $0.subtitle(units: units), level: $0.level) }
    }

    static let coachingStyles: [ChoiceList<CoachingStyle>.Option] = CoachingStyle.allCases.map {
        .init(value: $0, title: $0.title, subtitle: $0.subtitle, icon: $0.icon)
    }

    static func weeklyVolume(units: Units) -> [ChoiceList<Int>.Option] {
        let km = units == .km
        return [
            .init(value: 6_000, title: km ? "Less than 10 km" : "Less than 6 miles"),
            .init(value: 15_000, title: km ? "10–20 km" : "6–12 miles"),
            .init(value: 27_000, title: km ? "20–35 km" : "12–22 miles"),
            .init(value: 45_000, title: km ? "35–55 km" : "22–34 miles"),
            .init(value: 65_000, title: km ? "More than 55 km" : "More than 34 miles"),
        ]
    }

    static let referralSources = [
        "Instagram", "Facebook", "TikTok", "YouTube", "Google",
        "Friend or family", "Running club", "App Store", "Other",
    ]

    /// Picks a weekend day for the long run when available.
    static func longRunDay(for days: Set<Int>) -> Int {
        if days.contains(6) { return 6 }
        if days.contains(7) { return 7 }
        return days.max() ?? 6
    }
}

// MARK: - Body inputs

struct AgeInput: View {
    @Binding var age: Int

    var body: some View {
        RulerPicker(value: $age, range: 13...90) { "\($0)" }
    }
}

struct HeightInput: View {
    @Binding var heightCm: Double
    let units: Units

    var body: some View {
        if units == .mi {
            RulerPicker(
                value: Binding(get: { Int((heightCm / 2.54).rounded()) }, set: { heightCm = Double($0) * 2.54 }),
                range: 48...90,
                majorEvery: 12
            ) { "\($0 / 12)′ \($0 % 12)″" }
        } else {
            RulerPicker(
                value: Binding(get: { Int(heightCm.rounded()) }, set: { heightCm = Double($0) }),
                range: 120...220
            ) { "\($0) cm" }
        }
    }
}

struct WeightInput: View {
    @Binding var weightKg: Double
    let units: Units

    var body: some View {
        if units == .mi {
            RulerPicker(
                value: Binding(get: { Int((weightKg / 0.453592).rounded()) }, set: { weightKg = Double($0) * 0.453592 }),
                range: 80...400
            ) { "\($0) lb" }
        } else {
            RulerPicker(
                value: Binding(get: { Int(weightKg.rounded()) }, set: { weightKg = Double($0) }),
                range: 35...180
            ) { "\($0) kg" }
        }
    }
}

nonisolated extension Profile {
    var age: Int? { birthYear.map { Calendar.current.component(.year, from: .now) - $0 } }

    static func birthYear(forAge age: Int) -> Int {
        Calendar.current.component(.year, from: .now) - age
    }
}
