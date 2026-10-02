import SwiftUI

/// The whole plan: the progress card, past weeks collapsed under
/// "Completed", then this week and the weeks ahead, each a title over its
/// schedule (`WeekSchedule`). The current week is near the top, so there's
/// no scrolling to find it.
struct PlanView: View {
    @Environment(TrainingStore.self) private var store
    @State private var path: [Workout] = []
    /// Fires the confetti when the finish line scrolls into view.
    @State private var celebrations = 0
    /// Shown briefly after a drop until moving workouts is wired up.
    @State private var moveNotice = false
    /// The list is the default every time; the calendar is for runners who
    /// prefer one.
    @State private var showsCalendar = false
    @State private var showsShare = false

    /// A workout was dropped on another day. The UI is ready; saving the
    /// move needs the API, so for now this only says it's coming.
    /// TODO: call the store to swap the workout's date with `day`'s.
    private func moveWorkout(_ id: UUID, to day: Day) {
        Analytics.track("workout_move_attempted")
        moveNotice = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            moveNotice = false
        }
    }

    /// "This week" or "Next week", so it's clear where you are as you scroll.
    private func weekEyebrow(_ workouts: [Workout]) -> String? {
        guard let first = workouts.map(\.date).min() else { return nil }
        let thisMonday = Day.today.mondayOfWeek
        switch first.mondayOfWeek {
        case thisMonday: return "This week"
        case thisMonday.adding(days: 7): return "Next week"
        default: return nil
        }
    }

    /// The week's planned distance ("6.5 mi"). Weeks after next add their
    /// dates ("Oct 19 – 25 · 6.5 mi") so they're easy to place; this week
    /// and next week don't need them.
    private func weekDetail(_ workouts: [Workout], units: Units) -> String {
        let meters = workouts.filter { !$0.isRest }.compactMap(\.distanceM).reduce(0, +)
        let distance = Format.distance(Double(meters), units)
        let days = workouts.map(\.date)
        guard weekEyebrow(workouts) == nil, let first = days.min(), let last = days.max() else { return distance }
        return "\(PlanPDF.weekRange(first, last)) · \(distance)"
    }

    private var headerButtons: AnyView? {
        guard store.plan != nil else { return nil }
        return AnyView(HStack(spacing: Spacing.s) {
            HeaderButton(showsCalendar ? "Show as list" : "Show as calendar",
                         systemImage: showsCalendar ? "list.bullet" : "calendar") {
                withAnimation(.snappy) { showsCalendar.toggle() }
                Analytics.track("plan_view_toggled", ["view": showsCalendar ? "calendar" : "list"])
            }
            HeaderButton("Share plan", systemImage: "square.and.arrow.up") { showsShare = true }
        })
    }

    /// Weeks entirely before this one, shown collapsed under "Completed".
    private var pastWeeks: [(week: Int, workouts: [Workout])] {
        let monday = Day.today.mondayOfWeek
        return store.weeks.filter { week in week.workouts.allSatisfy { $0.date < monday } }
    }

    var body: some View {
        let units = store.units
        let past = pastWeeks
        let pastNumbers = Set(past.map(\.week))
        NavigationStack(path: $path) {
            Group {
                TabPage("Your plan", accessory: headerButtons) {
                    if let plan = store.plan {
                        ProgressCard(plan: plan, units: units)
                    }
                    if showsCalendar {
                        PlanCalendar(workouts: store.workouts, units: units)
                            .transition(.opacity)
                    } else {
                    if !past.isEmpty {
                        CompletedWeeks(weeks: past, units: units)
                    }
                    ForEach(store.weeks.filter { !pastNumbers.contains($0.week) }, id: \.week) { week, workouts in
                        PageSection("Week \(week)", eyebrow: weekEyebrow(workouts), detail: weekDetail(workouts, units: units)) {
                            WeekSchedule(workouts: workouts, units: units, onMove: moveWorkout)
                        }
                        .id(week)
                    }
                    if store.plan != nil, !store.weeks.isEmpty {
                        FinishLine()
                            .onScrollVisibilityChange(threshold: 0.8) { visible in
                                guard visible else { return }
                                Haptics.success()
                                celebrations += 1
                            }
                    }
                    }
                }
                .refreshable { await store.refresh() }
                .hidesTabBar(!path.isEmpty)

            }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workoutID: $0.id) }
        }
        .overlay { ConfettiBurst(trigger: celebrations).ignoresSafeArea() }
        .overlay(alignment: .bottom) {
            if moveNotice {
                Label("Moving workouts is coming soon", systemImage: "calendar.badge.clock")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                    .glassEffect()
                    .padding(.bottom, Spacing.s)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: moveNotice)
        .sheet(isPresented: $showsShare) {
            if let plan = store.plan {
                SharePlanSheet(plan: plan, workouts: store.workouts, units: store.units)
            }
        }
        .onAppear { Analytics.screen("Plan") }
    }
}

