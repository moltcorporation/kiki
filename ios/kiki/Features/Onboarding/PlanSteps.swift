import SwiftUI

struct AccountStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "Save your plan",
            subtitle: "Create your account so your plan and progress are always with you.",
            showsContinue: false
        ) {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(symbol: "sparkles", text: "A personalized plan, built just for you")
                    InfoRow(symbol: "arrow.triangle.2.circlepath", text: "Adjust it anytime, like a real coach")
                    InfoRow(symbol: "lock.fill", text: "Private and secure. We never sell your data.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)

                SignInOptions {
                    model.isSignedIn = true
                    model.go(to: .generating)
                }

                LegalFootnote(prefix: "By continuing, you agree to our")
            }
        }
    }
}

struct LegalFootnote: View {
    var prefix: String

    var body: some View {
        Text("\(prefix) [Terms](\(Config.termsURL.absoluteString)) and [Privacy Policy](\(Config.privacyURL.absoluteString)).")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .tint(.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
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
        (8, "Analyzing your running"),
        (25, "Setting your training paces"),
        (45, "Mapping your training phases"),
        (70, "Building your weeks"),
        (90, "Balancing hard and easy days"),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().stroke(Color.wash, lineWidth: 14)
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

            VStack(spacing: 8) {
                Text(error == nil ? "Building your plan" : "Something went wrong")
                    .font(.title.weight(.bold))
                Text(error ?? "Kiki is designing every workout around you. This usually takes under a minute.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            if error == nil {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(milestones, id: \.0) { threshold, label in
                        let done = displayed >= Double(threshold + 12)
                        HStack(spacing: 12) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(done ? Color.ink : Color.secondary.opacity(0.4))
                                .contentTransition(.symbolEffect(.replace))
                            Text(label)
                                .foregroundStyle(displayed >= Double(threshold) ? Color.ink : Color.secondary)
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
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 8)
        .background(Color.paper)
        .task(id: attempt) { await build() }
        .task { await animateProgress() }
    }

    private func build() async {
        do {
            let planID: UUID
            if let pending = store.pendingPlan, pending.status == .generating {
                planID = pending.id
            } else {
                try await store.saveProfile(model.profile)
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

/// The finished plan, before the paywall.
struct PlanPreviewStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(TrainingStore.self) private var store

    var body: some View {
        let units = store.units
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(greeting)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(store.plan?.title ?? "Your plan is ready")
                        .font(.display(.largeTitle))
                        .fixedSize(horizontal: false, vertical: true)
                    if let summary = store.plan?.summary {
                        Text(summary).foregroundStyle(.secondary)
                    }
                }

                if let plan = store.plan {
                    HStack(spacing: 12) {
                        Stat(value: "\(store.totalWeeks)", label: "weeks")
                        Stat(value: "\(store.workouts.filter { !$0.isRest }.count)", label: "runs")
                        if let predicted = plan.predictedTimeS {
                            Stat(value: Format.duration(predicted), label: "predicted")
                        } else {
                            Stat(value: Format.shortDate(plan.raceDate), label: "race day")
                        }
                    }

                    if let phases = plan.phases, !phases.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your journey").font(.headline)
                            PhaseTimeline(phases: phases, totalWeeks: store.totalWeeks)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your first week").font(.headline)
                    ForEach(firstWeek) { workout in
                        WorkoutRow(workout: workout, units: units)
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("Start my plan") {
                Analytics.track("onboarding_completed")
                model.reset()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .background(Color.paper)
        }
        .background(Color.paper)
        .onAppear { Analytics.screen("Plan Preview") }
    }

    private var greeting: String {
        if let name = store.profile?.firstName { return "\(name), your plan is ready" }
        return "Your plan is ready"
    }

    private var firstWeek: [Workout] {
        Array(store.workouts.filter { !$0.isRest }.prefix(5))
    }

    private struct Stat: View {
        let value: String
        let label: String

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.metric(.title2)).minimumScaleFactor(0.6).lineLimit(1)
                Text(label).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.wash, in: .rect(cornerRadius: 18))
        }
    }
}

struct PhaseTimeline: View {
    let phases: [PlanPhase]
    let totalWeeks: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                        let weeks = max(1, phase.endWeek - phase.startWeek + 1)
                        Capsule()
                            .fill(Color.ink.opacity(0.35 + 0.65 * Double(index + 1) / Double(phases.count)))
                            .frame(width: max(8, (proxy.size.width - CGFloat(phases.count - 1) * 3) * CGFloat(weeks) / CGFloat(max(totalWeeks, 1))))
                    }
                }
            }
            .frame(height: 10)
            ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                HStack(alignment: .firstTextBaseline) {
                    Text(phase.name).font(.subheadline.weight(.semibold))
                    Text("Weeks \(phase.startWeek)–\(phase.endWeek)").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
                Text(phase.focus).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
