import Foundation

/// Answers collected during onboarding, and which screen comes next.
@Observable
final class OnboardingModel {
    enum Step: String, Codable, CaseIterable {
        case distance, raceDate, experience, weeklyVolume, longestRun, goal, goalTime, recentRace
        case adaptInfo, runDays, longRunDay, name, age, body, injury, notifications, account
        case generating, preview
    }

    struct Answers: Codable {
        var units: Units = .localeDefault
        var raceDistance: RaceDistance?
        var customDistanceKm: Double = 15
        var raceDate: Day?
        var raceName = ""
        var experience: Experience?
        var weeklyDistanceM: Int?
        var longestRunM: Int?
        var goalType: GoalType?
        var goalTimeS: Int?
        var recentRaceDistance: RaceDistance?
        var recentRaceTimeS: Int?
        var runDays: Set<Int> = []
        var longRunDay: Int?
        var firstName = ""
        var birthYear: Int?
        var heightCm: Double?
        var weightKg: Double?
        var hasInjury: Bool?
        var injury = ""
    }

    var answers: Answers { didSet { save() } }
    private(set) var path: [Step] = [] { didSet { save() } }
    /// Set when the runner is already signed in, so the account step is skipped.
    var isSignedIn = false

    private static let storageKey = "onboarding.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            answers = saved.answers
            path = saved.path
        } else {
            answers = Answers()
        }
    }

    var current: Step { path.last ?? .distance }

    /// Progress through the question screens (0…1) for the header bar.
    var progress: Double {
        let questions = flow.filter { $0 != .generating && $0 != .preview }
        guard let index = questions.firstIndex(of: current) else { return 1 }
        return Double(index + 1) / Double(questions.count)
    }

    /// The ordered screens for the current answers.
    var flow: [Step] {
        var steps: [Step] = [.distance, .raceDate, .experience, .weeklyVolume, .longestRun, .goal]
        if answers.goalType == .time { steps += [.goalTime, .recentRace] }
        steps += [.adaptInfo, .runDays, .longRunDay, .name, .age, .body, .injury, .notifications]
        if !isSignedIn { steps.append(.account) }
        steps += [.generating, .preview]
        return steps
    }

    func start() {
        if path.isEmpty { path = [.distance] }
        Analytics.track("onboarding_started")
    }

    func advance() {
        let steps = flow
        guard let index = steps.firstIndex(of: current), index + 1 < steps.count else { return }
        let next = steps[index + 1]
        Analytics.track("onboarding_step_completed", ["step": current.rawValue])
        path.append(next)
    }

    func back() {
        guard path.count > 1 else { return }
        path.removeLast()
    }

    func go(to step: Step) {
        path.append(step)
    }

    func reset() {
        answers = Answers()
        path = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: Building requests

    var profile: Profile {
        Profile(
            firstName: answers.firstName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            units: answers.units,
            timezone: TimeZone.current.identifier,
            birthYear: answers.birthYear,
            heightCm: answers.heightCm,
            weightKg: answers.weightKg,
            experience: answers.experience ?? .beginner,
            weeklyDistanceM: answers.weeklyDistanceM ?? 0,
            longestRunM: answers.longestRunM ?? 0,
            runDays: answers.runDays.sorted(),
            longRunDay: answers.longRunDay ?? answers.runDays.max() ?? 6,
            injury: answers.hasInjury == true ? answers.injury.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "Yes, unspecified" : nil,
            extras: nil
        )
    }

    var planRequest: PlanRequest {
        let distance = answers.raceDistance ?? .half
        let recent = answers.recentRaceTimeS != nil ? answers.recentRaceDistance?.meters : nil
        return PlanRequest(
            raceDistance: distance,
            raceDistanceM: distance == .other ? Int(answers.customDistanceKm * 1000) : nil,
            raceName: answers.raceName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            raceDate: answers.raceDate ?? suggestedRaceDate,
            goalType: answers.goalType ?? .finish,
            goalTimeS: answers.goalType == .time ? answers.goalTimeS : nil,
            recentRaceDistanceM: recent,
            recentRaceTimeS: recent != nil ? answers.recentRaceTimeS : nil
        )
    }

    /// A sensible race date when the runner doesn't have one yet.
    var suggestedRaceDate: Day {
        let weeks: Int = switch answers.raceDistance ?? .half {
        case .fiveK: 8
        case .tenK: 10
        case .half: 12
        case .marathon: answers.experience == .advanced ? 16 : 18
        case .other: 12
        }
        // Races are usually on weekends: land on a Sunday.
        let target = Day.today.adding(days: weeks * 7)
        return target.mondayOfWeek.adding(days: 6)
    }

    /// Typical training days for the runner's experience.
    var suggestedRunDays: Set<Int> {
        switch answers.experience ?? .beginner {
        case .new: [2, 4, 6]
        case .beginner: [2, 4, 6, 7]
        case .intermediate: [1, 2, 4, 6, 7]
        case .advanced: [1, 2, 3, 4, 6, 7]
        }
    }

    private struct Saved: Codable {
        let answers: Answers
        let path: [Step]
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(Saved(answers: answers, path: path)) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
