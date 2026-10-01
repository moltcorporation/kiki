import SwiftUI

/// Home: the goal countdown and progress, today's workout, and the next few
/// days, on the shared tab layout.
struct TodayView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker

    @State private var sheet: AppSheet?
    /// Holds `Workout`s and `HomeRoute`s.
    @State private var path = NavigationPath()

    enum HomeRoute: Hashable { case goal }

    var body: some View {
        let units = store.units

        NavigationStack(path: $path) {
            TabPage(LocalizedStringKey(greeting)) {
                // The goal, with Adjust my plan right under it.
                if let plan = store.plan {
                    VStack(spacing: Metrics.stackSpacing) {
                        Button { path.append(HomeRoute.goal) } label: {
                            GoalProgressCard(plan: plan, units: units)
                        }
                        .buttonStyle(.haptic)
                        .accessibilityHint("Shows your goal details")
                        ListCard {
                            Button {
                                sheet = .adjust
                            } label: {
                                ListRow(
                                    icon: "sparkles",
                                    title: Text("Adjust my plan"),
                                    subtitles: ["Tired, busy or sore? Tell Kiki."],
                                    showsChevron: true
                                )
                            }
                            .buttonStyle(.haptic)
                        }
                    }
                }

                if let pending = store.pendingPlan, pending.status == .generating {
                    MessageCard(icon: "sparkles", title: "Building your new plan…", message: "This usually takes under a minute.")
                }

                PageSection("Today") {
                    if let workout = store.workouts.first(where: { $0.date == .today }) {
                        WorkoutHeroCard(
                            workout: workout,
                            run: store.run(for: workout),
                            units: units,
                            paces: store.plan?.paces,
                            onDone: { sheet = .log(workout, store.run(for: workout)) },
                            onStart: workout.isRest ? nil : { tracker.start(for: workout) }
                        )
                        .contentShape(.rect(cornerRadius: Radius.card))
                        .onTapGesture { path.append(workout) }
                        .accessibilityAction(named: "Show details") { path.append(workout) }
                    } else {
                        OutsidePlanCard(day: .today, plan: store.plan)
                    }
                }

                if !upcoming.isEmpty {
                    PageSection("Upcoming") {
                        WorkoutListCard(workouts: upcoming, units: units)
                    }
                }

            }
            .refreshable { await store.refresh() }
            .hidesTabBar(!path.isEmpty)
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workoutID: $0.id) }
            .navigationDestination(for: HomeRoute.self) { _ in GoalDetailView() }
            .appSheets($sheet)
            .overlay(alignment: .bottom) { OfflineBanner() }
        }
        .onAppear { Analytics.screen("Home") }
    }

    /// "Good morning, Stuart!"
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

/// A list of workouts in one card (Home's Upcoming, each week on Plan).
/// Rows open the workout.
struct WorkoutListCard: View {
    let workouts: [Workout]
    let units: Units

    var body: some View {
        ListCard(dividerInset: WorkoutRow.textInset) {
            ForEach(workouts) { workout in
                NavigationLink(value: workout) {
                    WorkoutRow(workout: workout, units: units)
                }
                .buttonStyle(.haptic)
            }
        }
    }
}

/// The first thing on Today: a countdown to the goal and progress so far.
private struct GoalProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units

    var body: some View {
        let finale = store.workouts.last { $0.type == .race }
        let endDate = finale?.date ?? plan.raceDate
        let daysLeft = max(0, Day.today.days(until: endDate))
        let week = store.currentWeekNumber
        let total = max(store.totalWeeks, 1)

        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Your goal")
                    .font(.eyebrow)
                    .foregroundStyle(.muted)
                Text(plan.goalHeadline(units: units))
                    .font(.heroTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(plan.goalSubline(units: units, endDate: endDate))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.muted)
            }

            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text(daysLeft == 0 ? "It's today!" : daysLeft == 1 ? "1 day to go" : "\(daysLeft) days to go")
                        .font(.headline)
                    Spacer()
                    if let week {
                        Text("Week \(week) of \(total)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.muted)
                    }
                }
                ProgressView(value: Double(min(week ?? 0, total)), total: Double(total))
                    .tint(.ink)
                    .accessibilityHidden(true)
            }
        }
        // Always dark: white type on the asphalt, in light and dark mode.
        .foregroundStyle(.ink)
        .environment(\.colorScheme, .dark)
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background { AsphaltBackground() }
        .clipShape(.rect(cornerRadius: Radius.card))
        .elevation(.raised)
        .accessibilityElement(children: .combine)
    }
}

