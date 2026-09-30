import SwiftUI

/// Ask the AI coach to adjust upcoming workouts, then show what changed.
struct AdjustPlanView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    var initialReason: AdjustReason?
    /// Prefilled note, e.g. describing a training change made in the You tab.
    var initialMessage: String?

    @State private var reason: AdjustReason?
    @State private var message = ""
    @State private var phase: Phase = .input
    @FocusState private var messageFocused: Bool

    enum Phase {
        case input
        case working
        case done(Adjustment)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .input: input
                case .working: working
                case .done(let adjustment): result(adjustment)
                case .failed(let error): failure(error)
                }
            }
            .animation(.snappy, value: phaseKey)
            .navigationTitle("Adjust my plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(phaseKey == 1)
        .onAppear {
            reason = reason ?? initialReason
            if message.isEmpty, let initialMessage { message = initialMessage }
            Analytics.screen("Adjust Plan")
        }
    }

    private var phaseKey: Int {
        switch phase {
        case .input: 0
        case .working: 1
        case .done: 2
        case .failed: 3
        }
    }

    private var input: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("What's going on?")
                    .font(.screenTitle)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(AdjustReason.allCases, id: \.self) { option in
                        Button {
                            Haptics.select()
                            reason = option
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: option.symbol).font(.title3)
                                Text(option.label).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                            .padding(14)
                            .foregroundStyle(reason == option ? Color.paper : Color.ink)
                            .background(reason == option ? Color.ink : Color.wash, in: .rect(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(reason == option ? .isSelected : [])
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell Kiki more").font(.headline)
                    TextField(placeholder, text: $message, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($messageFocused)
                        .padding(16)
                        .background(Color.wash, in: .rect(cornerRadius: 16))
                    if reason == .injured {
                        Text("If pain is sharp, getting worse, or lasts more than a few days, please see a medical professional.")
                            .font(.footnote)
                            .foregroundStyle(.muted)
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("Update my plan", isEnabled: reason != nil, action: submit)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    private var placeholder: String {
        switch reason {
        case .missed: "e.g. I missed Tuesday's tempo run"
        case .tired: "e.g. Work has been intense and I'm sleeping badly"
        case .injured: "e.g. My left knee aches after long runs"
        case .schedule: "e.g. I can't run on Thursdays anymore"
        case .tooEasy: "e.g. My easy runs feel very easy"
        case .tooHard: "e.g. I can't hit the interval paces"
        case .other, nil: "Anything Kiki should know (optional)"
        }
    }

    private var working: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Kiki is rethinking your plan…").font(.title3.weight(.semibold))
            Text("This takes a few seconds.").foregroundStyle(.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func result(_ adjustment: Adjustment) -> some View {
        let changed = Set(adjustment.changedDates ?? [])
        let workouts = store.workouts.filter { changed.contains($0.date) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    KikiLogo(size: 40)
                    Text(adjustment.reply ?? "Your plan is updated.")
                        .padding(16)
                        .background(Color.wash, in: .rect(cornerRadius: 20))
                }
                if !workouts.isEmpty {
                    Text("Updated workouts").font(.headline)
                    ForEach(workouts) { workout in
                        WorkoutRow(workout: workout, units: store.units)
                    }
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("Done") { dismiss() }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    private func failure(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't update your plan", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Try again") { phase = .input }
                .buttonStyle(.borderedProminent)
        }
    }

    private func submit() {
        guard let reason else { return }
        messageFocused = false
        phase = .working
        Task {
            do {
                let adjustment = try await store.requestAdjustment(
                    reason: reason,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
                Haptics.success()
                phase = .done(adjustment)
            } catch {
                Haptics.error()
                if case APIError.subscriptionRequired = error { await subscriptions.refresh() }
                phase = .failed((error as? LocalizedError)?.errorDescription ?? "Please try again.")
            }
        }
    }
}
