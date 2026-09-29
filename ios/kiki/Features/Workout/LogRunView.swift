import SwiftUI

/// Log or edit a run. Prefilled from the planned workout, an existing run,
/// or a GPS-tracked draft, so "Mark as done" is usually one tap on Save.
struct LogRunView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let workout: Workout?
    let existing: Run?
    var draft: Run?

    @State private var distance = ""
    @State private var durationS = 0
    @State private var startedAt = Date.now
    @State private var feeling: Feeling?
    @State private var effort: Double = 5
    @State private var notes = ""
    @State private var editingDuration = false
    @State private var followUp: AdjustReason?
    @State private var showAdjust = false
    @State private var confirmDiscard = false
    @FocusState private var distanceFocused: Bool

    private var units: Units { store.units }
    private var distanceMeters: Double? {
        Double(distance.replacingOccurrences(of: ",", with: ".")).map { Format.meters(fromDistance: $0, units) }
    }
    private var canSave: Bool { (distanceMeters ?? 0) > 0 && durationS > 0 }
    private var isTracked: Bool { (draft ?? existing)?.source == .kiki }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("How did it feel?").font(.headline)
                        HStack(spacing: 8) {
                            ForEach(Feeling.allCases, id: \.self) { option in
                                Button {
                                    Haptics.select()
                                    feeling = option
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(option.emoji).font(.title)
                                        Text(option.label).font(.caption.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 72)
                                    .foregroundStyle(feeling == option ? Color.paper : Color.ink)
                                    .background(feeling == option ? Color.ink : Color.wash, in: .rect(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(feeling == option ? .isSelected : [])
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                }

                Section {
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0.0", text: $distance)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($distanceFocused)
                            .disabled(isTracked)
                            .frame(maxWidth: 100)
                        Text(units.rawValue).foregroundStyle(.secondary)
                    }
                    Button {
                        distanceFocused = false
                        withAnimation { editingDuration.toggle() }
                    } label: {
                        HStack {
                            Text("Time").foregroundStyle(.ink)
                            Spacer()
                            Text(Format.duration(durationS)).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    .disabled(isTracked)
                    if editingDuration {
                        DurationWheel(seconds: $durationS)
                    }
                    if let distanceMeters, distanceMeters > 0, durationS > 0 {
                        HStack {
                            Text("Pace")
                            Spacer()
                            Text(Format.pace(Double(durationS) / (distanceMeters / 1000), units))
                                .foregroundStyle(.secondary)
                        }
                    }
                    DatePicker("Started", selection: $startedAt, in: ...Date.now)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Effort")
                            Spacer()
                            Text("\(Int(effort))/10 · \(effortLabel)").foregroundStyle(.secondary)
                        }
                        Slider(value: $effort, in: 1...10, step: 1)
                            .onChange(of: effort) { Haptics.select() }
                    }
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                } footer: {
                    Text("Kiki uses how you felt to keep your plan right for you.")
                }

                if existing != nil {
                    Section {
                        Button("Delete run", role: .destructive) {
                            if let existing { store.delete(existing) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(workout?.title ?? "Log a run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        if draft != nil { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .disabled(!canSave)
                }
            }
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
            .sheet(isPresented: $showAdjust, onDismiss: { dismiss() }) {
                AdjustPlanView(initialReason: followUp)
            }
        }
        .onAppear(perform: prefill)
    }

    private var effortLabel: String {
        switch Int(effort) {
        case ...3: "Easy"
        case 4...6: "Moderate"
        case 7...8: "Hard"
        default: "All out"
        }
    }

    private func prefill() {
        let source = existing ?? draft
        if let source {
            distance = Format.distanceNumber(source.distanceM, units, decimals: 2)
            durationS = source.durationS
            startedAt = source.startedAt
            feeling = source.feeling
            effort = Double(source.effort ?? 5)
            notes = source.notes ?? ""
        } else if let workout {
            if let d = workout.distanceM { distance = Format.distanceNumber(Double(d), units, decimals: 1) }
            let pace = workout.type.paceZone.flatMap { store.plan?.paces?[$0] }.map { Double($0.min + $0.max) / 2 }
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
            effort = workout.type.isQuality ? 7 : 4
        }
    }

    private func save() {
        guard let meters = distanceMeters else { return }
        let base = existing ?? draft
        let run = Run(
            id: base?.id ?? UUID(),
            workoutId: workout?.id ?? base?.workoutId,
            source: base?.source ?? .manual,
            externalId: base?.externalId,
            startedAt: startedAt,
            distanceM: meters,
            durationS: durationS,
            elevationGainM: base?.elevationGainM,
            avgHeartRate: base?.avgHeartRate,
            route: base?.route,
            splits: base?.splits,
            effort: Int(effort),
            feeling: feeling,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        store.save(run)
        Haptics.success()

        if existing == nil, feeling == .pain {
            followUp = .injured
        } else if existing == nil, feeling == .tired || Int(effort) >= 9 {
            followUp = .tired
        } else {
            dismiss()
        }
    }
}
