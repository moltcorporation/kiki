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

/// The top of the Plan tab: two numbers, side by side. Miles run so far
/// (it feels like an accomplishment) and the week they're on.
struct PlanProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units

    var body: some View {
        let doneM = store.runs
            .filter { Day($0.startedAt) >= plan.startDate && Day($0.startedAt) <= plan.raceDate }
            .reduce(0) { $0 + $1.distanceM }
        let total = max(store.totalWeeks, 1)
        let week = max(min(store.currentWeekNumber ?? 1, total), 1)

        Card(padding: Spacing.l) {
            HStack(spacing: 0) {
                Stat(value: Format.distanceNumber(doneM, units), suffix: nil, label: units == .mi ? "Miles run" : "Kilometers run")
                Rectangle()
                    .fill(Color.hairline)
                    .frame(width: 1, height: 40)
                Stat(value: "\(week)", suffix: "of \(total)", label: "Week")
            }
        }
    }

    /// A big number (with an optional quieter suffix) over its label.
    private struct Stat: View {
        let value: String
        let suffix: String?
        let label: LocalizedStringKey

        var body: some View {
            VStack(spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(value).font(.metric(.title))
                    if let suffix {
                        Text(suffix)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.muted)
                    }
                }
                Text(label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.muted)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}
