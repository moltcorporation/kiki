import SwiftUI

/// A profile answer editable from the Profile tab.
enum ProfileField: Hashable {
    case experience, weeklyVolume, longestRun, runDays, coachingStyle, units
    case name, age, height, weight

    var title: String {
        switch self {
        case .experience: "Experience"
        case .weeklyVolume: "Weekly distance"
        case .longestRun: "Longest recent run"
        case .runDays: "Run days"
        case .coachingStyle: "Coaching style"
        case .units: "Units"
        case .name: "Name"
        case .age: "Age"
        case .height: "Height"
        case .weight: "Weight"
        }
    }

    /// Training inputs the current plan was built from. Changing one offers
    /// to update the plan.
    var affectsPlan: Bool {
        switch self {
        case .experience, .weeklyVolume, .longestRun, .runDays, .coachingStyle: true
        case .units, .name, .age, .height, .weight: false
        }
    }
}

/// Edits one profile field with the same inputs onboarding uses, then saves.
struct ProfileFieldEditor: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let field: ProfileField

    @State private var draft: Profile?
    @State private var isSaving = false
    @State private var error: String?
    @State private var planNote: PlanNote?
    @FocusState private var nameFocused: Bool

    var body: some View {
        DetailPage(LocalizedStringKey(field.title)) {
            if let draft = Binding($draft) {
                editor(draft)
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", action: save)
                    .disabled(!canSave || isSaving)
            }
        }
        .sheet(item: $planNote, onDismiss: { dismiss() }) { note in
            ProOnly(title: "Update your plan with Kiki Pro", message: "Your change is saved. Kiki Pro updates your plan to match.", source: "profile_change") {
                AdjustSheet(scope: .plan, autoSend: .init(reason: field == .runDays ? .schedule : .other, message: note.text))
            }
        }
        .alert(error ?? "", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        }
        .onAppear {
            if draft == nil { draft = store.profile }
            nameFocused = field == .name
        }
    }

    @ViewBuilder
    private func editor(_ profile: Binding<Profile>) -> some View {
        let units = profile.wrappedValue.units
        switch field {
        case .experience:
            ChoiceList(options: Questions.experience(units: units), selection: profile.wrappedValue.experience) {
                profile.wrappedValue.experience = $0
            }
        case .weeklyVolume:
            ChoiceList(options: Questions.weeklyVolume(units: units), selection: closestVolume(profile.wrappedValue.weeklyDistanceM, units)) {
                profile.wrappedValue.weeklyDistanceM = $0
            }
        case .longestRun:
            ChoiceList(options: Questions.longestRun(units: units), selection: closest(profile.wrappedValue.longestRunM, in: Questions.longestRun(units: units))) {
                profile.wrappedValue.longestRunM = $0
            }
        case .runDays:
            RunDaysSelector(days: Binding(
                get: { Set(profile.wrappedValue.runDays) },
                set: { profile.wrappedValue.runDays = $0.sorted() }
            ), experience: profile.wrappedValue.experience)
        case .coachingStyle:
            ChoiceList(options: Questions.coachingStyles, selection: profile.wrappedValue.coachingStyle ?? .balanced) {
                profile.wrappedValue.coachingStyle = $0
            }
        case .units:
            ChoiceList(options: Questions.units, selection: units) { profile.wrappedValue.units = $0 }
        case .name:
            TextField("First name", text: Binding(
                get: { profile.wrappedValue.firstName ?? "" },
                set: { profile.wrappedValue.firstName = $0 }
            ))
            .font(.screenTitle)
            .textContentType(.givenName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($nameFocused)
            .onSubmit(save)
            .inputField()
        case .age:
            AgeInput(age: Binding(
                get: { profile.wrappedValue.age ?? Defaults.age },
                set: { profile.wrappedValue.birthYear = Profile.birthYear(forAge: $0) }
            ))
            .padding(.top, Spacing.xxl)
        case .height:
            HeightInput(heightCm: Binding(
                get: { profile.wrappedValue.heightCm ?? Defaults.heightCm },
                set: { profile.wrappedValue.heightCm = $0 }
            ), units: units)
            .padding(.top, Spacing.xxl)
        case .weight:
            WeightInput(weightKg: Binding(
                get: { profile.wrappedValue.weightKg ?? Defaults.weightKg },
                set: { profile.wrappedValue.weightKg = $0 }
            ), units: units)
            .padding(.top, Spacing.xxl)
        }
    }

    private var canSave: Bool {
        guard let draft else { return false }
        switch field {
        case .runDays: return !draft.runDays.isEmpty
        case .name: return draft.firstName?.trimmingCharacters(in: .whitespaces).isEmpty == false
        // Inputs with a default value save that value even if untouched.
        case .age, .height, .weight: return true
        default: return draft != store.profile
        }
    }

    /// The weekly-volume option nearest the saved value.
    private func closestVolume(_ meters: Int, _ units: Units) -> Int? {
        closest(meters, in: Questions.weeklyVolume(units: units))
    }

    /// The option nearest a saved value.
    private func closest(_ meters: Int, in options: [ChoiceList<Int>.Option]) -> Int? {
        guard meters > 0 else { return nil }
        return options.map(\.value).min { abs($0 - meters) < abs($1 - meters) }
    }

    private func save() {
        guard var profile = draft, canSave, let original = store.profile else { return }
        switch field {
        case .experience:
            if profile.experience == .new {
                profile.weeklyDistanceM = 0
                profile.longestRunM = 0
            } else if original.experience == .new {
                profile.longestRunM = profile.experience.typicalLongestRunM
            }
        case .runDays:
            profile.longRunDay = Questions.longRunDay(for: Set(profile.runDays))
        case .name:
            profile.firstName = profile.firstName?.trimmingCharacters(in: .whitespaces)
        case .age:
            profile.birthYear = profile.birthYear ?? Profile.birthYear(forAge: Defaults.age)
        case .height:
            profile.heightCm = profile.heightCm ?? Defaults.heightCm
        case .weight:
            profile.weightKg = profile.weightKg ?? Defaults.weightKg
        default:
            break
        }

        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await store.saveProfile(profile)
                Haptics.success()
                Analytics.track("profile_field_updated", ["field": field.title])
                if field.affectsPlan, store.plan != nil, let note = planNote(from: original, to: profile) {
                    planNote = PlanNote(text: note)
                } else {
                    dismiss()
                }
            } catch {
                Haptics.error()
                self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't save. Please try again."
            }
        }
    }

    /// Describes the change for the coach, so the plan update knows why.
    private func planNote(from old: Profile, to new: Profile) -> String? {
        switch field {
        case .experience where old.experience != new.experience:
            "I'd now describe my running as \(new.experience.title.lowercased())."
        case .weeklyVolume where old.weeklyDistanceM != new.weeklyDistanceM:
            "I now run about \(Format.distance(Double(new.weeklyDistanceM), new.units, decimals: 0)) a week."
        case .longestRun where old.longestRunM != new.longestRunM:
            "My longest recent run is about \(Format.distance(Double(new.longestRunM), new.units, decimals: 0))."
        case .runDays where old.runDays != new.runDays:
            "I can now run on \(RunDaysSelector.summary(new.runDays))."
        case .coachingStyle where old.coachingStyle != new.coachingStyle:
            "Please change my coaching style to \((new.coachingStyle ?? .balanced).title.lowercased())."
        default:
            nil
        }
    }
}

private struct PlanNote: Identifiable {
    let id = UUID()
    let text: String
}
