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
/// as the plan goes by (the current week inside), beside the goal and its date,
/// then a hairline and the two stats that matter most: distance run and
/// average pace.
struct ProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units

    var body: some View {
        let runs = store.runs.filter { Day($0.startedAt) >= plan.startDate && Day($0.startedAt) <= plan.raceDate }
        let distanceM = runs.reduce(0) { $0 + $1.distanceM }
        let timed = runs.filter { $0.durationS > 0 && $0.distanceM > 0 }
        let timedM = timed.reduce(0) { $0 + $1.distanceM }
        let timedS = Double(timed.reduce(0) { $0 + $1.durationS })
        // How far through the plan: the same measure as the goal card's bar.
        let total = max(store.totalWeeks, 1)
        let week = min(store.currentWeekNumber ?? (Day.today > plan.raceDate ? total : 0), total)

        Card(padding: Spacing.l) {
            HStack(spacing: Spacing.xxl) {
                PlanRing(week: max(week, 1), total: total)

                VStack(alignment: .leading, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(plan.displayName)
                            .font(.rowTitle)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Plan.goalDate(plan.raceDate))
                            .font(.detail)
                            .foregroundStyle(.muted)
                    }
                    .accessibilityElement(children: .combine)

                    Rectangle().fill(Color.hairline).frame(height: 1)

                    HStack(spacing: Spacing.m) {
                        Stat(value: Format.distanceNumber(distanceM, units), label: units == .mi ? "Miles run" : "Km run")
                        Rectangle().fill(Color.hairline).frame(width: 1, height: 32)
                        Stat(value: timedM > 0 ? Format.pace(timedS / (timedM / 1000), units, withUnit: false) : "–:––",
                             label: "Avg. pace /\(units.rawValue)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// A bold number over its label.
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
            .accessibilityElement(children: .combine)
        }
    }
}

/// A black ring filling on a light track as the plan goes by, with the
/// current week inside ("1/12") and "Week" underneath.
private struct PlanRing: View {
    let week: Int
    let total: Int

    private let size: CGFloat = 84
    private let lineWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                Circle()
                    .stroke(Color.track, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: CGFloat(week) / CGFloat(max(total, 1)))
                    .stroke(Color.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: week)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(week)")
                        .font(.metric(.title2))
                    Text("/\(total)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.muted)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, lineWidth + Spacing.xs)
            }
            .frame(width: size, height: size)

            Text("Week")
                .font(.caption.weight(.medium))
                .foregroundStyle(.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plan progress")
        .accessibilityValue("Week \(week) of \(total)")
    }
}
