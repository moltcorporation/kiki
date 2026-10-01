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
                        PlanProgressCard(plan: plan, units: units)
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

/// The top of the Plan tab: where the runner stands, at a glance. Runs and
/// distance done against the whole plan, the current week, and every week
/// as a bar (height = planned distance, black = done) so they see the
/// build-up and where they are in it.
struct PlanProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units

    var body: some View {
        let workouts = store.workouts.filter { !$0.isRest }
        let runsDone = workouts.filter { $0.status == .completed }.count
        let plannedM = Double(workouts.compactMap(\.distanceM).reduce(0, +))
        let doneM = store.runs
            .filter { Day($0.startedAt) >= plan.startDate && Day($0.startedAt) <= plan.raceDate }
            .reduce(0) { $0 + $1.distanceM }
        let week = store.currentWeekNumber ?? 0
        let total = max(store.totalWeeks, 1)

        Card {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Your progress")
                    .font(.eyebrow)
                    .foregroundStyle(.muted)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    MetricView(value: "\(runsDone)", label: "of \(workouts.count) runs", style: .title2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MetricView(value: Format.distanceNumber(doneM, units), label: "of \(Format.distance(plannedM, units, decimals: 0))", style: .title2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MetricView(value: "\(min(week, total))", label: "of \(total) weeks", style: .title2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: Spacing.s) {
                    WeekBars(weeks: store.weeks, currentWeek: week)
                    HStack {
                        Text("Start")
                        Spacer()
                        Text(Plan.goalDate(plan.raceDate))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.muted)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your progress: \(runsDone) of \(workouts.count) runs done, \(Format.distance(doneM, units)) of \(Format.distance(plannedM, units, decimals: 0)), week \(min(week, total)) of \(total)")
    }
}

/// One bar per week: height is the week's planned distance, the black fill
/// is what's done, and the current week's bar is darker.
private struct WeekBars: View {
    let weeks: [(week: Int, workouts: [Workout])]
    let currentWeek: Int
    private let height: CGFloat = 56

    var body: some View {
        let totals = weeks.map { week in
            let runs = week.workouts.filter { !$0.isRest }
            let planned = Double(runs.compactMap(\.distanceM).reduce(0, +))
            let done = Double(runs.filter { $0.status == .completed }.compactMap(\.distanceM).reduce(0, +))
            return (week: week.week, planned: planned, done: done)
        }
        let peak = max(totals.map(\.planned).max() ?? 1, 1)

        HStack(alignment: .bottom, spacing: Spacing.xs) {
            ForEach(totals, id: \.week) { week in
                let barHeight = max(Spacing.xs, height * week.planned / peak)
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(week.week == currentWeek ? Color.ink.opacity(0.3) : Color.track)
                    Capsule()
                        .fill(Color.ink)
                        .frame(height: week.planned > 0 ? barHeight * min(week.done / week.planned, 1) : 0)
                }
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}
