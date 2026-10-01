import SwiftUI

/// Ask the AI coach to adjust upcoming workouts, then show what changed.
struct AdjustPlanView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    var initialReason: AdjustReason?
    /// Prefilled note, e.g. describing a training change made in the Profile tab.
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
        DetailPage {
            PageHeader(title: "What's going on?")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)], spacing: Spacing.m) {
                ForEach(AdjustReason.allCases, id: \.self) { option in
                    SelectableTile(isSelected: reason == option, minHeight: 88, alignment: .topLeading, action: { reason = option }) {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Image(systemName: option.symbol).font(.title3)
                            Text(option.label).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                        }
                        .padding(Spacing.xxs)
                    }
                }
            }

            PageSection("Tell Kiki more") {
                TextField(placeholder, text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($messageFocused)
                    .inputField()
                if reason == .injured {
                    Footnote("If pain is sharp, getting worse, or lasts more than a few days, please see a medical professional.")
                }
            }
        }
        .bottomActions {
            PrimaryButton("Update my plan", isEnabled: reason != nil, action: submit)
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
        VStack(spacing: Spacing.l) {
            Spacer()
            ProgressView().controlSize(.large)
            VStack(spacing: Spacing.xs) {
                Text("Kiki is rethinking your plan…").font(.cardTitle)
                Text("This takes a few seconds.").foregroundStyle(.muted)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background { PageBackground() }
    }

    private func result(_ adjustment: Adjustment) -> some View {
        let changed = Set(adjustment.changedDates ?? [])
        let workouts = store.workouts.filter { changed.contains($0.date) }
        return DetailPage {
            CoachBubble(text: adjustment.reply ?? "Your plan is updated.")
            if !workouts.isEmpty {
                PageSection("Updated workouts") {
                    ListCard(dividerInset: WorkoutRow.textInset) {
                        ForEach(workouts) { workout in
                            WorkoutRow(workout: workout, units: store.units, isNavigable: false)
                        }
                    }
                }
            }
        }
        .bottomActions {
            PrimaryButton("Done") { dismiss() }
        }
    }

    private func failure(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't update your plan", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            PrimaryButton("Try again") { phase = .input }
                .padding(.horizontal, Metrics.screenMargin)
        }
        .background { PageBackground() }
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
