import SwiftUI

/// Log or edit a run, in a bottom sheet like the rest of the app. Prefilled
/// from the planned workout, an existing run, or a GPS-tracked draft, so
/// "Mark done" is usually one tap on Save. One question about the run (how
/// it felt); Kiki derives the effort from it. Editing adds Delete.
struct LogRunView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let workout: Workout?
    let existing: Run?
    var draft: Run?
    /// Called after a new run is saved (e.g. to write it to Apple Health).
    var onSave: ((Run) -> Void)?

    @State private var distance = ""
    @State private var durationS = 0
    @State private var startedAt = Date.now
    @State private var feeling: Feeling?
    @State private var notes = ""
    @State private var editingDuration = false
    @State private var followUp: AdjustReason?
    @State private var showAdjust = false
    @State private var confirmDiscard = false
    @State private var confirmDelete = false
    @State private var height: CGFloat = 560
    @FocusState private var focused: Field?

    private enum Field { case distance, notes }

    private var units: Units { store.units }
    private var distanceMeters: Double? {
        Double(distance.replacingOccurrences(of: ",", with: ".")).map { Format.meters(fromDistance: $0, units) }
    }
    private var canSave: Bool { (distanceMeters ?? 0) > 0 && durationS > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                details
                feelingPicker
                TextField("Add a note (optional)", text: $notes, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused, equals: .notes)
                    .inputField()
                VStack(spacing: Spacing.xs) {
                    PrimaryButton(existing == nil ? "Save run" : "Save changes", isEnabled: canSave, action: save)
                    if existing != nil {
                        Button("Delete run", role: .destructive) { confirmDelete = true }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.destructive)
                            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
                            .buttonStyle(.haptic)
                    } else if draft != nil {
                        TextButton("Discard run") { confirmDiscard = true }
                    }
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, Spacing.xxxl)
            .padding(.bottom, Spacing.l)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.height(min(height, 700)), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surface)
        // A tracked run is only saved from here: don't lose it to a swipe.
        .interactiveDismissDisabled(draft != nil)
        .confirmationDialog(
            "Want Kiki to adjust your upcoming week?",
            isPresented: .constant(followUp != nil && !showAdjust),
            titleVisibility: .visible
        ) {
            Button("Adjust my plan") { showAdjust = true }
            Button("Not now", role: .cancel) { dismiss() }
        } message: {
            Text(followUp == .injured ? "Kiki can ease off to help you recover." : "Kiki can lighten the next few days so you recover.")
        }
        .confirmationDialog("Discard this run?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard run", role: .destructive) { dismiss() }
        } message: {
            Text("Your tracked run won't be saved.")
        }
        .confirmationDialog("Delete this run?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete run", role: .destructive) {
                if let existing { store.delete(existing) }
                Haptics.success()
                dismiss()
            }
        } message: {
            Text("It's removed from your log and your plan.")
        }
        .sheet(isPresented: $showAdjust, onDismiss: { dismiss() }) {
            ProOnly(title: "Adjust with Kiki Pro", message: "Kiki eases your next few days so you recover.", source: "log_followup") {
                AdjustSheet(scope: .plan, autoSend: followUp.map { .init(reason: $0) })
            }
        }
        .onAppear(perform: prefill)
        .onAppear { Analytics.screen("Log Run", ["editing": existing != nil]) }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(existing == nil ? (workout?.title ?? "Log a run") : "Edit run")
                .font(.heroTitle)
                .accessibilityAddTraits(.isHeader)
            Text(startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.detail)
                .foregroundStyle(.muted)
        }
    }

    /// Distance, time, start and pace, in one card of rows.
    private var details: some View {
        VStack(spacing: 0) {
            row("Distance") {
                HStack(spacing: Spacing.xs) {
                    TextField("0.0", text: $distance)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .distance)
                        .frame(maxWidth: 90)
                    Text(units.rawValue).foregroundStyle(.muted)
                }
            }
            Divider().padding(.leading, RowMetrics.horizontalPadding)
            Button {
                focused = nil
                withAnimation(.smooth) { editingDuration.toggle() }
            } label: {
                row("Time") {
                    Text(Format.duration(durationS)).foregroundStyle(.muted).monospacedDigit()
                }
            }
            .buttonStyle(.plain)
            if editingDuration {
                DurationWheel(seconds: $durationS)
                    .padding(.horizontal, RowMetrics.horizontalPadding)
            }
            Divider().padding(.leading, RowMetrics.horizontalPadding)
            row("Started") {
                DatePicker("", selection: $startedAt, in: ...Date.now)
                    .labelsHidden()
            }
            if let distanceMeters, distanceMeters > 0, durationS > 0 {
                Divider().padding(.leading, RowMetrics.horizontalPadding)
                row("Pace") {
                    Text(Format.pace(Double(durationS) / (distanceMeters / 1000), units))
                        .foregroundStyle(.muted)
                        .monospacedDigit()
                }
            }
        }
        .background(Color.wash, in: .rect(cornerRadius: Radius.control))
    }

    private func row(_ label: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer(minLength: Spacing.m)
            value()
        }
        .foregroundStyle(.ink)
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .frame(minHeight: 50)
        .contentShape(.rect)
    }

    /// One question: how it felt. Effort is derived from it for the coach.
    private var feelingPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("How did it feel?")
                .font(.sectionTitle)
            FlowChips(options: Feeling.allCases, selection: $feeling)
        }
    }

    // MARK: Data

    private func prefill() {
        let source = existing ?? draft
        if let source {
            distance = Format.distanceNumber(source.distanceM, units, decimals: 2)
            durationS = source.durationS
            startedAt = source.startedAt
            feeling = source.feeling
            notes = source.notes ?? ""
        } else if let workout {
            if let d = workout.distanceM { distance = Format.distanceNumber(Double(d), units, decimals: 1) }
            let pace = workout.type.paceZone.flatMap { store.plan?.paces?[$0] }.map(Double.init)
            if let s = workout.durationS {
                durationS = s
            } else if let d = workout.distanceM, let pace {
                durationS = Int(Double(d) / 1000 * pace)
            }
            if workout.date < .today {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: workout.date.date)
                components.hour = 7
                startedAt = Calendar.current.date(from: components) ?? .now
            }
        }
    }

    /// A run logged by hand on a day with a planned run checks it off
    /// (the plan stays the plan; other runs just go in the log).
    private func openWorkout(on day: Day) -> Workout? {
        store.workouts.first { $0.date == day && !$0.isRest && $0.status == .planned && store.run(for: $0) == nil }
    }

    private func save() {
        guard let meters = distanceMeters else { return }
        let base = existing ?? draft
        let run = Run(
            id: base?.id ?? UUID(),
            workoutId: workout?.id ?? base?.workoutId ?? openWorkout(on: Day(startedAt))?.id,
            source: base?.source ?? .manual,
            externalId: base?.externalId,
            startedAt: startedAt,
            distanceM: meters,
            durationS: durationS,
            elevationGainM: base?.elevationGainM,
            avgHeartRate: base?.avgHeartRate,
            route: base?.route,
            splits: base?.splits,
            effort: feeling?.effort ?? base?.effort,
            feeling: feeling,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        store.save(run)
        if existing == nil { onSave?(run) }
        Haptics.success()

        if existing == nil, feeling == .pain {
            followUp = .injured
        } else if existing == nil, feeling == .tired {
            followUp = .tired
        } else {
            dismiss()
        }
    }
}