extension Plan {
    /// What the runner is working toward, in plain words: "Finish the
    /// Chicago Marathon", "10K in 45:00", "Run 30 minutes non-stop".
    func goalHeadline(units: Units) -> String {
        let distance = distanceLabel(units: units)
        switch goalKind {
        case .race:
            if goalType == .time, let time = goalTimeS {
                return "\(raceName ?? distance) in \(Format.duration(time))"
            }
            return "Finish the \(raceName ?? distance)"
        case .faster:
            if let time = goalTimeS { return "\(distance) in \(Format.duration(time))" }
            return "A faster \(distance)"
        case .start:
            return "Run 30 minutes non-stop"
        case .fit:
            return "Run consistently"
        }
    }

    /// The when (and the distance, if a named race hides it).
    func goalSubline(units: Units, endDate: Day) -> String {
        let date = endDate.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        switch goalKind {
        case .race:
            return raceName == nil ? date : "\(distanceLabel(units: units)) · \(date)"
        case .faster:
            return "Time trial · \(date)"
        case .start, .fit:
            return "By \(date)"
        }
    }
}

/// Today's workout: a standard white card that leads with a big title and
/// metrics. Home's only dark card is the goal, so the two don't compete.
struct WorkoutHeroCard: View {
    let workout: Workout
    let run: Run?
    let units: Units
    let paces: PaceZones?
    let onDone: () -> Void
    let onStart: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack {
                Text(workout.type.label)
                    .font(.eyebrow)
                    .foregroundStyle(.muted)
                Spacer()
                if workout.status == .completed {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.eyebrow)
                }
            }

            Text(workout.title)
                .font(.heroTitle)

            if let metric = Format.workoutMetric(workout, units: units) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxxl) {
                    MetricView(value: metric.value, label: metric.unit)
                    if let zone = workout.type.paceZone, let range = paces?[zone] {
                        MetricView(
                            value: Format.pace(Double(range.max + range.min) / 2, units, withUnit: false),
                            label: "\(zone.rawValue) /\(units.rawValue)"
                        )
                    }
                }
            }

            Text(workout.description)
                .font(.detail)
                .foregroundStyle(.muted)
                .lineLimit(4)

            if let run {
                RunSummaryLine(run: run, units: units)
            }

            if !workout.isRest {
                HStack(spacing: Spacing.m) {
                    PrimaryButton(workout.status == .completed ? "Edit run" : "Mark as done", action: onDone)
                    if let onStart, workout.status != .completed {
                        CircleButton("Start run with GPS", systemImage: "figure.run", action: onStart)
                    }
                }
                .controlSize(.small)
                .padding(.top, Spacing.xs)
            } else {
                Button("Log a run anyway", action: onDone)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ink)
                    .frame(minHeight: Metrics.minTapTarget)
                    .buttonStyle(.haptic)
            }
        }
        .foregroundStyle(.ink)
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
    }
}

/// A finished run in one line: distance · time · pace · feeling.
struct RunSummaryLine: View {
    let run: Run
    let units: Units

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
            Text([
                Format.distance(run.distanceM, units),
                Format.duration(run.durationS),
                run.pace.map { Format.pace($0, units) },
                run.feeling.map { "\($0.emoji) \($0.label)" },
            ].compactMap { $0 }.joined(separator: " · "))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.ink)
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ink.opacity(0.08), in: .rect(cornerRadius: Radius.inner))
    }
}

private struct OutsidePlanCard: View {
    let day: Day
    let plan: Plan?

    var body: some View {
        if let plan, day < plan.startDate {
            MessageCard(icon: "calendar", title: "Before your plan", message: "Your plan starts \(Format.shortDate(plan.startDate)).")
        } else {
            MessageCard(icon: "calendar", title: "Nothing scheduled", message: "This day is outside your plan.")
        }
    }
}

struct OfflineBanner: View {
    @Environment(TrainingStore.self) private var store

    var body: some View {
        if !store.isOnline {
            Label("Offline. Changes will sync automatically.", systemImage: "wifi.slash")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
                .glassEffect()
                .padding(.bottom, Spacing.s)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
