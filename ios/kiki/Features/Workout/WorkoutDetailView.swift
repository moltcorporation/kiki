import SwiftUI

struct WorkoutDetailView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker

    let workoutID: UUID

    @State private var sheet: AppSheet?
    @State private var showMove = false
    @State private var error: String?

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
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    WorkoutIcon(workout: workout, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.type.label).font(.subheadline.weight(.semibold)).foregroundStyle(.muted)
                        Text(workout.date.date, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.subheadline)
                            .foregroundStyle(.muted)
                    }
                    Spacer()
                    StatusBadge(status: workout.status, isToday: workout.date == .today)
                }

                Text(workout.title).font(.display(.largeTitle))

                if !workout.isRest {
                    HStack(alignment: .firstTextBaseline, spacing: 32) {
                        if let metric = Format.workoutMetric(workout, units: units) {
                            MetricView(value: metric.value, label: metric.unit)
                        }
                        if let zone = workout.type.paceZone, let range = store.plan?.paces?[zone] {
                            MetricView(value: Format.paceRange(range, units).replacingOccurrences(of: " /\(units.rawValue)", with: ""), label: "\(zone.rawValue) pace /\(units.rawValue)")
                        }
                    }
                }

                Text(workout.description)
                    .font(.body)
                    .foregroundStyle(.muted)

                if !workout.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Workout").font(.headline).padding(.bottom, 12)
                        ForEach(Array(workout.steps.enumerated()), id: \.offset) { index, step in
                            StepRow(step: step, units: units, paces: store.plan?.paces)
                            if index < workout.steps.count - 1 { Divider().padding(.leading, 44) }
                        }
                    }
                }

                if let run {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your run").font(.headline)
                        RunSummaryLine(run: run, units: units)
                        if let notes = run.notes, !notes.isEmpty {
                            Text("“\(notes)”").font(.subheadline).foregroundStyle(.muted)
                        }
                    }
                }

                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            if !workout.isRest || workout.status == .completed {
                HStack(spacing: 10) {
                    PrimaryButton(workout.status == .completed ? "Edit run" : "Mark as done") {
                        sheet = .log(workout, run)
                    }
                    if workout.date == .today, workout.status != .completed, !workout.isRest {
                        Button {
                            tracker.start(for: workout)
                        } label: {
                            Image(systemName: "figure.run").font(.headline).frame(width: 56, height: 56)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Start run with GPS")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if workout.status != .completed && workout.type != .race {
                        Button("Move to another day", systemImage: "calendar") { showMove = true }
                    }
                    if workout.status == .planned && !workout.isRest {
                        Button("Skip workout", systemImage: "forward.fill") {
                            Haptics.tap()
                            store.setStatus(.skipped, for: workout)
                        }
                    }
                    if workout.status == .skipped {
                        Button("Undo skip", systemImage: "arrow.uturn.backward") { store.setStatus(.planned, for: workout) }
                    }
                    Button("Adjust my plan", systemImage: "sparkles") { sheet = .adjust }
                    if let run {
                        Button("Delete run", systemImage: "trash", role: .destructive) { store.delete(run) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More actions")
            }
        }
        .appSheets($sheet)
        .sheet(isPresented: $showMove) {
            MoveWorkoutSheet(workout: workout) { day in
                Task {
                    do {
                        try await store.move(workout, to: day)
                        Haptics.success()
                    } catch {
                        Haptics.error()
                        self.error = (error as? LocalizedError)?.errorDescription
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear { Analytics.screen("Workout Detail", ["type": workout.type.rawValue]) }
    }
}

private struct StepRow: View {
    let step: WorkoutStep
    let units: Units
    let paces: PaceZones?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 30, height: 30)
                .background(step.kind == .work ? Color.ink : Color.wash, in: .circle)
                .foregroundStyle(step.kind == .work ? Color.paper : Color.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                if let detail { Text(detail).font(.subheadline).foregroundStyle(.muted) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private var symbol: String {
        switch step.kind {
        case .warmup: "sunrise.fill"
        case .work: "bolt.fill"
        case .recovery: "pause.fill"
        case .cooldown: "sunset.fill"
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

/// Pick another day this week or next to swap this workout with.
struct MoveWorkoutSheet: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let workout: Workout
    let onMove: (Day) -> Void

    var body: some View {
        let options = store.workouts.filter {
            $0.id != workout.id
                && $0.date >= .today
                && $0.date < workout.date.mondayOfWeek.adding(days: 14)
                && $0.status != .completed
                && $0.type != .race
        }

        NavigationStack {
            List(options) { other in
                Button {
                    Haptics.tap()
                    onMove(other.date)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(other.date.date, format: .dateTime.weekday(.wide).month().day())
                                .font(.body.weight(.semibold))
                            Text(other.isRest ? "Rest day" : "Swap with \(other.title)")
                                .font(.subheadline)
                                .foregroundStyle(.muted)
                        }
                        Spacer()
                    }
                    .contentShape(.rect)
                }
                .foregroundStyle(.ink)
            }
            .navigationTitle("Move \(workout.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .overlay {
                if options.isEmpty {
                    ContentUnavailableView("No days available", systemImage: "calendar", description: Text("There are no open days in the next two weeks."))
                }
            }
        }
    }
}
