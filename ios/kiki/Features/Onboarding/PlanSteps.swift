import SwiftUI

struct AccountStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "Save your plan",
            subtitle: "Create an account to keep your plan and progress.",
            showsContinue: false
        ) {
            VStack(spacing: Spacing.xxxl + Spacing.s) {
                InfoList {
                    InfoRow(symbol: "sparkles", text: "A personalized plan, built just for you")
                    InfoRow(symbol: "arrow.triangle.2.circlepath", text: "Adjust it anytime, like a real coach")
                    InfoRow(symbol: "lock.fill", text: "Private and secure. We never sell your data.")
                }

                if model.isSignedIn {
                    // RootView continues once the account loads (plan → app, else build one).
                    HStack(spacing: Spacing.m) {
                        ProgressView()
                        Text("Loading your account…").foregroundStyle(.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                } else {
                    SignInOptions {}
                }
            }
        }
    }
}

/// Saves the profile, starts plan generation and shows progress until ready.
struct GeneratingStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(TrainingStore.self) private var store

    @State private var serverProgress = 5
    @State private var displayed: Double = 0
    @State private var error: String?
    @State private var attempt = 0

    private let milestones = [
        (8, "Reading your answers"),
        (25, "Setting your starting point"),
        (45, "Planning your weeks"),
        (70, "Balancing runs and rest"),
        (90, "Adding the finishing touches"),
    ]

    var body: some View {
        VStack(spacing: Spacing.xxxl) {
            Spacer()
            ZStack {
                Circle().stroke(Color.track, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: displayed / 100)
                    .stroke(Color.ink, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(displayed))%")
                    .font(.metric(.largeTitle))
                    .contentTransition(.numericText())
            }
            .frame(width: 180, height: 180)
            .accessibilityElement()
            .accessibilityLabel("Building your plan")
            .accessibilityValue("\(Int(displayed)) percent")

            VStack(spacing: Spacing.s) {
                Text(error == nil ? (model.firstName.map { "Building your plan, \($0)" } ?? "Building your plan") : "Something went wrong")
                    .font(.screenTitle)
                    .multilineTextAlignment(.center)
                Text(error ?? "Kiki is designing every run around you. This usually takes under a minute.")
                    .foregroundStyle(.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xxxl)

            if error == nil {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    ForEach(milestones, id: \.0) { threshold, label in
                        let done = displayed >= Double(threshold + 12)
                        HStack(spacing: Spacing.m) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(done ? Color.ink : Color.track)
                                .contentTransition(.symbolEffect(.replace))
                            Text(label)
                                .foregroundStyle(displayed >= Double(threshold) ? Color.ink : Color.muted)
                        }
                    }
                }
                .font(.body.weight(.medium))
            }
            Spacer()
            if error != nil {
                PrimaryButton("Try again") {
                    error = nil
                    attempt += 1
                }
                .padding(.horizontal, Metrics.screenMargin)
            }
        }
        .padding(.bottom, Spacing.s)
        .task(id: attempt) { await build() }
        .task { await animateProgress() }
    }

    private func build() async {
        do {
            let planID: UUID
            if let pending = store.pendingPlan, pending.status == .generating {
                planID = pending.id
            } else {
                // A new goal keeps the saved profile; first-run onboarding saves it.
                if model.mode == .full { try await store.saveProfile(model.profile) }
                planID = try await store.createPlan(model.planRequest).id
            }
            _ = try await store.waitForPlan(planID) { serverProgress = $0 }
            serverProgress = 100
            try? await Task.sleep(for: .milliseconds(700))
            Haptics.success()
            model.go(to: .preview)
        } catch is CancellationError {
        } catch {
            Haptics.error()
            Analytics.captureError(error, context: ["step": "plan_generation"])
            self.error = (error as? LocalizedError)?.errorDescription ?? "Please try again."
        }
    }

    /// Eases the ring toward the server's progress so it always feels alive.
    private func animateProgress() async {
        while !Task.isCancelled {
            let target = Double(serverProgress == 100 ? 100 : min(serverProgress + 25, 97))
            if displayed < target {
                let step = serverProgress == 100 ? 4.0 : max(0.15, (target - displayed) / 40)
                withAnimation(.linear(duration: 0.1)) { displayed = min(target, displayed + step) }
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}

/// The finished plan: a quick look before the paywall (or back to the app
/// when changing goals).
struct PlanPreviewStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(TrainingStore.self) private var store

    var body: some View {
        let units = store.units
        let runs = store.workouts.filter { !$0.isRest }
        let finale = store.workouts.last { $0.type == .race }

        FlowPage(
            eyebrow: LocalizedStringKey(model.firstName.map { "\($0), your plan is ready" } ?? "Your plan is ready"),
            title: LocalizedStringKey(store.plan?.title ?? "Your plan"),
            subtitle: store.plan?.summary.map { LocalizedStringKey($0) },
            titleStyle: .display
        ) {
            HStack(spacing: Metrics.stackSpacing) {
                Stat(value: "\(store.totalWeeks)", label: "weeks")
                Stat(value: "\(Int((Double(runs.count) / Double(max(store.totalWeeks, 1))).rounded()))", label: "runs a week")
                if let finale {
                    Stat(value: Format.shortDate(finale.date), label: finale.title)
                }
            }

            PageSection("Your first week") {
                WeekSchedule(workouts: store.weeks.first?.workouts ?? [], units: units, isNavigable: false)
            }
        } actions: {
            PrimaryButton("Start my plan") {
                Analytics.track(model.mode == .full ? "onboarding_completed" : "goal_changed")
                model.finish()
            }
        }
        .onAppear { Analytics.screen("Plan Preview") }
    }

    private struct Stat: View {
        let value: String
        let label: String

        var body: some View {
            Card(padding: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(value).font(.metric(.title2)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(label).font(.footnote).foregroundStyle(.muted).lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
