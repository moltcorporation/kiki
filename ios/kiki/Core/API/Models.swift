import Foundation

// MARK: - Calendar day

/// A calendar date without a time or time zone, encoded as "YYYY-MM-DD".
nonisolated struct Day: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let day = Day(string: string) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date \(string)"))
        }
        self = day
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    static var today: Day { Day(.now) }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// Midnight of this day in the current calendar.
    var date: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func adding(days: Int) -> Day {
        Day(Calendar.current.date(byAdding: .day, value: days, to: date)!)
    }

    func days(until other: Day) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: other.date).day ?? 0
    }

    /// ISO weekday: 1 = Monday … 7 = Sunday.
    var isoWeekday: Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    var mondayOfWeek: Day { adding(days: 1 - isoWeekday) }

    static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

// MARK: - Enums

nonisolated enum Units: String, Codable, CaseIterable, Sendable {
    case km, mi

    static var localeDefault: Units {
        Locale.current.measurementSystem == .metric ? .km : .mi
    }
}

nonisolated enum Experience: String, Codable, CaseIterable, Sendable {
    case new, beginner, intermediate, advanced
}

nonisolated enum RaceDistance: String, Codable, CaseIterable, Sendable {
    case fiveK = "5k", tenK = "10k", half, marathon, other

    var meters: Int? {
        switch self {
        case .fiveK: 5000
        case .tenK: 10000
        case .half: 21097
        case .marathon: 42195
        case .other: nil
        }
    }

    var label: String {
        switch self {
        case .fiveK: "5K"
        case .tenK: "10K"
        case .half: "Half Marathon"
        case .marathon: "Marathon"
        case .other: "Other distance"
        }
    }
}

/// What the runner wants from Kiki. Only used as input to plan generation;
/// the app itself never branches on it beyond labels.
/// Order is the order shown in onboarding; `race` is the default.
nonisolated enum GoalKind: String, Codable, CaseIterable, Sendable {
    case race, faster, start, fit
}

nonisolated enum CoachingStyle: String, Codable, CaseIterable, Sendable {
    case gentle, balanced, push
}

nonisolated enum GoalType: String, Codable, Sendable {
    case finish, time
}

nonisolated enum WorkoutType: String, Codable, CaseIterable, Sendable {
    case rest, easy, recovery, long, tempo, intervals, hills, fartlek, progression
    case runWalk = "run_walk"
    case racePace = "race_pace"
    case crossTraining = "cross_training"
    case race

    var label: String {
        switch self {
        case .rest: "Rest"
        case .runWalk: "Run/Walk"
        case .easy: "Easy"
        case .recovery: "Recovery"
        case .long: "Long Run"
        case .tempo: "Tempo"
        case .intervals: "Intervals"
        case .hills: "Hills"
        case .fartlek: "Fartlek"
        case .progression: "Progression"
        case .racePace: "Race Pace"
        case .crossTraining: "Cross-Train"
        case .race: "Race Day"
        }
    }

    var symbol: String {
        switch self {
        case .rest: "moon.zzz.fill"
        case .runWalk: "figure.walk"
        case .easy, .recovery: "figure.run"
        case .long: "road.lanes"
        case .tempo, .progression, .racePace: "speedometer"
        case .intervals, .fartlek: "bolt.fill"
        case .hills: "mountain.2.fill"
        case .crossTraining: "figure.mixed.cardio"
        case .race: "flag.checkered"
        }
    }

    var isQuality: Bool {
        [.tempo, .intervals, .hills, .fartlek, .progression, .racePace, .race].contains(self)
    }
}

nonisolated enum Feeling: String, Codable, CaseIterable, Sendable {
    case great, good, okay, tired, pain

    var label: String { rawValue.capitalized }

    var emoji: String {
        switch self {
        case .great: "🔥"
        case .good: "🙂"
        case .okay: "😐"
        case .tired: "😮‍💨"
        case .pain: "🤕"
        }
    }
}

nonisolated enum RunSource: String, Codable, Sendable {
    case kiki, manual
    case appleHealth = "apple_health"
    case strava
}

// MARK: - Entities

nonisolated struct Profile: Codable, Equatable, Sendable {
    var firstName: String?
    var units: Units
    var timezone: String
    var birthYear: Int?
    var heightCm: Double?
    var weightKg: Double?
    var coachingStyle: CoachingStyle?
    var experience: Experience
    var weeklyDistanceM: Int
    var longestRunM: Int
    var runDays: [Int]
    var longRunDay: Int
    var extras: [String: String]?
}

nonisolated struct PaceRange: Codable, Hashable, Sendable {
    let min: Int
    let max: Int
}

