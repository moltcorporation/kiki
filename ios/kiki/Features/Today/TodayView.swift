import SwiftUI

/// Home: the goal card (with the plan actions), today's workout, this week
/// at a glance, and Help Kiki grow, on the shared tab layout.
struct TodayView: View {
    @Environment(TrainingStore.self) private var store

    /// Switches to the Plan tab (the goal card's "View plan").
    var onViewPlan: () -> Void = {}

    @State private var sheet: AppSheet?
    /// Holds `Workout`s and `HomeRoute`s.
    @State private var path = NavigationPath()

    enum HomeRoute: Hashable { case goal }

    var body: some View {
        let units = store.units

        NavigationStack(path: $path) {
            TabPage(LocalizedStringKey(greeting)) {
                // The goal: Home's header, with the plan actions in its footer.
                if let plan = store.plan {
                    GoalProgressCard(
                        plan: plan,
                        units: units,
                        onOpen: { path.append(HomeRoute.goal) },
                        onAdjust: { sheet = .adjust },
                        onViewPlan: onViewPlan
                    )
                }

                if let pending = store.pendingPlan, pending.status == .generating {
                    MessageCard(icon: "sparkles", title: "Building your new plan…", message: "This usually takes under a minute.")
                }

                PageSection("Today") {
                    if let workout = store.workouts.first(where: { $0.date == .today }) {
                        TodayCard(
                            workout: workout,
                            run: store.run(for: workout),
                            units: units,
                            paces: store.plan?.paces,
                            onOpen: { path.append(workout) },
                            onLog: { sheet = .log(workout, store.run(for: workout)) },
                            onAdjust: { sheet = .adjust }
                        )
                    } else {
                        OutsidePlanCard(day: .today, plan: store.plan)
                    }
                }

                if !store.workouts(inWeekOf: .today).isEmpty {
                    PageSection("This week", actionTitle: "See plan", action: onViewPlan) {
                        ThisWeekCard(units: units) { path.append($0) }
                    }
                }


                GetSetUpSection()

                HelpKikiGrowSection()

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

    /// "Good evening,\nStuart!" by time of day, on two lines so it always
    /// fits; "Good evening!" without a name.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return store.profile?.firstName.map { "\(part),\n\($0)!" } ?? "\(part)!"
    }
}

/// Home's header: the goal, its date, the countdown and progress on the
/// asphalt (tap for the goal details), with the plan
/// actions in its footer.
private struct GoalProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units
    let onOpen: () -> Void
    let onAdjust: () -> Void
    let onViewPlan: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) {
                summary
            }
            .buttonStyle(.haptic)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Shows your goal details")

            CardActions(
                .init("Adjust plan", systemImage: "sparkles", perform: onAdjust),
                .init("View schedule", systemImage: "calendar", perform: onViewPlan)
            )
        }
        // Always dark: white type on the asphalt, in light and dark mode.
        .foregroundStyle(.ink)
        .environment(\.colorScheme, .dark)
        .background { AsphaltBackground() }
        .clipShape(.rect(cornerRadius: Radius.card))
        .elevation(.raised)
    }

    private var summary: some View {
        let timeline = PlanTimeline(plan: plan, store: store)
        let countdown = switch timeline.phase {
        case .underway: timeline.daysLeft == 1 ? "1 day to go" : "\(timeline.daysLeft) days to go"
        case .goalDay: plan.goalKind == .race ? "It's race day!" : "It's today!"
        case .finished: "Plan finished"
        }

        return VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(plan.displayName)
                    .font(.heroTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    // Clear of the watermark.
                    .padding(.trailing, 56)
                // The date ("Wed, Dec 16"), and the target time for time goals.
                Text([shortGoalDate(timeline.endDate), plan.goalTimeLabel].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.ink.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text(countdown)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("Week \(timeline.week) of \(timeline.totalWeeks)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.ink.opacity(0.7))
                }
                ProgressView(value: Double(timeline.week), total: Double(timeline.totalWeeks))
                    .tint(.ink)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.ink)
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // A faint runner in the corner, like a watermark.
        .overlay(alignment: .topTrailing) {
            Image(systemName: "figure.run")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.ink.opacity(0.12))
                .padding(Metrics.cardPadding)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }

    /// "Wed, Dec 16", with the year only when it isn't this year.
    private func shortGoalDate(_ day: Day) -> String {
        let isThisYear = Calendar.current.isDate(day.date, equalTo: .now, toGranularity: .year)
        return isThisYear
            ? day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            : day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }
}

