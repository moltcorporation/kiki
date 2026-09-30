import Foundation

/// Answers collected during onboarding and which screen comes next.
///
/// Answers are only inputs: they become the runner's profile and their plan
/// request. The main app never depends on how a question was answered.
@Observable
final class OnboardingModel {
    enum Mode {
        /// First-run onboarding, persisted so it can resume.
        case full
        /// "Change goal" from the You tab: goal questions only, prefilled
        /// from the saved profile.
        case newGoal
    }

    enum Step: String, Codable {
        // Goal
        case goal, units, distance, raceDate, raceGoal, goalTime, timeframe
        // Running
        case experience, weeklyVolume, runDays, coachingStyle, goalCheck
        // About you
        case name, age, height, weight, flexibility, referral, notifications, summary
        // Plan
        case account, generating, preview
    }

    struct Answers: Codable {
        /// Preselected so the most common goal is one tap away.
        var goalKind: GoalKind? = .race
        var units: Units = .localeDefault
        var raceDistance: RaceDistance?
        var customDistanceKm: Double = 15
        var raceDate: Day?
        /// The runner chose "Not yet" for the race date; we suggest one.
        var noRaceDate = false
        var raceName = ""
        var goalType: GoalType?
        var goalTimeS: Int?
        /// Plan length for "get faster" goals.
        var weeks = 8
        var experience: Experience?
        var weeklyDistanceM: Int?
        var runDays: Set<Int> = []
        var coachingStyle: CoachingStyle?
        var firstName = ""
        var age: Int?
        var heightCm: Double?
        var weightKg: Double?
        var referralSource: String?
    }

    let mode: Mode
    /// Called when a "new goal" flow finishes or is cancelled.
    var onFinish: (() -> Void)?

    var answers: Answers { didSet { save() } }
    private(set) var path: [Step] = [] { didSet { save() } }
    /// Set when the runner is already signed in, so the account step is skipped.
    var isSignedIn = false

    private static let storageKey = "onboarding.v3"