/// The five feelings as wrapping chips (black when selected).
private struct FlowChips: View {
    let options: [Feeling]
    @Binding var selection: Feeling?

    var body: some View {
        // Two rows so the labels never shrink.
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) { ForEach(options.prefix(3), id: \.self, content: chip) }
            HStack(spacing: Spacing.s) { ForEach(options.dropFirst(3), id: \.self, content: chip) }
        }
    }

    private func chip(_ option: Feeling) -> some View {
        let isSelected = selection == option
        return Button {
            Haptics.select()
            withAnimation(.snappy) { selection = isSelected ? nil : option }
        } label: {
            Text(option.question)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.paper : Color.ink)
                .padding(.horizontal, Spacing.l)
                .frame(minHeight: 40)
                .background(isSelected ? Color.ink : Color.surface, in: .capsule)
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension Feeling {
    /// The answer to "How did it feel?".
    var question: String {
        switch self {
        case .great: "Great"
        case .good: "Good"
        case .okay: "Okay"
        case .tired: "Tough"
        case .pain: "Something hurt"
        }
    }

    /// Effort out of 10 for the coach, derived from the feeling.
    var effort: Int {
        switch self {
        case .great: 3
        case .good: 4
        case .okay: 6
        case .tired: 8
        case .pain: 7
        }
    }
}
