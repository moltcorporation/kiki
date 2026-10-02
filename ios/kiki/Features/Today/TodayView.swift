import SwiftUI

/// Home: the goal card (with the plan actions), today's workout, this week
/// at a glance, and Help Kiki grow, on the shared tab layout.
struct TodayView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker

    /// Switches to the Plan tab (the goal card's "View plan").
    var onViewPlan: () -> Void = {}

    @State private var sheet: AppSheet?
    /// Holds `Workout`s and `HomeRoute`s.
    @State private var path = NavigationPath()

    enum HomeRoute: Hashable { case goal }

    var body: some View {
        let units = store.units

        NavigationStack(path: $path) {
            TabPage(LocalizedStringKey(greeting), eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
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
                            weekRuns: store.workouts(inWeekOf: .today).filter { !$0.isRest }.sorted { $0.date < $1.date },
                            name: store.profile?.firstName,
                            onOpen: { path.append(workout) },
                            onStart: { tracker.start(for: workout) }
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

    /// "Hello, Stuart!"
    private var greeting: String {
        store.profile?.firstName.map { "Hello, \($0)!" } ?? "Hello!"
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

            Rectangle()
                .fill(Color.hairline)
                .frame(height: 1)

            HStack(spacing: 0) {
                footerAction("Adjust plan", systemImage: "sparkles", action: onAdjust)
                Rectangle()
                    .fill(Color.hairline)
                    .frame(width: 1, height: Spacing.xl)
                footerAction("View plan", systemImage: "calendar", action: onViewPlan)
            }
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

        return VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(plan.displayName)
                    .font(.heroTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    // Clear of the watermark.
                    .padding(.trailing, 64)
                // The date, and the target time for time goals.
                Text([Plan.goalDate(timeline.endDate), plan.goalTimeLabel].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.ink.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text(countdown)
                        .font(.headline)
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
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.ink.opacity(0.12))
                .padding(Metrics.cardPadding)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }

    /// One half of the footer: icon + label, centered, full height.
    private func footerAction(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.ink)
                .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                .contentShape(.rect)
        }
        .buttonStyle(.haptic)
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

/// Today's workout at a glance: where it falls in the week, what it is,
/// how far and how long (or what they ran, once logged), a play button to
/// start it, and a short note from Kiki. Tapping the card opens the workout.
struct TodayCard: View {
    let workout: Workout
    let run: Run?
    let units: Units
    let paces: PaceZones?
    /// This week's runs in order, for "Run 2 of 3 this week".
    let weekRuns: [Workout]
    let name: String?
    let onOpen: () -> Void
    let onStart: () -> Void

    private var canStart: Bool { !workout.isRest && run == nil && workout.status == .planned }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.m) {
                Button(action: onOpen) {
                    summary
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.haptic)
                .accessibilityHint("Shows the workout")

                if canStart {
                    Button(action: onStart) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.paper)
                            .frame(width: 56, height: 56)
                            .background(Color.ink, in: .circle)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.haptic)
                    .accessibilityLabel("Start run")
                }
            }
            .padding(Metrics.cardPadding)

            Rectangle().fill(Color.hairline).frame(height: 1)

            // A short note from Kiki.
            HStack(spacing: Spacing.m) {
                KikiLogo(size: 24)
                Text(coachNote)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.cardPadding)
            .padding(.vertical, Spacing.m + Spacing.xs)
            .accessibilityElement(children: .combine)
        }
        .foregroundStyle(.ink)
        .elevatedCard()
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(eyebrow)
                .font(.eyebrow)
                .foregroundStyle(.muted)
            Text(workout.isRest ? "Rest day" : workout.title)
                .font(.cardTitle)
                .lineLimit(2)

            if !workout.isRest {
                HStack(alignment: .lastTextBaseline, spacing: Spacing.xl) {
                    if let run {
                        Figure(value: Format.distanceNumber(run.distanceM, units), unit: units.rawValue)
                        Figure(value: "\(Int((Double(run.durationS) / 60).rounded()))", unit: "min")
                        if let pace = run.pace {
                            Detail(value: Format.pace(pace, units, withUnit: false), label: "/\(units.rawValue) pace")
                        }
                    } else {
                        if let meters = workout.distanceM {
                            Figure(value: Format.distanceNumber(Double(meters), units), unit: units.rawValue)
                        }
                        if let minutes = plannedMinutes {
                            Figure(value: "\(minutes)", unit: "min")
                        }
                        if let pace = targetPace {
                            Detail(value: Format.pace(pace, units, withUnit: false), label: "/\(units.rawValue) pace")
                        }
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Run 2 of 3 this week", "Done · Run 1 of 3", or "Recovery".
    private var eyebrow: String {
        if workout.isRest { return "Recovery" }
        guard let index = weekRuns.firstIndex(where: { $0.id == workout.id }) else { return workout.type.label }
        let position = "Run \(index + 1) of \(weekRuns.count)"
        return run != nil || workout.status == .completed ? "Done · \(position)" : "\(position) this week"
    }

    /// The average of the type's pace range, in seconds per km.
    private var targetPace: Double? {
        guard let zone = workout.type.paceZone, let range = paces?[zone] else { return nil }
        return Double(range.min + range.max) / 2
    }

    /// Planned time, or distance at the target pace.
    private var plannedMinutes: Int? {
        if let seconds = workout.durationS { return Int((Double(seconds) / 60).rounded()) }
        guard let meters = workout.distanceM, let pace = targetPace else { return nil }
        return Int((Double(meters) / 1000 * pace / 60).rounded())
    }

    /// A short coach line. Canned for now (by workout type and time of day);
    /// the AI coach can write these later.
    private var coachNote: String {
        let who = name.map { ", \($0)" } ?? ""
        let when = Calendar.current.component(.hour, from: .now) >= 17 ? "tonight" : "today"
        if workout.isRest { return "Rest is training too\(who). Enjoy the day off." }
        if run != nil || workout.status == .completed { return "Nice work\(who). Recovery starts now." }
        switch workout.type.paceZone {
        case .easy, .recovery: return "Keep it conversational \(when)\(who)."
        case .long: return "Settle in and keep it steady\(who)."
        case .tempo: return "Comfortably hard \(when)\(who). You've got this."
        case .interval: return "Push the reps, recover between\(who)."
        case .race: return "Trust your training\(who)."
        case nil: return "Enjoy it \(when)\(who)."
        }
    }

    /// A bold number with its unit below ("2.0" / "mi").
    private struct Figure: View {
        let value: String
        let unit: String

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.metric(.title2))
                Text(unit).font(.caption.weight(.medium)).foregroundStyle(.muted)
            }
        }
    }

    /// A smaller value with its label below ("11:56" / "/mi pace").
    private struct Detail: View {
        let value: String
        let label: String

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
                Text(label).font(.caption.weight(.medium)).foregroundStyle(.muted)
            }
        }
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