nonisolated struct PaceZones: Codable, Hashable, Sendable {
    let easy: PaceRange
    let long: PaceRange
    let tempo: PaceRange
    let interval: PaceRange
    let race: PaceRange
    let recovery: PaceRange

    subscript(zone: PaceZone) -> PaceRange {
        switch zone {
        case .easy: easy
        case .long: long
        case .tempo: tempo
        case .interval: interval
        case .race: race
        case .recovery: recovery
        }
    }
}

nonisolated enum PaceZone: String, Codable, Hashable, Sendable {
    case easy, long, tempo, interval, race, recovery
}

nonisolated struct Plan: Codable, Identifiable, Hashable, Sendable {
    nonisolated enum Status: String, Codable, Sendable { case generating, ready, failed, archived }

    let id: UUID
    let status: Status
    let goalKind: GoalKind
    let raceDistance: RaceDistance?
    let raceDistanceM: Int?
    let raceName: String?
    /// Last day of the plan (race day for race goals).
    let raceDate: Day
    let startDate: Day
    let goalType: GoalType
    let goalTimeS: Int?
    let title: String?
    let summary: String?
    let predictedTimeS: Int?
    let paces: PaceZones?
    let progress: Int

    /// The one place goal-specific wording lives.
    var displayName: String {
        if let raceName { return raceName }
        switch goalKind {
        case .start: return "Start running"
        case .fit: return "Stay fit"
        case .race: return raceDistance?.label ?? "Race"
        case .faster: return "Faster \(raceDistance?.label ?? "running")"
        }
    }
}

nonisolated struct WorkoutStep: Codable, Hashable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable { case warmup, work, recovery, cooldown }

    let kind: Kind
    let distanceM: Int?
    let durationS: Int?
    let repeatCount: Int?
    let pace: PaceZone?
    let note: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case kind, distanceM, durationS, pace, note
        case repeatCount = "repeat"
    }
}

nonisolated struct Workout: Codable, Identifiable, Hashable, Sendable {
    nonisolated enum Status: String, Codable, Sendable { case planned, completed, skipped }

    let id: UUID
    let planId: UUID
    var date: Day
    let week: Int
    var type: WorkoutType
    var title: String
    var description: String
    var distanceM: Int?
    var durationS: Int?
    var steps: [WorkoutStep]
    var status: Status

    var isRest: Bool { type == .rest }
}

nonisolated struct Run: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var workoutId: UUID?
    var source: RunSource
    var externalId: String?
    var startedAt: Date
    var distanceM: Double
    var durationS: Int
    var elevationGainM: Double?
    var avgHeartRate: Int?
    var route: String?
    var splits: [Split]?
    var effort: Int?
    var feeling: Feeling?
    var notes: String?

    nonisolated struct Split: Codable, Hashable, Sendable {
        let distanceM: Double
        let durationS: Double
    }

    /// Seconds per km.
    var pace: Double? { distanceM > 50 ? Double(durationS) / (distanceM / 1000) : nil }
}

nonisolated struct Adjustment: Codable, Identifiable, Sendable {
    nonisolated enum Status: String, Codable, Sendable { case pending, applied, failed }

    let id: UUID
    let status: Status
    let reply: String?
    let changedDates: [Day]?
}

nonisolated enum AdjustReason: String, Codable, CaseIterable, Sendable {
    case missed, tired, injured
    case tooEasy = "too_easy"
    case tooHard = "too_hard"
    case schedule, other

    var label: String {
        switch self {
        case .missed: "I missed a run"
        case .tired: "I'm feeling tired"
        case .injured: "Something hurts"
        case .tooEasy: "It's too easy"
        case .tooHard: "It's too hard"
        case .schedule: "My schedule changed"
        case .other: "Something else"
        }
    }

    var symbol: String {
        switch self {
        case .missed: "calendar.badge.exclamationmark"
        case .tired: "battery.25percent"
        case .injured: "bandage.fill"
        case .tooEasy: "arrow.up.right"
        case .tooHard: "arrow.down.right"
        case .schedule: "calendar"
        case .other: "text.bubble.fill"
        }
    }
}

// MARK: - Requests / responses

nonisolated struct PlanRequest: Encodable, Sendable {
    var goalKind: GoalKind
    var raceDistance: RaceDistance?
    var raceDistanceM: Int?
    var raceName: String?
    /// Race goals only; the server sets the end date for other goals.
    var raceDate: Day?
    /// "Get faster" goals only: 8 or 12.
    var weeks: Int?
    var goalType: GoalType
    var goalTimeS: Int?
}

nonisolated struct CurrentPlanResponse: Codable, Sendable {
    let plan: Plan?
    let workouts: [Workout]
    let pending: Plan?
}

nonisolated struct PlanResponse: Decodable, Sendable {
    let plan: Plan
    let workouts: [Workout]?
}

nonisolated struct MeResponse: Decodable, Sendable {
    nonisolated struct User: Decodable, Sendable {
        let id: String
        let email: String
        let name: String
    }
    let user: User
    let profile: Profile?
}
