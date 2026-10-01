import SwiftUI

/// One workout, made simple: the date big at the top, what to run, exactly
/// what to do, and clear actions (Mark as done, Skip, Change workout).
struct WorkoutDetailView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker

    let workoutID: UUID

    @State private var sheet: AppSheet?
    @State private var showChangeSoon = false

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

        return DetailPage {
            // The date leads.
            PageHeader(
                eyebrow: relativeDay(workout.date).map { LocalizedStringKey($0) },
                title: LocalizedStringKey(workout.date.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            )

            // What to run.
            Card {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    HStack(spacing: RowMetrics.spacing) {
                        WorkoutIcon(workout: workout, size: .large)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(workout.type.label)
                                .font(.eyebrow)
                                .foregroundStyle(.muted)
                            Text(workout.title)
                                .font(.cardTitle)
                        }
                        Spacer(minLength: 0)
                        StatusBadge(status: workout.status)
                    }
                    if !workout.isRest {
                        Divider()
                        VStack(alignment: .leading, spacing: Spacing.l) {
                            if let metric = Format.workoutMetric(workout, units: units) {
                                DetailLine(label: "Distance", value: "\(metric.value) \(metric.unit)")
                            }
                            if let zone = workout.type.paceZone {
                                if let range = store.plan?.paces?[zone] {
                                    let perUnit = units == .mi ? "per mile" : "per km"
                                    DetailLine(
                                        label: "Pace",
                                        value: "About \(Format.pace(Double(range.min + range.max) / 2, units, withUnit: false)) \(perUnit)",
                                        note: "Anywhere from \(Format.pace(Double(range.min), units, withUnit: false)) to \(Format.pace(Double(range.max), units, withUnit: false)) is fine."
                                    )
                                }
                                DetailLine(label: "Effort", value: zone.effort)
                            }
                        }
                    }
                }
            }

            // Exactly what to do.
            PageSection("What to do") {
                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(workout.description)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, workout.steps.isEmpty ? 0 : Spacing.s)
                        ForEach(Array(workout.steps.enumerated()), id: \.offset) { _, step in
                            Divider()
                            StepRow(step: step, units: units, paces: store.plan?.paces)
                        }
                    }
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
        // A focused page: the buttons sit alone at the bottom.
        .toolbarVisibility(.hidden, for: .tabBar)
        .appSheets($sheet)
        .alert("Coming soon", isPresented: $showChangeSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Soon you'll be able to swap this for a different workout.")
        }
        .onAppear { Analytics.screen("Workout Detail", ["type": workout.type.rawValue]) }
    }

    /// Mark as done leads; Skip and Change workout sit below it.
    private func actions(_ workout: Workout, run: Run?) -> some View {
        VStack(spacing: Spacing.m) {
            HStack(spacing: Spacing.m) {
                PrimaryButton(workout.status == .completed ? "Edit run" : "Mark as done") {
                    sheet = .log(workout, run)
                }
                if workout.date == .today, workout.status != .completed {
                    CircleButton("Start run with GPS", systemImage: "figure.run") {
                        tracker.start(for: workout)
                    }
                }
            }
            if workout.status != .completed {
                HStack(spacing: Spacing.m) {
                    if workout.status == .skipped {
                        SecondaryButton("Undo skip") {
                            Haptics.tap()
                            store.setStatus(.planned, for: workout)
                        }
                    } else {
                        SecondaryButton("Skip workout") {
                            Haptics.tap()
                            store.setStatus(.skipped, for: workout)
                        }
                    }
                    // Placeholder until swapping workouts is designed.
                    SecondaryButton("Change workout") { showChangeSoon = true }
                }
            }
        }
    }

    /// "Today", "Tomorrow" or "Yesterday", else nil.
    private func relativeDay(_ day: Day) -> String? {
        switch Day.today.days(until: day) {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        default: nil
        }
    }
}

/// A labeled line in the workout card: "Distance", "3.0 miles".
private struct DetailLine: View {
    let label: String
    let value: String
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(.eyebrow)
                .foregroundStyle(.muted)
            Text(value)
                .font(.rowTitle)
                .fixedSize(horizontal: false, vertical: true)
            if let note {
                Text(note)
                    .font(.detail)
                    .foregroundStyle(.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StepRow: View {
    let step: WorkoutStep
    let units: Units
    let paces: PaceZones?

    var body: some View {
        HStack(alignment: .top, spacing: RowMetrics.spacing) {
            RowIcon(systemName: symbol, size: .small)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.rowTitle)
                if let detail { Text(detail).font(.detail).foregroundStyle(.muted) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch step.kind {
        case .warmup: "sunrise"
        case .work: "bolt"
        case .recovery: "pause"
        case .cooldown: "sunset"
        }
    }

    private var title: String {
        let amount = step.distanceM.map { Format.stepDistance($0, units) } ?? step.durationS.map { Format.minutes($0) } ?? ""
        let name = switch step.kind {
        case .warmup: "Warm up"
        case .work: "Run"
        case .recovery: "Recover"
        case .cooldown: "Cool down"
        }
        let base = amount.isEmpty ? name : "\(name) \(amount)"
        if let repeats = step.repeatCount, repeats > 1 { return "\(repeats) × \(base)" }
        return base
    }

    private var detail: String? {
        var parts: [String] = []
        if let zone = step.pace, let range = paces?[zone] {
            parts.append("\(zone.rawValue.capitalized) pace \(Format.paceRange(range, units))")
        }
        if let note = step.note, !note.isEmpty { parts.append(note) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
