import SwiftUI

/// Every detail of the current goal, each editable on its own. The race
/// name is a label and saves instantly; anything that changes the training
/// opens that question from onboarding and confirms before rebuilding.
struct GoalDetailView: View {
    @Environment(TrainingStore.self) private var store
    let onEdit: (OnboardingModel.Step) -> Void

    @State private var editingName = false

    var body: some View {
        ScrollView {
            if let plan = store.plan {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.displayName)
                            .font(.screenTitle)
                        Text(plan.goalDetails(units: store.units).joined(separator: " · "))
                            .foregroundStyle(.muted)
                    }

                    PreferenceGroup {
                        rows(plan)
                    }

                    Text("Changing your goal, distance, date or goal time builds a new plan from today. You'll see it before anything changes, and runs you've logged are kept.")
                        .font(.footnote)
                        .foregroundStyle(.muted)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(Color.paper)
        .navigationTitle("Your goal")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingName) { RaceNameSheet() }
        .onAppear { Analytics.screen("Goal Details") }
    }

    @ViewBuilder
    private func rows(_ plan: Plan) -> some View {
        let units = store.units
        PreferenceRow(icon: plan.goalKind.icon, label: "Goal", value: plan.goalKind.title,
                      showsDivider: plan.goalKind == .race || plan.goalKind == .faster) {
            onEdit(.goal)
        }
        switch plan.goalKind {
        case .race:
            PreferenceRow(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Distance",
                          value: plan.distanceLabel(units: units)) { onEdit(.distance) }
            PreferenceRow(icon: "calendar", label: "Race date",
                          value: plan.raceDate.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())) {
                onEdit(.raceDate)
            }
            PreferenceRow(icon: "character.cursor.ibeam", label: "Race name", value: plan.raceName ?? "Add") {
                editingName = true
            }
            PreferenceRow(icon: "flag.checkered", label: "Race-day goal",
                          value: plan.goalType == .time ? "Hit a time" : "Just finish",
                          showsDivider: plan.goalType == .time) { onEdit(.raceGoal) }
            if plan.goalType == .time {
                PreferenceRow(icon: "stopwatch", label: "Goal time", value: plan.goalTimeS.map { Format.duration($0) } ?? "Add",
                              showsDivider: false) { onEdit(.goalTime) }
            }
        case .faster:
            PreferenceRow(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Distance",
                          value: plan.distanceLabel(units: units)) { onEdit(.distance) }
            PreferenceRow(icon: "stopwatch", label: "Goal time", value: plan.goalTimeS.map { Format.duration($0) } ?? "Add") {
                onEdit(.goalTime)
            }
            PreferenceRow(icon: "calendar", label: "Plan length", value: "\(plan.weekCount) weeks", showsDivider: false) {
                onEdit(.timeframe)
            }
        case .start, .fit:
            EmptyView()
        }
    }
}

/// Renames the race. A label only, so it saves without rebuilding the plan.
private struct RaceNameSheet: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isSaving = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("Race name")
                .font(.sheetTitle)
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .padding(.bottom, 18)
            Divider()
            VStack(spacing: 16) {
                TextField("e.g. Chicago Marathon", text: $name)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit(save)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.wash, in: .rect(cornerRadius: 20))
                PrimaryButton("Save", isLoading: isSaving, action: save)
            }
            .padding(24)
        }
        .presentationDetents([.height(250)])
        .presentationCornerRadius(32)
        .presentationDragIndicator(.visible)
        .alert("Couldn't save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .onAppear {
            name = store.plan?.raceName ?? ""
            focused = true
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await store.renameRace(name)
                Haptics.success()
                dismiss()
            } catch {
                Haptics.error()
                self.error = (error as? LocalizedError)?.errorDescription ?? "Please try again."
            }
        }
    }
}

extension Plan {
    /// The race distance, e.g. "Half Marathon" or "10 mi".
    func distanceLabel(units: Units) -> String {
        if raceDistance == .other, let meters = raceDistanceM {
            return Format.distance(Double(meters), units, decimals: 0)
        }
        return raceDistance?.label ?? ""
    }

    /// Plan length in weeks, counting the current partial week.
    var weekCount: Int {
        max(1, startDate.mondayOfWeek.days(until: raceDate.mondayOfWeek) / 7 + 1)
    }

    /// Short lines describing the goal, for cards and headers.
    func goalDetails(units: Units) -> [String] {
        let weeksLeft = max(0, Day.today.days(until: raceDate) / 7)
        switch goalKind {
        case .race:
            let date = raceDate.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            let target = goalType == .time ? goalTimeS.map { "Goal \(Format.duration($0))" } : "Finish strong"
            return [
                [raceName == nil ? nil : distanceLabel(units: units), date].compactMap { $0 }.joined(separator: " · "),
                [target, weeksLeft > 0 ? "\(weeksLeft) weeks to go" : nil].compactMap { $0 }.joined(separator: " · "),
            ]
        case .faster:
            return [
                [goalTimeS.map { "Goal \(Format.duration($0))" }, "\(weekCount)-week plan"].compactMap { $0 }.joined(separator: " · "),
            ]
        case .start:
            return ["Run 30 minutes non-stop · \(weekCount) weeks"]
        case .fit:
            return ["Run consistently · \(weekCount) weeks"]
        }
    }
}
