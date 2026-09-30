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

        return ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                // The date leads.
                VStack(alignment: .leading, spacing: 2) {
                    if let relative = relativeDay(workout.date) {
                        Text(relative)
                            .font(.headline)
                            .foregroundStyle(.muted)
                    }
                    Text(workout.date.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.screenTitle)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // What to run.
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        WorkoutIcon(workout: workout, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.type.label)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.muted)
                            Text(workout.title)
                                .font(.title2.weight(.bold))
                        }
                        Spacer(minLength: 0)
                        StatusBadge(status: workout.status, isToday: false)
                    }
                    if !workout.isRest {
                        HStack(alignment: .firstTextBaseline, spacing: 32) {
                            if let metric = Format.workoutMetric(workout, units: units) {
                                MetricView(value: metric.value, label: metric.unit)
                            }
                            if let zone = workout.type.paceZone, let range = store.plan?.paces?[zone] {
                                MetricView(
                                    value: Format.paceRange(range, units).replacingOccurrences(of: " /\(units.rawValue)", with: ""),
                                    label: "\(zone.rawValue) pace /\(units.rawValue)"
                                )
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .elevatedCard(cornerRadius: 24)

                // Exactly what to do.
                TabSection("What to do") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(workout.description)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, workout.steps.isEmpty ? 0 : 8)
                        ForEach(Array(workout.steps.enumerated()), id: \.offset) { index, step in
                            Divider()
                            StepRow(step: step, units: units, paces: store.plan?.paces)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .elevatedCard(cornerRadius: 24)
                }

                if let run {
                    TabSection("Your run") {
                        VStack(alignment: .leading, spacing: 10) {
                            RunSummaryLine(run: run, units: units)
                            if let notes = run.notes, !notes.isEmpty {
                                Text("“\(notes)”").font(.subheadline).foregroundStyle(.muted)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .elevatedCard(cornerRadius: 24)
                    }
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background { PageBackground() }
        .safeAreaInset(edge: .bottom) {
            if !workout.isRest || workout.status == .completed {
                actions(workout, run: run)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PrimaryButton(workout.status == .completed ? "Edit run" : "Mark as done") {
                    sheet = .log(workout, run)
                }
                if workout.date == .today, workout.status != .completed {
                    Button {
                        tracker.start(for: workout)
                    } label: {
                        Image(systemName: "figure.run")
                            .font(.headline)
                            .frame(width: Metrics.buttonHeight, height: Metrics.buttonHeight)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Start run with GPS")
                }
            }
            if workout.status != .completed {
                HStack(spacing: 10) {
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
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 8)
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

private struct StepRow: View {
    let step: WorkoutStep
    let units: Units
    let paces: PaceZones?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 32, height: 32)
                .background(Color.wash, in: .circle)
                .foregroundStyle(.ink)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                if let detail { Text(detail).font(.subheadline).foregroundStyle(.muted) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
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
