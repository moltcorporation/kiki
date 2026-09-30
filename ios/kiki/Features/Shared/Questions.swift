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
        case .start: "New to running? Start here"
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
        case .new: "New to running"
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
            .init(value: .other, title: "Other", subtitle: "Enter distance"),
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

// MARK: - Defaults

/// Starting values for inputs: realistic for an average runner and rounded
/// the way a person would pick them. Used by onboarding and the You tab.
enum Defaults {
    static let age = 35
    static let heightCm = 170.0     // 5′7″
    static let weightKg = 72.0      // 159 lb
    static let customDistanceKm = 16.09344  // 10 mi / 16 km

    /// A typical recreational goal for the distance, in seconds.
    static func goalTime(meters: Double) -> Int {
        switch Int(meters.rounded()) {
        case 5000: return 30 * 60
        case 10000: return 60 * 60
        case 21097: return 2 * 3600 + 15 * 60
        case 42195: return 4 * 3600 + 30 * 60
        default:
            // About 6:30/km, rounded to 5 minutes.
            let raw = meters / 1000 * 390
            return max(5, Int((raw / 300).rounded())) * 300
        }
    }
}

// MARK: - Body inputs

struct AgeInput: View {
    @Binding var age: Int

    var body: some View {
        RulerPicker(value: $age, range: 13...90) { "\($0)" }
    }
}

/// Units for height and weight. They follow the runner's distance units
/// (miles -> ft/lb, kilometers -> cm/kg) until switched, and one switch
/// applies to both. Values are always stored metric; only display converts.
enum BodyUnits {
    static let storageKey = "bodyUnits"

    static func resolve(_ stored: String, default distanceUnits: Units) -> Units {
        Units(rawValue: stored) ?? distanceUnits
    }
}

/// Small imperial/metric switch shown above a body input.
private struct BodyUnitsPicker: View {
    @Binding var stored: String
    let current: Units
    let imperial: String
    let metric: String

    var body: some View {
        Picker("Units", selection: Binding(get: { current }, set: { stored = $0.rawValue })) {
            Text(imperial).tag(Units.mi)
            Text(metric).tag(Units.km)
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
        .onChange(of: current) { Haptics.select() }
    }
}

struct HeightInput: View {
    @Binding var heightCm: Double
    /// The runner's distance units; height follows them unless switched.
    let units: Units
    @AppStorage(BodyUnits.storageKey) private var stored = ""

    var body: some View {
        let bodyUnits = BodyUnits.resolve(stored, default: units)
        VStack(spacing: 32) {
            BodyUnitsPicker(stored: $stored, current: bodyUnits, imperial: "ft / in", metric: "cm")
            if bodyUnits == .mi {
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
}

struct WeightInput: View {
    @Binding var weightKg: Double
    /// The runner's distance units; weight follows them unless switched.
    let units: Units
    @AppStorage(BodyUnits.storageKey) private var stored = ""

    var body: some View {
        let bodyUnits = BodyUnits.resolve(stored, default: units)
        VStack(spacing: 32) {
            BodyUnitsPicker(stored: $stored, current: bodyUnits, imperial: "lb", metric: "kg")
            if bodyUnits == .mi {
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
}

nonisolated extension Profile {
    var age: Int? { birthYear.map { Calendar.current.component(.year, from: .now) - $0 } }

    static func birthYear(forAge age: Int) -> Int {
        Calendar.current.component(.year, from: .now) - age
    }
}
