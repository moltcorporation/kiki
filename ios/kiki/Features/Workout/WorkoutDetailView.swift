import SwiftUI

/// One workout, made simple: when it is, what it is and how it should feel,
/// the three numbers that matter (distance, time, effort), exactly what to
/// do step by step, and Start run / Mark done / Adjust or skip at the bottom.
struct WorkoutDetailView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker

    let workoutID: UUID

    @State private var sheet: AppSheet?

    var body: some View {
        if let workout = store.workouts.first(where: { $0.id == workoutID }) {
            content(workout)
        } else {
            ContentUnavailableView("Workout not found", systemImage: "calendar.badge.exclamationmark")
        }
    }

    private func content(_ workout: Workout) -> some View {
        let units = store.units
        let run = store.run(for: workout)
        let paces = store.plan?.paces

        return DetailPage {
            // When, what, and how it should feel.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(dateLine(workout.date))
                    .font(.eyebrow)
                    .foregroundStyle(.muted)
                Text(workout.isRest ? "Rest day" : workout.title)
                    .font(.screenTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(workout.description)
                    .font(.body)
                    .foregroundStyle(.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xxs)
            }

            if !workout.isRest {
                // The three numbers that matter.
                HStack(spacing: Spacing.s) {
                    if let meters = workout.distanceM {
                        StatTile(value: Format.distance(Double(meters), units), label: "Distance")
                    }
                    if let minutes = workout.plannedMinutes(paces: paces) {
                        StatTile(value: "\(minutes) min", label: "About")
                    }
                    StatTile(value: workout.type.effort, label: "Effort")
                }

                PageSection("What to do") {
                    StepList(workout: workout, units: units, paces: paces)
                }
            }

            if let run {
                PageSection("Your run") {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            RunSummaryLine(run: run, units: units)
                            if let notes = run.notes, !notes.isEmpty {
                                Text("“\(notes)”").font(.detail).foregroundStyle(.muted)
                            }
                        }
                    }
                }
            }
        }
        .bottomActions {
            if !workout.isRest || workout.status == .completed {
                actions(workout, run: run)
            }
        }
        .appSheets($sheet)
        .onAppear { Analytics.screen("Workout Detail", ["type": workout.type.rawValue]) }
    }

    /// Today: Start run, with Mark done and Adjust or skip beneath. Other
    /// days: Mark done, with Adjust or skip. Done: Edit run. Skipped: Undo.
    @ViewBuilder
    private func actions(_ workout: Workout, run: Run?) -> some View {
        switch workout.status {
        case .completed:
            SecondaryButton("Edit run", systemImage: "pencil") { sheet = .log(workout, run) }
        case .skipped:
            SecondaryButton("Undo skip", systemImage: "arrow.uturn.backward") {
                Haptics.tap()
                store.setStatus(.planned, for: workout)
            }
        case .planned:
            if workout.date == .today {
                PrimaryButton("Start run", systemImage: "play.fill") { tracker.start(for: workout) }
                HStack(spacing: 0) {
                    textAction("Mark done", systemImage: "checkmark") { sheet = .log(workout, run) }
                    Rectangle().fill(Color.hairline).frame(width: 1, height: Spacing.l)
                    textAction("Adjust or skip", systemImage: "slider.horizontal.3") { sheet = .adjustDay(workout) }
                }
            } else {
                PrimaryButton("Mark done", systemImage: "checkmark") { sheet = .log(workout, run) }
                textAction("Adjust or skip", systemImage: "slider.horizontal.3") { sheet = .adjustDay(workout) }
            }
        }
    }

    private func textAction(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.ink)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.haptic)
    }

    /// "Today · Thu, Oct 1", "Tomorrow · Fri, Oct 2", or "Tue, Oct 6".
    private func dateLine(_ day: Day) -> String {
        let date = day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let relative: String? = switch Day.today.days(until: day) {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        default: nil
        }
        return [relative, date].compactMap { $0 }.joined(separator: " · ")
    }
}

/// A small white tile: a bold value over its label ("2.0 mi" / "Distance").
private struct StatTile: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value)
                .font(.metric(.title3))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.muted)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard(cornerRadius: Radius.control)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Steps

/// The workout's steps in one card: warm up, the main set (a "Repeat 6
/// times" group for intervals), cool down. Workouts without steps show one
/// step for the whole run.
private struct StepList: View {
    let workout: Workout
    let units: Units
    let paces: PaceZones?

    /// A step, or a repeated set of steps.
    private enum Block: Identifiable {
        case single(Int, WorkoutStep)
        case repeated(Int, times: Int, [WorkoutStep])

        var id: Int {
            switch self {
            case .single(let index, _), .repeated(let index, _, _): index
            }
        }
    }