/// The top of the Plan tab: progress and goal together. A ring that fills
/// day by day through the plan (days to go inside), beside the goal and its date,
/// then a hairline and two stats: distance run and the longest run.
struct ProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units

    var body: some View {
        let runs = store.runs.filter { Day($0.startedAt) >= plan.startDate && Day($0.startedAt) <= plan.raceDate }
        let distanceM = runs.reduce(0) { $0 + $1.distanceM }
        let longestM = runs.map(\.distanceM).max() ?? 0
        let timeline = PlanTimeline(plan: plan, store: store)

        Card(padding: Spacing.l) {
            HStack(spacing: Spacing.xxl) {
                PlanRing(timeline: timeline)

                VStack(alignment: .leading, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(plan.displayName)
                            .font(.rowTitle)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Plan.goalDate(timeline.endDate))
                            .font(.detail)
                            .foregroundStyle(.muted)
                    }
                    .accessibilityElement(children: .combine)

                    Rectangle().fill(Color.hairline).frame(height: 1)

                    HStack(spacing: Spacing.m) {
                        Stat(value: Format.distanceNumber(distanceM, units), label: units == .mi ? "Miles run" : "Km run")
                        Rectangle().fill(Color.hairline).frame(width: 1, height: 32)
                        Stat(value: Format.distanceNumber(longestM, units), unit: units.rawValue, label: "Longest run")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// A bold number over its label.
    private struct Stat: View {
        let value: String
        /// A small unit after the number ("mi").
        var unit: String?
        let label: String

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                (Text(value) + Text(unit.map { " \($0)" } ?? "").font(.subheadline.weight(.semibold)))
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
/// days to go inside (the number, and a small label under it). Full with
/// "Today" on the goal day, and a checkmark once it has passed.
private struct PlanRing: View {
    let timeline: PlanTimeline

    private let size: CGFloat = 92
    private let lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            ProgressRing(progress: timeline.progress, lineWidth: lineWidth)
            Group {
                switch timeline.phase {
                case .underway:
                    VStack(spacing: 0) {
                        Text("\(timeline.daysLeft)")
                            .font(.metric(.title))
                        Text(timeline.daysLeft == 1 ? "day to go" : "days to go")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.muted)
                    }
                case .goalDay:
                    Text("Today")
                        .font(.metric(.title3))
                case .finished:
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: "checkmark")
                            .font(.title2.weight(.bold))
                        Text("Finished")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.muted)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, lineWidth + Spacing.s)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plan progress")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        switch timeline.phase {
        case .underway: timeline.daysLeft == 1 ? "1 day to go" : "\(timeline.daysLeft) days to go"
        case .goalDay: "Today"
        case .finished: "Finished"
        }
    }
}

/// The end of the plan, under the last week: a small celebration for
/// runners who scroll all the way down (the confetti fires as it appears).
private struct FinishLine: View {

    var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "flag.checkered")
                .font(.title2)
                .padding(.bottom, Spacing.xs)
                .accessibilityHidden(true)
            Text("The finish line")
                .font(.cardTitle)
            Text("You've got this!")
                .font(.detail)
                .foregroundStyle(.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.ink)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.l)
        .padding(.bottom, Spacing.xxxl)
        .accessibilityElement(children: .combine)
    }
}

