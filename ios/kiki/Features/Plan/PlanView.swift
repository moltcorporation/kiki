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

/// The top of the Plan tab: a ring that fills as the runner works through
/// the plan, and four stats beside it in a 2×2 grid split by hairlines:
/// distance run, longest run, weeks to go and average pace.
struct ProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units

    var body: some View {
        let runs = store.runs.filter { Day($0.startedAt) >= plan.startDate && Day($0.startedAt) <= plan.raceDate }
        let distanceM = runs.reduce(0) { $0 + $1.distanceM }
        let longestM = runs.map(\.distanceM).max() ?? 0
        let timedRuns = runs.filter { $0.durationS > 0 && $0.distanceM > 0 }
        let timedM = timedRuns.reduce(0) { $0 + $1.distanceM }
        let timedS = Double(timedRuns.reduce(0) { $0 + $1.durationS })
        let averagePace = timedM > 0 ? timedS / (timedM / 1000) : nil
        // Same count as the goal ("10 weeks to go").
        let weeksToGo = max(0, Day.today.days(until: plan.raceDate) / 7)
        // How far through the plan: the same measure as the goal card's bar.
        let total = max(store.totalWeeks, 1)
        let week = min(store.currentWeekNumber ?? (Day.today > plan.raceDate ? total : 0), total)
        let unit = units == .mi ? "mi" : "km"

        Card {
            HStack(spacing: Spacing.xl) {
                PlanRing(week: week, total: total)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Stat(value: Format.distanceNumber(distanceM, units), label: units == .mi ? "Miles run" : "Km run")
                        verticalRule
                        Stat(value: Format.distanceNumber(longestM, units), label: "Longest run")
                    }
                    Rectangle().fill(Color.hairline).frame(height: 1)
                    HStack(spacing: 0) {
                        Stat(value: "\(weeksToGo)", label: weeksToGo == 1 ? "Week to go" : "Weeks to go")
                        verticalRule
                        Stat(value: averagePace.map { Format.pace($0, units, withUnit: false) } ?? "–:––",
                             label: "Avg. pace /\(unit)")
                    }
                }
            }
        }
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

/// A black ring filling on a light track as the weeks go by.
private struct PlanRing: View {
    let week: Int
    let total: Int

    private let size: CGFloat = 96
    private let lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(week) / CGFloat(total))
                .stroke(Color.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: week)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plan progress")
        .accessibilityValue("Week \(max(week, 1)) of \(total)")
    }
}
