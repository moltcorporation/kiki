import SwiftUI

/// Home: the goal card (with the plan actions), today's workout and the next few
/// days, on the shared tab layout.
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
                        NavigationLink(value: workout) {
                            TodayCard(workout: workout, run: store.run(for: workout), units: units, paces: store.plan?.paces)
                        }
                        .buttonStyle(.haptic)
                    } else {
                        OutsidePlanCard(day: .today, plan: store.plan)
                    }
                }

                if !upcoming.isEmpty {
                    PageSection("Upcoming") {
                        WeekSchedule(workouts: upcoming, units: units)
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

    /// "Good morning, Stuart!", by time of day.
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
        // A faint finish flag in the corner, like a watermark.
        .overlay(alignment: .topTrailing) {
            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 40, weight: .bold))
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

/// Today's workout at a glance: what it is, how far and how fast (or what
/// they actually ran, once logged), and how it should feel. The whole card
/// opens the workout.
struct TodayCard: View {
    let workout: Workout
    let run: Run?
    let units: Units
    let paces: PaceZones?

    var body: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(workout.isRest ? "Rest day" : workout.title)
                    .font(.cardTitle)

                if workout.isRest {
                    Text("Recovery is when your body gets stronger. Take it easy today.")
                        .font(.detail)
                        .foregroundStyle(.muted)
                } else if let run {
                    // Logged: what they actually did.
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xl) {
                        Figure(value: Format.distanceNumber(run.distanceM, units), unit: units.rawValue)
                        Figure(value: Format.duration(run.durationS), unit: nil)
                        if let pace = run.pace {
                            Figure(value: Format.pace(pace, units, withUnit: false), unit: "/\(units.rawValue)")
                        }
                    }
                    Text("Done\(run.feeling.map { " · Felt \($0.label.lowercased()) \($0.emoji)" } ?? "")")
                        .font(.detail)
                        .foregroundStyle(.muted)
                } else {
                    // Planned: how far, how fast, how it should feel.
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xl) {
                        if let meters = workout.distanceM {
                            Figure(value: Format.distanceNumber(Double(meters), units), unit: units.rawValue)
                        } else if let seconds = workout.durationS {
                            Figure(value: "\(Int((Double(seconds) / 60).rounded()))", unit: "min")
                        }
                        if let zone = workout.type.paceZone, let range = paces?[zone] {
                            Figure(value: Format.pace(Double(range.min + range.max) / 2, units, withUnit: false), unit: "/\(units.rawValue)")
                        }
                    }
                    if let zone = workout.type.paceZone {
                        Text(zone.effort)
                            .font(.detail)
                            .foregroundStyle(.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            RowChevron()
        }
        .foregroundStyle(.ink)
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
        .contentShape(.rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the workout")
    }

    /// A bold number with a small unit after it ("2.0 mi", "11:56 /mi").
    private struct Figure: View {
        let value: String
        let unit: String?

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(value).font(.metric(.title2))
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.muted)
                }
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
