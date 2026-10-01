import SwiftUI

/// The whole plan: a summary card, then each week as a title with its
/// workouts in one card (the same card style as Home). Opens scrolled to
/// the current week.
struct PlanView: View {
    @Environment(TrainingStore.self) private var store
    @State private var path: [Workout] = []

    var body: some View {
        let units = store.units
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                TabPage("Your plan") {
                    if let plan = store.plan {
                        ProgressCard(plan: plan, units: units)
                    }
                    ForEach(store.weeks, id: \.week) { week, workouts in
                        PageSection("Week \(week)", detail: summary(workouts, units: units)) {
                            WorkoutListCard(workouts: workouts, units: units)
                        }
                        .id(week)
                    }
                }
                .refreshable { await store.refresh() }
                .hidesTabBar(!path.isEmpty)
                .onAppear {
                    if let current = store.currentWeekNumber, current > 1 {
                        proxy.scrollTo(current, anchor: .top)
                    }
                }
            }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workoutID: $0.id) }
        }
        .onAppear { Analytics.screen("Plan") }
    }

    /// "1/4 · 17 mi": runs done out of runs planned, and planned distance.
    private func summary(_ workouts: [Workout], units: Units) -> String {
        let planned = workouts.compactMap(\.distanceM).reduce(0, +)
        let done = workouts.filter { !$0.isRest && $0.status == .completed }.count
        let runs = workouts.filter { !$0.isRest }.count
        return "\(done)/\(runs) · \(Format.distance(Double(planned), units, decimals: 0))"
    }
}

/// The top of the Plan tab: progress and goal together. A ring that fills
/// as the plan goes by, weeks to go inside it, and a 2×2 grid split by
/// hairlines: miles run and longest run (progress), race day and race
/// distance (the goal).
struct ProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units

    var body: some View {
        let runs = store.runs.filter { Day($0.startedAt) >= plan.startDate && Day($0.startedAt) <= plan.raceDate }
        let distanceM = runs.reduce(0) { $0 + $1.distanceM }
        let longestM = runs.map(\.distanceM).max() ?? 0
        // Same count as the goal ("10 weeks to go").
        let weeksToGo = max(0, Day.today.days(until: plan.raceDate) / 7)
        // How far through the plan: the same measure as the goal card's bar.
        let total = max(store.totalWeeks, 1)
        let week = min(store.currentWeekNumber ?? (Day.today > plan.raceDate ? total : 0), total)
        let isRace = plan.goalKind == .race

        Card {
            HStack(spacing: Spacing.xl) {
                PlanRing(progress: Double(week) / Double(total), weeksToGo: weeksToGo)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Stat(value: Format.distanceNumber(distanceM, units), label: units == .mi ? "Miles run" : "Km run")
                        verticalRule
                        Stat(value: Format.distanceNumber(longestM, units), label: "Longest run")
                    }
                    Rectangle().fill(Color.hairline).frame(height: 1)
                    HStack(spacing: 0) {
                        Stat(value: shortDate(plan.raceDate), label: isRace ? "Race day" : "Goal date")
                        verticalRule
                        goalStat(runs: runs)
                    }
                }
            }
        }
    }

    /// The goal's distance; for goals without one, what they're working
    /// toward (30 minutes) or their average pace.
    @ViewBuilder
    private func goalStat(runs: [Run]) -> some View {
        if let meters = plan.raceDistanceM ?? plan.raceDistance?.meters {
            Stat(value: Format.distance(Double(meters), units), label: "Distance")
        } else if plan.goalKind == .start {
            Stat(value: "30 min", label: "Goal")
        } else {
            let timed = runs.filter { $0.durationS > 0 && $0.distanceM > 0 }
            let meters = timed.reduce(0) { $0 + $1.distanceM }
            let seconds = Double(timed.reduce(0) { $0 + $1.durationS })
            Stat(value: meters > 0 ? Format.pace(seconds / (meters / 1000), units, withUnit: false) : "–:––",
                 label: "Avg. pace /\(units.rawValue)")
        }
    }

    /// "Dec 16", with the year only when it isn't this year.
    private func shortDate(_ day: Day) -> String {
        let isThisYear = Calendar.current.isDate(day.date, equalTo: .now, toGranularity: .year)
        return isThisYear
            ? day.date.formatted(.dateTime.month(.abbreviated).day())
            : day.date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var verticalRule: some View {
        Rectangle().fill(Color.hairline).frame(width: 1)
    }

    /// One cell: a bold number over its label.
    private struct Stat: View {
        let value: String
        let label: String

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(value)
                    .font(.metric(.title3))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.m)
            .padding(.horizontal, Spacing.m)
            .accessibilityElement(children: .combine)
        }
    }
}

/// A black ring filling on a light track as the plan goes by, with the
/// weeks to go inside.
private struct PlanRing: View {
    let progress: Double
    let weeksToGo: Int

    private let size: CGFloat = 104
    private let lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress)
            VStack(spacing: 0) {
                Text("\(weeksToGo)")
                    .font(.metric(.title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(weeksToGo == 1 ? "week to go" : "weeks to go")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, lineWidth + Spacing.xs)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plan progress")
        .accessibilityValue(weeksToGo == 1 ? "1 week to go" : "\(weeksToGo) weeks to go")
    }
}
