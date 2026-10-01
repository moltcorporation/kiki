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

/// The top of the Plan tab: three numbers, side by side. Distance run so
/// far (it feels like an accomplishment), weeks completed, and average
/// pace across the plan's runs.
struct PlanProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units

    var body: some View {
        let runs = store.runs.filter { Day($0.startedAt) >= plan.startDate && Day($0.startedAt) <= plan.raceDate }
        let distanceM = runs.reduce(0) { $0 + $1.distanceM }
        let timedRuns = runs.filter { $0.durationS > 0 && $0.distanceM > 0 }
        let timedM = timedRuns.reduce(0) { $0 + $1.distanceM }
        let timedS = Double(timedRuns.reduce(0) { $0 + $1.durationS })
        let averagePace = timedM > 0 ? timedS / (timedM / 1000) : nil
        let total = max(store.totalWeeks, 1)
        // Weeks fully behind the runner (all of them once the plan is over).
        let weeksDone = Day.today > plan.raceDate ? total : max((store.currentWeekNumber ?? 1) - 1, 0)

        Card(padding: Spacing.l) {
            HStack(spacing: 0) {
                Stat(value: Format.distanceNumber(distanceM, units), suffix: nil,
                     label: units == .mi ? "Miles run" : "Km run")
                divider
                Stat(value: "\(min(weeksDone, total))", suffix: "/\(total)", label: "Weeks completed")
                divider
                Stat(value: averagePace.map { Format.pace($0, units, withUnit: false) } ?? "–:––",
                     suffix: "/\(units.rawValue)", label: "Avg pace")
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(width: 1, height: 40)
    }

    /// A big number (with an optional quieter suffix) over its label.
    private struct Stat: View {
        let value: String
        let suffix: String?
        let label: LocalizedStringKey

        var body: some View {
            VStack(spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(value).font(.metric(.title2))
                    if let suffix {
                        Text(suffix)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.muted)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}