    init(mode: Mode = .full, profile: Profile? = nil) {
        self.mode = mode
        if mode == .full,
           let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            answers = saved.answers
            path = saved.path
        } else {
            answers = Answers()
        }
        if let profile { seed(from: profile) }
        if mode == .newGoal {
            isSignedIn = true
            path = [.goal]
        }
    }

    /// Prefills everything except the goal from a saved profile.
    private func seed(from profile: Profile) {
        answers.units = profile.units
        answers.experience = profile.experience
        answers.weeklyDistanceM = profile.weeklyDistanceM
        answers.runDays = Set(profile.runDays)
        answers.coachingStyle = profile.coachingStyle ?? .balanced
        answers.firstName = profile.firstName ?? ""
        answers.age = profile.age
        answers.heightCm = profile.heightCm
        answers.weightKg = profile.weightKg
    }

    var current: Step { path.last ?? .goal }

    var firstName: String? { answers.firstName.trimmingCharacters(in: .whitespaces).nilIfEmpty }

    /// The ordered screens for the current answers.
    var flow: [Step] {
        var steps: [Step] = [.goal]
        if mode == .full { steps.append(.units) }

        switch answers.goalKind {
        case .race:
            steps += [.distance, .raceDate, .raceGoal]
            if answers.goalType == .time { steps.append(.goalTime) }
        case .faster:
            steps += [.distance, .goalTime, .timeframe]
        case .start, .fit, nil:
            break
        }

        if mode == .full {
            steps.append(.experience)
            if let experience = answers.experience, experience != .new { steps.append(.weeklyVolume) }
            steps += [.runDays, .coachingStyle]
        }
        steps.append(.goalCheck)

        if mode == .full {
            steps += [.name, .age, .height, .weight, .flexibility, .referral, .notifications, .summary]
            if !isSignedIn { steps.append(.account) }
        }
        steps += [.generating, .preview]
        return steps
    }

    /// Current screen number and total, for the segmented header.
    var stepPosition: (step: Int, total: Int) {
        let screens = flow.filter { $0 != .generating && $0 != .preview }
        guard let index = screens.firstIndex(of: current) else { return (screens.count, screens.count) }
        return (index + 1, screens.count)
    }

    // MARK: Navigation

    enum Direction { case forward, backward }

    /// Direction of the last navigation, for slide transitions.
    private(set) var direction: Direction = .forward
    private var isNavigating = false

    /// Plan building and preview have no back; a signed-in runner can't
    /// leave the account step while their account loads.
    var canGoBack: Bool {
        switch current {
        case .generating, .preview: false
        case .account: !isSignedIn
        default: path.count > 1 || mode == .newGoal || !isSignedIn
        }
    }

    var showsHeader: Bool { current != .generating && current != .preview }

    func start() {
        guard path.isEmpty else { return }
        direction = .forward
        path = [.goal]
        Analytics.track("onboarding_started")
    }

    func advance() {
        let steps = flow
        guard let index = steps.firstIndex(of: current), index + 1 < steps.count else { return }
        let from = current
        navigate(.forward) { [self] in
            Analytics.track("onboarding_step_completed", ["step": from.rawValue, "mode": mode == .full ? "full" : "new_goal"])
            path.append(steps[index + 1])
        }
    }

    /// Goes back one screen, skipping screens no longer in the flow. From the
    /// first screen, returns to the welcome screen (keeping answers) or
    /// cancels a "new goal" flow.
    func back() {
        guard canGoBack else { return }
        navigate(.backward) { [self] in
            guard path.count > 1 else {
                if mode == .newGoal { onFinish?() } else { path = [] }
                return
            }
            path.removeLast()
            while path.count > 1, let last = path.last, !flow.contains(last) {
                path.removeLast()
            }
        }
    }

    func go(to step: Step) {
        navigate(.forward) { [self] in path.append(step) }
    }

    /// Ends onboarding once the plan is ready.
    func finish() {
        if mode == .newGoal {
            onFinish?()
        } else {
            reset()
        }
    }

    /// Sets the direction first, then changes the screen on the next run loop,
    /// so the outgoing screen renders with the new direction before it slides
    /// out. Ignores taps while a navigation is in flight.
    private func navigate(_ direction: Direction, _ change: @escaping () -> Void) {
        guard !isNavigating else { return }
        isNavigating = true
        self.direction = direction
        Task { @MainActor in
            change()
            isNavigating = false
        }
    }

    func reset() {
        answers = Answers()
        path = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: Building requests

    var profile: Profile {
        let experience = answers.experience ?? .new
        return Profile(
            firstName: firstName,
            units: answers.units,
            timezone: TimeZone.current.identifier,
            birthYear: answers.age.map(Profile.birthYear(forAge:)),
            heightCm: answers.heightCm,
            weightKg: answers.weightKg,
            coachingStyle: answers.coachingStyle ?? .balanced,
            experience: experience,
            weeklyDistanceM: experience == .new ? 0 : (answers.weeklyDistanceM ?? 0),
            longestRunM: experience.typicalLongestRunM,
            runDays: answers.runDays.sorted(),
            longRunDay: Questions.longRunDay(for: answers.runDays),
            extras: answers.referralSource.map { ["referralSource": $0] }
        )
    }

    var planRequest: PlanRequest {
        let kind = answers.goalKind ?? .race
        let distance = answers.raceDistance
        let customM = distance == .other ? Int(answers.customDistanceKm * 1000) : nil
        switch kind {
        case .race:
            let goalType = answers.goalType ?? .finish
            return PlanRequest(
                goalKind: .race,
                raceDistance: distance ?? .fiveK,
                raceDistanceM: customM,
                raceName: answers.raceName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                raceDate: answers.noRaceDate ? suggestedRaceDate : (answers.raceDate ?? suggestedRaceDate),
                weeks: nil,
                goalType: goalType,
                goalTimeS: goalType == .time ? answers.goalTimeS : nil
            )
        case .faster:
            return PlanRequest(
                goalKind: .faster,
                raceDistance: distance ?? .fiveK,
                raceDistanceM: customM,
                raceName: nil,
                raceDate: nil,
                weeks: answers.weeks,
                goalType: .time,
                goalTimeS: answers.goalTimeS ?? defaultGoalTime
            )
        case .start, .fit:
            return PlanRequest(goalKind: kind, raceDistance: nil, raceDistanceM: nil, raceName: nil,
                               raceDate: nil, weeks: nil, goalType: .finish, goalTimeS: nil)
        }
    }

    /// A sensible race date when the runner doesn't have one yet (a Sunday).
    var suggestedRaceDate: Day {
        let weeks: Int = switch answers.raceDistance ?? .half {
        case .fiveK: 8
        case .tenK: 10
        case .half: 12
        case .marathon: answers.experience == .advanced ? 16 : 18
        case .other: 12
        }
        return Day.today.adding(days: weeks * 7).mondayOfWeek.adding(days: 6)
    }

    /// Starting value for the goal-time wheel.
    var defaultGoalTime: Int {
        switch answers.raceDistance ?? .fiveK {
        case .fiveK: 28 * 60
        case .tenK: 58 * 60
        case .half: 2 * 3600 + 5 * 60
        case .marathon: 4 * 3600 + 30 * 60
        case .other: Int(answers.customDistanceKm * 360)
        }
    }

    /// Typical training days for the runner's experience.
    var suggestedRunDays: Set<Int> {
        switch answers.experience ?? .new {
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
        guard mode == .full, let data = try? JSONEncoder().encode(Saved(answers: answers, path: path)) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
