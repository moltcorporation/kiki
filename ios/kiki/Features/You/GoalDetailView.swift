import SwiftUI

/// Every detail of the current goal, each editable on its own. The race
/// name is a label and saves instantly; anything that changes the training
/// opens that question from onboarding and confirms before rebuilding.
/// Opened from Home's goal card and from the Profile tab.
struct GoalDetailView: View {
    @Environment(TrainingStore.self) private var store

    @State private var editingName = false
    @State private var goalFlow: OnboardingModel?

    var body: some View {
        DetailPage("Your goal") {
            if let plan = store.plan {
                PageHeader(
                    title: LocalizedStringKey(plan.displayName),
                    // The details are in the rows below; the date is enough here.
                    subtitle: LocalizedStringKey(Plan.goalDate(plan.raceDate))
                )
                VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
                    ListCard {
                        rows(plan)
                    }
                    Footnote("Changing your goal, distance, date or goal time builds a new plan from today. You'll see it before anything changes, and runs you've logged are kept.")
                }
            }
        }
        .sheet(isPresented: $editingName) { RaceNameSheet() }
        .goalEditFlow($goalFlow)
        .onAppear { Analytics.screen("Goal Details") }
    }

    private func onEdit(_ step: OnboardingModel.Step) {
        goalFlow = .goalEdit(step, store: store) { goalFlow = nil }
    }

    @ViewBuilder
    private func rows(_ plan: Plan) -> some View {
        let units = store.units
        SettingsRow(icon: plan.goalKind.icon, label: "Goal", value: plan.goalKind.title) {
            onEdit(.goal)
        }
        switch plan.goalKind {
        case .race:
            SettingsRow(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Distance",
                          value: plan.distanceLabel(units: units)) { onEdit(.distance) }
            SettingsRow(icon: "calendar", label: "Race date",
                          value: plan.raceDate.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())) {
                onEdit(.raceDate)
            }
            SettingsRow(icon: "character.cursor.ibeam", label: "Race name", value: plan.raceName ?? "Add") {
                editingName = true
            }
            SettingsRow(icon: "flag.checkered", label: "Race-day goal",
                          value: plan.goalType == .time ? "Hit a time" : "Just finish") { onEdit(.raceGoal) }
            if plan.goalType == .time {
                SettingsRow(icon: "stopwatch", label: "Goal time", value: plan.goalTimeS.map { Format.duration($0) } ?? "Add") { onEdit(.goalTime) }
            }
        case .faster:
            SettingsRow(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Distance",
                          value: plan.distanceLabel(units: units)) { onEdit(.distance) }
            SettingsRow(icon: "stopwatch", label: "Goal time", value: plan.goalTimeS.map { Format.duration($0) } ?? "Add") {
                onEdit(.goalTime)
            }
            SettingsRow(icon: "calendar", label: "Plan length", value: "\(plan.weekCount) weeks") {
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
        CompactSheet("Race name") {
            TextField("e.g. Chicago Marathon", text: $name)
                .font(.title3.weight(.semibold))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(save)
                .inputField()
            PrimaryButton("Save", isLoading: isSaving, action: save)
        }
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
}

extension OnboardingModel {
    /// The goal questions from onboarding, prefilled with the current goal.
    /// `.goal` changes the whole goal; any other step edits just that
    /// detail. Either way the flow ends with a confirmation before
    /// rebuilding. `onFinish` dismisses it.
    static func goalEdit(_ step: Step, store: TrainingStore, onFinish: @escaping () -> Void) -> OnboardingModel {
        let mode: Mode = step == .goal ? .newGoal : .editGoal(step)
        let model = OnboardingModel(mode: mode, profile: store.profile, plan: store.plan)
        model.onFinish = onFinish
        Analytics.track("goal_edit_started", ["step": step.rawValue])
        return model
    }
}

extension View {
    /// Presents a goal edit flow from `OnboardingModel.goalEdit` full screen.
    func goalEditFlow(_ flow: Binding<OnboardingModel?>) -> some View {
        fullScreenCover(item: flow) { model in
            OnboardingFlow().environment(model)
        }
    }
}
