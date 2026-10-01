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

/// The top of the Plan tab: three progress rings (runs, distance, weeks)
/// that fill as the runner works through the plan. Nothing else, so where
/// they stand is clear at a glance.
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
        let total = max(store.totalWeeks, 1)
        let week = min(store.currentWeekNumber ?? 0, total)

        Card {
            HStack(alignment: .top, spacing: 0) {
                ProgressRing(
                    value: "\(runsDone)", target: "of \(workouts.count)", label: "Runs",
                    progress: Double(runsDone) / Double(max(workouts.count, 1)), color: .ringRuns
                )
                ProgressRing(
                    value: Format.distanceNumber(doneM, units, decimals: 0),
                    target: "of \(Format.distanceNumber(plannedM, units, decimals: 0))",
                    label: units == .mi ? "Miles" : "Km",
                    progress: doneM / max(plannedM, 1), color: .ringDistance
                )
                ProgressRing(
                    value: "\(week)", target: "of \(total)", label: "Weeks",
                    progress: Double(week) / Double(total), color: .ringWeeks
                )
            }
        }
    }
}

/// A ring that fills with progress, its number in the middle ("12" over
/// "of 35") and what it counts below.
private struct ProgressRing: View {
    let value: String
    let target: String
    let label: LocalizedStringKey
    let progress: Double
    let color: Color

    private let size: CGFloat = 84
    private let lineWidth: CGFloat = 10

    var body: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: progress)
                VStack(spacing: 0) {
                    Text(value)
                        .font(.metric(.title3))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(target)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, lineWidth + Spacing.xs)
            }
            .frame(width: size, height: size)

            Text(label)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(target)")
    }
}