    var body: some View {
        let blocks = Self.blocks(for: workout)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                if block.id != blocks.first?.id {
                    Divider()
                }
                switch block {
                case .single(_, let step):
                    StepRow(step: step, workout: workout, units: units, paces: paces)
                case .repeated(_, let times, let steps):
                    VStack(alignment: .leading, spacing: 0) {
                        Label("Repeat \(times) times", systemImage: "repeat")
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, Spacing.m)
                            .padding(.bottom, Spacing.xs)
                        // The repeated steps, indented under a guide line.
                        HStack(alignment: .top, spacing: Spacing.m) {
                            Rectangle()
                                .fill(Color.track)
                                .frame(width: 1.5)
                                .padding(.leading, Spacing.s)
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                                    StepRow(step: step, workout: workout, units: units, paces: paces)
                                }
                            }
                        }
                        .padding(.bottom, Spacing.s)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.horizontal, Metrics.cardPadding - Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
    }

    /// Groups a work step with a repeat count and the recovery after it.
    /// No steps: one step covering the whole run.
    private static func blocks(for workout: Workout) -> [Block] {
        let steps = workout.steps.isEmpty
            ? [WorkoutStep(kind: .work, distanceM: workout.distanceM, durationS: workout.distanceM == nil ? workout.durationS : nil,
                           repeatCount: nil, pace: workout.type.paceZone, note: nil)]
            : workout.steps
        var blocks: [Block] = []
        var index = 0
        while index < steps.count {
            let step = steps[index]
            if step.kind == .work, let times = step.repeatCount, times > 1 {
                var group = [step]
                if index + 1 < steps.count, steps[index + 1].kind == .recovery {
                    group.append(steps[index + 1])
                    index += 1
                }
                blocks.append(.repeated(index, times: times, group))
            } else {
                blocks.append(.single(index, step))
            }
            index += 1
        }
        return blocks
    }
}

/// One step: an effort bar, what to do and how, and how much.
private struct StepRow: View {
    let step: WorkoutStep
    let workout: Workout
    let units: Units
    let paces: PaceZones?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            Capsule()
                .fill(barColor)
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.rowTitle)
                if let detail {
                    Text(detail).font(.detail).foregroundStyle(.muted)
                }
            }
            Spacer(minLength: Spacing.s)
            Text(amount)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.m)
        .accessibilityElement(children: .combine)
    }

    /// Walk breaks: the recovery in a run/walk easy run.
    private var isWalk: Bool { [.runWalk, .easy].contains(workout.type) && step.kind == .recovery }

    private var title: String {
        switch step.kind {
        case .warmup: "Warm up"
        case .cooldown: "Cool down"
        case .recovery: isWalk ? "Walk" : "Recover"
        case .work:
            switch workout.type {
            case .tempo, .progression: "Tempo"
            case .intervals, .hills, .fartlek: "Fast"
            case .racePace: "Race pace"
            default: "Run"
            }
        }
    }

    /// How it should feel and the pace range. Fixed copy (never the AI's
    /// notes), so every workout reads the same way.
    private var detail: String? {
        if isWalk { return "Catch your breath" }
        if step.kind == .recovery { return "Easy jog or walk" }
        if workout.type == .runWalk {
            if step.kind == .warmup { return "Brisk walk" }
            if step.kind == .cooldown { return "Easy walk" }
        }
        guard let zone = step.pace ?? defaultZone else { return nil }
        let pace = (paces?[zone]).map { Format.targetPace($0, units) }
        return [zone.feel, pace].compactMap { $0 }.joined(separator: " · ")
    }

    private var defaultZone: PaceZone? {
        switch step.kind {
        case .warmup, .cooldown: .easy
        case .recovery: .recovery
        case .work: workout.type.paceZone
        }
    }

    private var amount: String {
        if let meters = step.distanceM { return Format.stepDistance(meters, units) }
        if let seconds = step.durationS { return Format.minutes(seconds) }
        return ""
    }

    /// Light for easy and walking, darker as the effort rises.
    private var barColor: Color {
        if isWalk || step.kind == .recovery || step.kind == .warmup || step.kind == .cooldown { return .track }
        switch step.pace ?? workout.type.paceZone {
        case .interval, .race: return .ink
        case .tempo, .long: return .ink.opacity(0.55)
        default: return .ink.opacity(0.3)
        }
    }
}

// MARK: - Labels

extension WorkoutType {
    /// How hard it is, in one word: Easy, Steady or Hard.
    var effort: String {
        switch self {
        case .long, .tempo, .progression: "Steady"
        case .intervals, .hills, .fartlek, .racePace, .race: "Hard"
        default: "Easy"
        }
    }
}

extension PaceZone {
    /// A step's effort in a word or two.
    var feel: String {
        switch self {
        case .easy, .recovery: "Easy"
        case .long: "Steady"
        case .tempo: "Comfortably hard"
        case .interval: "Hard"
        case .race: "Race pace"
        }
    }
}

extension Workout {
    /// Planned time in minutes, or the distance at the type's target pace.
    func plannedMinutes(paces: PaceZones?) -> Int? {
        if let seconds = durationS { return Int((Double(seconds) / 60).rounded()) }
        guard let meters = distanceM, let zone = type.paceZone, let target = paces?[zone] else { return nil }
        return Int((Double(meters) / 1000 * Double(target) / 60).rounded())
    }
}
