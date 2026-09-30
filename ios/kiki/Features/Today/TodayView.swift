import SwiftUI

/// Today: the goal countdown and progress, today's workout, and the next
/// few days, as cards that carry their own titles (Apple's card pattern).
struct TodayView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker

    @State private var sheet: AppSheet?
    @State private var path: [Workout] = []

    var body: some View {
        let units = store.units

        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let plan = store.plan {
                        GoalProgressCard(title: greeting, plan: plan, units: units)
                    }

                    if let pending = store.pendingPlan, pending.status == .generating {
                        Card {
                            Label("Building your new plan…", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    if let workout = store.workouts.first(where: { $0.date == .today }) {
                        WorkoutHeroCard(
                            heading: "Today",
                            workout: workout,
                            run: store.run(for: workout),
                            units: units,
                            paces: store.plan?.paces,
                            onDone: { sheet = .log(workout, store.run(for: workout)) },
                            onStart: workout.isRest ? nil : { tracker.start(for: workout) }
                        )
                        .contentShape(.rect(cornerRadius: 28))
                        .onTapGesture { path.append(workout) }
                        .accessibilityAction(named: "Show details") { path.append(workout) }
                    } else {
                        OutsidePlanCard(day: .today, plan: store.plan)
                    }

                    if !upcoming.isEmpty {
                        UpcomingCard(workouts: upcoming, units: units)
                    }

                    Button {
                        sheet = .adjust
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.body.weight(.semibold))
                                .frame(width: 40, height: 40)
                                .background(Color.wash, in: .circle)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Adjust my plan").font(.body.weight(.semibold))
                                Text("Tired, busy or sore? Tell Kiki.").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.ink)
                        .padding(14)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.1)))
                    }
                    .buttonStyle(.haptic)
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .refreshable { await store.refresh() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Wordmark centered in the bar, like a home tab logo.
                ToolbarItem(placement: .principal) {
                    Text("Kiki")
                        .font(.system(size: 24, weight: .black).italic())
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workoutID: $0.id) }
            .appSheets($sheet)
            .overlay(alignment: .bottom) { OfflineBanner() }
        }
        .onAppear { Analytics.screen("Today") }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return store.profile?.firstName.map { "\(part), \($0)!" } ?? "\(part)!"
    }

    /// The next several days after today (rest days included, so the
    /// runner sees the shape of the week).
    private var upcoming: [Workout] {
        Array(store.workouts.filter { $0.date > .today }.prefix(5))
    }
}

/// The next few days in one card, with its title inside (Apple's card
/// pattern). Rows open the workout.
private struct UpcomingCard: View {
    let workouts: [Workout]
    let units: Units

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming")
                .font(.sectionTitle)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            VStack(spacing: 0) {
                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                    NavigationLink(value: workout) {
                        WorkoutRow(workout: workout, units: units)
                    }
                    .buttonStyle(.plain)
                    if index < workouts.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
        }
        .padding(14)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wash, in: .rect(cornerRadius: 28))
    }
}

/// The first thing on Today: a countdown to the goal and progress so far.
private struct GoalProgressCard: View {
    @Environment(TrainingStore.self) private var store
    /// The card's title (the greeting).
    let title: String
    let plan: Plan
    let units: Units