extension Plan {
    /// "Goal 3:45:00" for goals with a target time, else nil.
    var goalTimeLabel: String? {
        guard goalKind == .faster || goalType == .time, let time = goalTimeS else { return nil }
        return "Goal \(Format.duration(time))"
    }

    /// A goal's date: "December 16", with the year
    /// only when it isn't this year ("March 7, 2027").
    static func goalDate(_ day: Day) -> String {
        let isThisYear = Calendar.current.isDate(day.date, equalTo: .now, toGranularity: .year)
        return isThisYear
            ? day.date.formatted(.dateTime.month(.wide).day())
            : day.date.formatted(.dateTime.month(.wide).day().year())
    }
}

/// Today's workout in one row (icon, title, "2.0 mi · 24 min", chevron to
/// open it) with Mark done and Adjust day in the footer. Once logged it
/// shows what they ran and Edit run; rest days have no footer.
struct TodayCard: View {
    let workout: Workout
    let run: Run?
    let units: Units
    let paces: PaceZones?
    let onOpen: () -> Void
    let onLog: () -> Void
    let onAdjust: () -> Void

    private var isDone: Bool { run != nil || workout.status == .completed }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: Spacing.m + Spacing.xs) {
                    Image(systemName: workout.isRest ? "moon.zzz" : workout.type.symbol)
                        .font(.title3.weight(.medium))
                        .frame(width: 48, height: 48)
                        .background(Color.wash, in: .rect(cornerRadius: Radius.inner))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(workout.isRest ? "Rest day" : workout.title)
                            .font(.rowTitle)
                            .strikethrough(workout.status == .skipped)
                        Text(detail)
                            .font(.detail)
                            .foregroundStyle(.muted)
                    }
                    Spacer(minLength: Spacing.s)
                    RowChevron()
                }
                .foregroundStyle(.ink)
                .padding(Metrics.cardPadding - Spacing.xs)
                .contentShape(.rect)
            }
            .buttonStyle(.haptic)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Shows the workout")

            if !workout.isRest {
                CardActions(
                    .init(isDone ? "Edit run" : "Mark done", systemImage: isDone ? "pencil" : "checkmark", perform: onLog),
                    .init("Adjust day", systemImage: "slider.horizontal.3", perform: onAdjust)
                )
            }
        }
        .elevatedCard()
    }

    /// "2.0 mi · 24 min", "Done · 3.0 mi · 30 min", "Skipped", or the rest
    /// day note.
    private var detail: String {
        if workout.isRest { return "Recovery is part of training" }
        if workout.status == .skipped { return "Skipped" }
        if let run {
            return "Done · \(Format.distance(run.distanceM, units)) · \(Int((Double(run.durationS) / 60).rounded())) min"
        }
        let distance = workout.distanceM.map { Format.distance(Double($0), units) }
        let minutes = plannedMinutes.map { "\($0) min" }
        let parts = [distance, minutes].compactMap { $0 }
        return parts.isEmpty ? workout.type.label : parts.joined(separator: " · ")
    }

    /// Planned time, or distance at the type's target pace.
    private var plannedMinutes: Int? {
        if let seconds = workout.durationS { return Int((Double(seconds) / 60).rounded()) }
        guard let meters = workout.distanceM, let zone = workout.type.paceZone, let range = paces?[zone] else { return nil }
        let pace = Double(range.min + range.max) / 2
        return Int((Double(meters) / 1000 * pace / 60).rounded())
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