/// Past weeks, folded away so this week stays near the top: a small
/// "Completed" label over one summary card ("Weeks 1–10", the dates, runs
/// done) that opens like an accordion into a row per week, each of which
/// opens to its schedule. A single past week shows as its own row.
private struct CompletedWeeks: View {
    let weeks: [(week: Int, workouts: [Workout])]
    let units: Units

    @State private var isOpen = false
    @State private var expanded: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Completed")
                .font(.eyebrow)
                .foregroundStyle(.muted)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                if weeks.count > 1 {
                    Button {
                        withAnimation(.smooth(duration: 0.35)) { isOpen.toggle() }
                    } label: {
                        SummaryRow(
                            title: "Weeks \(weeks.first?.week ?? 1)–\(weeks.last?.week ?? 1)",
                            workouts: weeks.flatMap(\.workouts),
                            isExpanded: isOpen
                        )
                    }
                    .buttonStyle(.haptic)
                }
                if isOpen || weeks.count == 1 {
                    ForEach(weeks, id: \.week) { week, workouts in
                        let isExpanded = expanded.contains(week)
                        if weeks.count > 1 || week != weeks.first?.week {
                            Divider().padding(.horizontal, RowMetrics.horizontalPadding)
                        }
                        Button {
                            withAnimation(.smooth(duration: 0.35)) {
                                if isExpanded { expanded.remove(week) } else { expanded.insert(week) }
                            }
                        } label: {
                            SummaryRow(title: "Week \(week)", workouts: workouts, isExpanded: isExpanded)
                        }
                        .buttonStyle(.haptic)
                        if isExpanded {
                            Divider().padding(.horizontal, RowMetrics.horizontalPadding)
                            WeekSchedule(workouts: workouts, units: units, isCard: false)
                                .transition(.opacity)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .background(Color.surface)
            .clipShape(.rect(cornerRadius: Radius.card))
            .elevation(.card)
        }
    }
}

/// A completed stretch: a Volt check when every run was done (else
/// "2/3"), the title over its dates, runs done, and a chevron.
private struct SummaryRow: View {
    let title: String
    let workouts: [Workout]
    let isExpanded: Bool

    var body: some View {
        let runs = workouts.filter { !$0.isRest }
        let done = runs.filter { $0.status == .completed }.count
        // The multi-week summary always shows a check: it's the finished
        // stretch. Single weeks show a check only when every run was done.
        let weeks = Set(workouts.map(\.week)).count
        let allDone = weeks > 1 || (done == runs.count && !runs.isEmpty)
        HStack(spacing: Spacing.m) {
            ZStack {
                Circle().fill(allDone ? Color.highlight : Color.wash)
                if allDone {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.onHighlight)
                } else {
                    Text("\(done)/\(runs.count)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                }
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.rowTitle)
                Text(dateRange).font(.detail).foregroundStyle(.muted)
            }
            Spacer(minLength: Spacing.s)
            Text("\(done) of \(runs.count) runs")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.muted)
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .accessibilityHidden(true)
        }
        .foregroundStyle(.ink)
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint("Shows the workouts")
    }

    /// "Sep 28 – Oct 4", "Oct 5 – 11", or "Jul 20 – Sep 27" for many weeks.
    private var dateRange: String {
        guard let first = workouts.map(\.date).min(), let last = workouts.map(\.date).max() else { return "" }
        let monday = first.mondayOfWeek
        let sunday = last.mondayOfWeek.adding(days: 6)
        let sameMonth = Calendar.current.isDate(monday.date, equalTo: sunday.date, toGranularity: .month)
        return "\(monday.date.formatted(.dateTime.month(.abbreviated).day())) – "
            + (sameMonth ? "\(sunday.day)" : sunday.date.formatted(.dateTime.month(.abbreviated).day()))
    }
}
