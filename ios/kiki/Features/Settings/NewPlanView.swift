import SwiftUI

/// Start a fresh plan for a new race or goal. The current plan stays active
/// until the new one is ready.
struct NewPlanView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var distance: RaceDistance = .half
    @State private var customKm: Double = 15
    @State private var raceDate = Day.today.adding(days: 84).date
    @State private var raceName = ""
    @State private var goalType: GoalType = .finish
    @State private var goalTimeS = 2 * 3600
    @State private var phase: Phase = .form

    enum Phase: Equatable { case form, building(Int), failed(String) }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .form: form
                case .building(let progress):
                    VStack(spacing: 16) {
                        ProgressView(value: Double(progress), total: 100).tint(.ink)
                        Text("Building your new plan…").font(.headline)
                        Text("Your current plan stays active until it's ready.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't build your plan", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try again") { phase = .form }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("New race or goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .onAppear {
            if let plan = store.plan {
                distance = plan.raceDistance
                goalType = plan.goalType
                goalTimeS = plan.goalTimeS ?? goalTimeS
            }
        }
    }

    private var form: some View {
        Form {
            Section("Race") {
                Picker("Distance", selection: $distance) {
                    ForEach(RaceDistance.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                if distance == .other {
                    Stepper("\(Format.distance(customKm * 1000, store.units))", value: $customKm, in: 2...100)
                }
                DatePicker(
                    "Race date",
                    selection: $raceDate,
                    in: Day.today.adding(days: 7).date...Day.today.adding(days: 40 * 7 - 1).date,
                    displayedComponents: .date
                )
                TextField("Race name (optional)", text: $raceName)
            }
            Section("Goal") {
                Picker("Goal", selection: $goalType) {
                    Text("Finish strong").tag(GoalType.finish)
                    Text("Time goal").tag(GoalType.time)
                }
                .pickerStyle(.segmented)
                if goalType == .time {
                    DurationWheel(seconds: $goalTimeS, showsHours: distance != .fiveK)
                }
            }
            Section {
                PrimaryButton("Build my new plan", action: build)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    private func build() {
        let request = PlanRequest(
            raceDistance: distance,
            raceDistanceM: distance == .other ? Int(customKm * 1000) : nil,
            raceName: raceName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            raceDate: Day(raceDate),
            goalType: goalType,
            goalTimeS: goalType == .time ? goalTimeS : nil
        )
        phase = .building(5)
        Task {
            do {
                let plan = try await store.createPlan(request)
                _ = try await store.waitForPlan(plan.id) { phase = .building($0) }
                Haptics.success()
                if let units = store.profile?.units {
                    await Notifications.scheduleWorkoutReminders(store.workouts, units: units)
                }
                dismiss()
            } catch {
                Haptics.error()
                phase = .failed((error as? LocalizedError)?.errorDescription ?? "Please try again.")
            }
        }
    }
}