    var body: some View {
        let finale = store.workouts.last { $0.type == .race }
        let endDate = finale?.date ?? plan.raceDate
        let daysLeft = max(0, Day.today.days(until: endDate))
        let planRuns = store.runs.filter { Day($0.startedAt) >= plan.startDate }
        let distance = planRuns.reduce(0) { $0 + $1.distanceM }

        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) {
                Text(finale?.title ?? plan.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.paper.opacity(0.7))
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(daysLeft == 0 ? "Today" : "\(daysLeft)")
                        .font(.metric(.largeTitle))
                        .contentTransition(.numericText())
                    if daysLeft > 0 {
                        Text(daysLeft == 1 ? "day to go" : "days to go")
                            .font(.headline)
                            .foregroundStyle(.paper.opacity(0.7))
                    }
                }
            }

            HStack(spacing: 0) {
                stat(value: "\(planRuns.count)", label: planRuns.count == 1 ? "run" : "runs")
                stat(value: Format.distanceNumber(distance, units, decimals: 1), label: units == .mi ? "miles" : "km")
                stat(value: store.currentWeekNumber.map { "\($0)/\(store.totalWeeks)" } ?? "–", label: "week")
            }
        }
        .foregroundStyle(.paper)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { AsphaltBackground() }
        .clipShape(.rect(cornerRadius: 28))
        .accessibilityElement(children: .combine)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.metric(.title3))
            Text(label).font(.caption).foregroundStyle(.paper.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorkoutHeroCard: View {
    /// Optional card title (e.g. "Today"), shown above the workout.
    var heading: LocalizedStringKey?
    let workout: Workout
    let run: Run?
    let units: Units
    let paces: PaceZones?
    let onDone: () -> Void
    let onStart: (() -> Void)?

    var body: some View {
        let inverted = !workout.isRest
        VStack(alignment: .leading, spacing: 16) {
            if let heading {
                HStack {
                    Text(heading)
                        .font(.sectionTitle)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background((inverted ? Color.paper : Color.ink).opacity(0.12), in: .circle)
                        .accessibilityHidden(true)
                }
            }
            HStack {
                Text(workout.type.label.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(inverted ? Color.paper.opacity(0.6) : .secondary)
                Spacer()
                if workout.status == .completed {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                }
            }

            Text(workout.title)
                .font(.system(.title, weight: .bold))

            if let metric = Format.workoutMetric(workout, units: units) {
                HStack(alignment: .firstTextBaseline, spacing: 28) {
                    MetricView(value: metric.value, label: metric.unit, inverted: inverted)
                    if let zone = workout.type.paceZone, let range = paces?[zone] {
                        MetricView(
                            value: Format.pace(Double(range.max + range.min) / 2, units, withUnit: false),
                            label: "\(zone.rawValue) /\(units.rawValue)",
                            inverted: inverted
                        )
                    }
                }
            }

            Text(workout.description)
                .font(.subheadline)
                .foregroundStyle(inverted ? Color.paper.opacity(0.75) : .secondary)
                .lineLimit(4)

            if let run {
                RunSummaryLine(run: run, units: units, inverted: inverted)
            }

            if !workout.isRest {
                HStack(spacing: 10) {
                    Button(action: onDone) {
                        Text(workout.status == .completed ? "Edit run" : "Mark as done")
                            .font(.headline)
                            .foregroundStyle(.ink)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.paper, in: .capsule)
                    }
                    .buttonStyle(.haptic)

                    if let onStart, workout.status != .completed {
                        Button(action: onStart) {
                            Image(systemName: "figure.run")
                                .font(.headline)
                                .foregroundStyle(.paper)
                                .frame(width: 50, height: 50)
                                .overlay(Circle().stroke(Color.paper.opacity(0.35), lineWidth: 1.5))
                                .contentShape(.circle)
                        }
                        .buttonStyle(.haptic)
                        .accessibilityLabel("Start run with GPS")
                    }
                }
                .padding(.top, 4)
            } else {
                Button("Log a run anyway", action: onDone)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ink)
                    .buttonStyle(.haptic)
            }
        }
        .foregroundStyle(inverted ? Color.paper : Color.ink)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(inverted ? Color.ink : Color.wash, in: .rect(cornerRadius: 28))
    }
}

struct MetricView: View {
    let value: String
    let label: String
    var inverted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.metric(.largeTitle))
            Text(label).font(.caption).foregroundStyle(inverted ? Color.paper.opacity(0.6) : .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RunSummaryLine: View {
    let run: Run
    let units: Units
    var inverted = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text([
                Format.distance(run.distanceM, units),
                Format.duration(run.durationS),
                run.pace.map { Format.pace($0, units) },
                run.feeling.map { "\($0.emoji) \($0.label)" },
            ].compactMap { $0 }.joined(separator: " · "))
        }
        .font(.subheadline.weight(.semibold))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((inverted ? Color.paper : Color.ink).opacity(0.1), in: .rect(cornerRadius: 14))
    }
}

private struct OutsidePlanCard: View {
    let day: Day
    let plan: Plan?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                if let plan, day < plan.startDate {
                    Text("Before your plan").font(.headline)
                    Text("Your plan starts \(Format.shortDate(plan.startDate)).").foregroundStyle(.secondary)
                } else {
                    Text("Nothing scheduled").font(.headline)
                    Text("This day is outside your plan.").foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct OfflineBanner: View {
    @Environment(TrainingStore.self) private var store

    var body: some View {
        if !store.isOnline {
            Label("Offline. Changes will sync automatically.", systemImage: "wifi.slash")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect()
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// The splash's asphalt texture with a soft, warm "sun" that drifts slowly
/// across and back, so the card feels alive. Still under Reduce Motion.
struct AsphaltBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.launchBackground
                Image(.launchTexture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                RadialGradient(
                    colors: [
                        Color(red: 1, green: 0.74, blue: 0.4).opacity(0.28),
                        Color(red: 1, green: 0.55, blue: 0.2).opacity(0.08),
                        .clear,
                    ],
                    center: UnitPoint(x: -0.1 + 1.2 * phase, y: 0.1),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.75
                )
                .blendMode(.screen)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { phase = 0.7; return }
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }
}
