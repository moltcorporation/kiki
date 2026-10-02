import SwiftUI

/// Every plan change happens in this bottom sheet. It fits its content and
/// stays a sheet throughout: quick options (or "Something else? Tell Kiki"
/// with a text box), then a short wait while Kiki makes targeted edits (the
/// sheet can't be closed meanwhile), then what changed.
///
/// Two scopes: a day (Today's "Adjust day", a workout's "Adjust or skip")
/// with options about that run, or the whole plan (Home's "Adjust plan")
/// with broader ones. Skipping a day is local: no coach, no plan changes.
struct AdjustSheet: View {
    enum Scope: Hashable {
        case day(Workout)
        case plan
    }

    /// What goes to the coach.
    struct Request: Equatable {
        let reason: AdjustReason
        var message: String?
    }

    let scope: Scope
    /// Sends this right away instead of showing the options (a profile
    /// change, or a run that felt hard).
    var autoSend: Request?

    @Environment(TrainingStore.self) private var store
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .options
    @State private var message = ""
    @State private var height: CGFloat = 420
    @FocusState private var messageFocused: Bool

    private enum Phase: Equatable {
        case options
        case writing(AdjustReason)
        case working
        case done(Adjustment)
        case failed(String, Request)
    }

    private struct Option: Identifiable {
        let id: String
        let icon: String
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let action: () -> Void
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.top, Spacing.xxxl)
                .padding(.bottom, Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(min(height, 680))])
        .presentationDragIndicator(phase == .working ? .hidden : .visible)
        .presentationBackground(Color.surface)
        .interactiveDismissDisabled(phase == .working)
        .animation(.smooth, value: phase)
        .onAppear {
            Analytics.screen("Adjust", ["scope": workout == nil ? "plan" : "day"])
            if let autoSend { send(autoSend) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .options: options
        case .writing(let reason): writing(reason)
        case .working: working
        case .done(let adjustment): done(adjustment)
        case .failed(let error, let request): failed(error, request)
        }
    }

    private var workout: Workout? {
        if case .day(let workout) = scope { workout } else { nil }
    }

    // MARK: Options

    private var options: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            header(title, subtitle)

            VStack(spacing: 0) {
                let options = self.optionList
                ForEach(options) { option in
                    Button(action: option.action) {
                        HStack(spacing: RowMetrics.spacing) {
                            Image(systemName: option.icon)
                                .font(.footnote.weight(.bold))
                                .frame(width: 32, height: 32)
                                .background(Color.surface, in: .circle)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(option.title).font(.rowTitle)
                                Text(option.subtitle).font(.detail).foregroundStyle(.muted)
                            }
                            Spacer(minLength: Spacing.s)
                            RowChevron()
                        }
                        .foregroundStyle(.ink)
                        .padding(.horizontal, RowMetrics.horizontalPadding)
                        .padding(.vertical, Spacing.m)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.haptic)
                    .accessibilityElement(children: .combine)
                    if option.id != options.last?.id {
                        Divider().padding(.leading, RowMetrics.horizontalPadding + 32 + RowMetrics.spacing)
                    }
                }
            }
            .background(Color.wash, in: .rect(cornerRadius: Radius.control))

            Button { write(.other) } label: {
                HStack(spacing: Spacing.s) {
                    Text("K")
                        .font(.system(size: 12, weight: .black).italic())
                        .foregroundStyle(.ink)
                        .frame(width: 22, height: 22)
                        .background(Color.paper, in: .circle)
                        .accessibilityHidden(true)
                    Text("Something else? Tell Kiki")
                }
                .font(.button)
                .foregroundStyle(.paper)
                .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                .background(Color.ink, in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.haptic)
        }
    }

    private var title: LocalizedStringKey {
        guard let workout else { return "Adjust your plan" }
        return workout.date == .today ? "Adjust today" : "Adjust this run"
    }

    private var subtitle: String {
        guard let workout else { return "Tell Kiki what's changed." }
        let amount = workout.distanceM.map { Format.distance(Double($0), store.units) }
            ?? workout.durationS.map { Format.minutes($0) }
        let date = workout.date == .today ? nil : workout.date.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return [date, workout.title, amount].compactMap { $0 }.joined(separator: " · ")
    }

    private var optionList: [Option] {
        if let workout {
            var list = [
                Option(id: "tired", icon: "battery.25percent", title: "I'm tired", subtitle: "Make it lighter") { send(.init(reason: .tired)) },
                Option(id: "hard", icon: "arrow.down", title: "It's too hard", subtitle: "Shorter or easier") { send(.init(reason: .tooHard)) },
                Option(id: "move", icon: "arrow.right", title: "Can't make it", subtitle: "Move it to another day") { send(.init(reason: .schedule)) },
                Option(id: "hurt", icon: "bandage", title: "Something hurts", subtitle: "Kiki eases off") { send(.init(reason: .injured)) },
            ]
            if workout.status == .planned {
                list.append(Option(id: "skip", icon: "minus", title: "Skip it", subtitle: "Rest instead. Your plan stays the same.") {
                    Haptics.success()
                    store.setStatus(.skipped, for: workout)
                    Analytics.track("adjust_quick_option", ["option": "skip"])
                    dismiss()
                })
            }
            return list
        }
        return [
            Option(id: "easier", icon: "arrow.down", title: "Make it easier", subtitle: "The plan feels too much") { send(.init(reason: .tooHard)) },
            Option(id: "harder", icon: "arrow.up", title: "Push me harder", subtitle: "I'm ready for more") { send(.init(reason: .tooEasy)) },
            Option(id: "missed", icon: "arrow.uturn.backward", title: "I've missed some runs", subtitle: "Get back on track") { send(.init(reason: .missed)) },
            Option(id: "hurt", icon: "bandage", title: "Something hurts", subtitle: "Ease off while you recover") { send(.init(reason: .injured)) },
            Option(id: "schedule", icon: "calendar", title: "My schedule changed", subtitle: "Tell Kiki what works now") { write(.schedule) },
        ]
    }

    // MARK: Writing

    private func writing(_ reason: AdjustReason) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            header(reason == .schedule ? "What's changed?" : "What's going on?",
                   workout == nil ? "Kiki will adjust your plan." : "Kiki will adjust this run.")

            VStack(alignment: .leading, spacing: Spacing.s) {
                TextField(placeholder(reason), text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($messageFocused)
                    .inputField()
                Footnote("If something hurts and it's sharp, getting worse, or lasts more than a few days, please see a medical professional.")
            }

            HStack(spacing: Spacing.m) {
                SecondaryButton("Back") {
                    messageFocused = false
                    phase = .options
                }
                PrimaryButton("Send", isEnabled: !trimmedMessage.isEmpty) {
                    send(.init(reason: reason, message: trimmedMessage))
                }
            }
        }
        .onAppear { messageFocused = true }
    }

    private var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func placeholder(_ reason: AdjustReason) -> String {
        switch reason {
        case .schedule: "e.g. I can't run on Thursdays anymore"
        default: workout == nil ? "e.g. I'm traveling next week" : "e.g. My legs feel heavy from yesterday"
        }
    }

    // MARK: Working, done, failed

    private var working: some View {
        VStack(spacing: Spacing.l) {
            ProgressView().controlSize(.large)
            VStack(spacing: Spacing.xs) {
                Text("Kiki is updating your plan…").font(.cardTitle)
                Text("This takes a few seconds.").font(.detail).foregroundStyle(.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    private func done(_ adjustment: Adjustment) -> some View {
        let changed = Set(adjustment.changedDates ?? [])
        let workouts = store.workouts.filter { changed.contains($0.date) }
        return VStack(alignment: .leading, spacing: Spacing.xl) {
            header(workouts.isEmpty ? "No changes needed" : "Plan updated", nil)
            CoachBubble(text: adjustment.reply ?? "Your plan is updated.")
            if !workouts.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(workouts.count == 1 ? "Updated workout" : "Updated workouts")
                        .font(.eyebrow)
                        .foregroundStyle(.muted)
                    WeekSchedule(workouts: workouts, units: store.units, isNavigable: false)
                }
            }
            PrimaryButton("Done") { dismiss() }
        }
    }

    private func failed(_ error: String, _ request: Request) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            header("Couldn't update your plan", LocalizedStringKey(error))
            PrimaryButton("Try again") { send(request) }
        }
    }

    private func header(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.heroTitle)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.detail)
                    .foregroundStyle(.muted)
            }
        }
    }

    private func header(_ title: LocalizedStringKey, _ subtitle: String) -> some View {
        header(title, LocalizedStringKey(subtitle))
    }

    // MARK: Actions

    private func write(_ reason: AdjustReason) {
        message = ""
        phase = .writing(reason)
    }

    private func send(_ request: Request) {
        messageFocused = false
        phase = .working
        Analytics.track("adjust_quick_option", ["option": request.reason.rawValue, "scope": workout == nil ? "plan" : "day"])
        Task {
            do {
                let adjustment = try await store.requestAdjustment(
                    reason: request.reason,
                    message: request.message,
                    targetDate: workout?.date
                )
                Haptics.success()
                phase = .done(adjustment)
            } catch {
                Haptics.error()
                if case APIError.subscriptionRequired = error { await subscriptions.refresh() }
                phase = .failed((error as? LocalizedError)?.errorDescription ?? "Please try again.", request)
            }
        }
    }
}
