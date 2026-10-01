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
                        PlanHeader(plan: plan)
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
        let done = workouts.filter { $0.status == .completed }.count
        let runs = workouts.filter { !$0.isRest }.count
        return "\(done)/\(runs) · \(Format.distance(Double(planned), units, decimals: 0))"
    }
}

struct PlanHeader: View {
    let plan: Plan

    var body: some View {
        let days = Day.today.days(until: plan.raceDate)
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(plan.title ?? plan.displayName).font(.cardTitle)
                HStack(spacing: Spacing.xl) {
                    Label(Format.shortDate(plan.raceDate), systemImage: "flag.checkered")
                    if days > 0 { Label("\(days) days", systemImage: "hourglass") }
                    if let predicted = plan.predictedTimeS {
                        Label(Format.duration(predicted), systemImage: "stopwatch")
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.muted)
                if let summary = plan.summary {
                    Text(summary).font(.detail).foregroundStyle(.muted).lineLimit(3)
                }
            }
        }
    }
}
