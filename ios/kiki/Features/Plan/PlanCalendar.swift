import SwiftUI

/// The plan as a month calendar, for runners who prefer one: a card with
/// month arrows, Monday-first day circles (done = Volt, today = ink, run
/// day = outline, rest = plain), a legend, and the selected day's workout
/// below (tap a day to pick it).
struct PlanCalendar: View {
    let workouts: [Workout]
    let units: Units

    @State private var month: Day = Day.today.firstOfMonth
    @State private var selected: Day = .today

    private var byDay: [Day: Workout] {
        Dictionary(workouts.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var firstMonth: Day { (workouts.map(\.date).min() ?? .today).firstOfMonth }
    private var lastMonth: Day { (workouts.map(\.date).max() ?? .today).firstOfMonth }

    var body: some View {
        let byDay = self.byDay
        VStack(alignment: .leading, spacing: Spacing.l) {
            Card {
                VStack(spacing: Spacing.l) {
                    header(byDay)
                    grid(byDay)
                }
            }
            legend
            if let workout = byDay[selected] {
                WeekSchedule(workouts: [workout], units: units)
            }
        }
        .onAppear {
            // Start on this month, or the plan's first month if it hasn't begun.
            let today = Day.today
            month = min(max(today.firstOfMonth, firstMonth), lastMonth)
            if byDay[today] == nil, let first = workouts.map(\.date).min() { selected = first }
        }
    }

    // MARK: Header

    private func header(_ byDay: [Day: Workout]) -> some View {
        let days = monthDays
        let inMonth = days.compactMap { byDay[$0] }
        let weeks = Set(inMonth.map(\.week))
        let runs = inMonth.filter { !$0.isRest }.count
        return HStack {
            arrow("chevron.left", label: "Previous month", isEnabled: month > firstMonth) { month = month.addingMonths(-1) }
            Spacer()
            VStack(spacing: Spacing.xxs) {
                Text(month.date.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                if let low = weeks.min(), let high = weeks.max() {
                    Text("\(low == high ? "Week \(low)" : "Weeks \(low)–\(high)") · \(runs) \(runs == 1 ? "run" : "runs")")
                        .font(.caption)
                        .foregroundStyle(.muted)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            arrow("chevron.right", label: "Next month", isEnabled: month < lastMonth) { month = month.addingMonths(1) }
        }
    }

    private func arrow(_ symbol: String, label: LocalizedStringKey, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? Color.ink : Color.muted.opacity(0.4))
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.haptic)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    // MARK: Grid

    /// Monday-first weeks covering the month, padded with neighbors.
    private var monthDays: [Day] {
        let start = month.mondayOfWeek
        let nextMonth = month.addingMonths(1)
        var days: [Day] = []
        var day = start
        while day < nextMonth || days.count % 7 != 0 {
            days.append(day)
            day = day.adding(days: 1)
        }
        return days
    }

    private func grid(_ byDay: [Day: Workout]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: Spacing.s) {
            ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { index in
                Text(["M", "T", "W", "T", "F", "S", "S"][index])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.muted)
                    .accessibilityHidden(true)
            }
            ForEach(monthDays, id: \.self) { day in
                DayCell(
                    day: day,
                    workout: byDay[day],
                    isInMonth: day.month == month.month,
                    isSelected: day == selected
                ) {
                    Haptics.select()
                    selected = day
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: Spacing.l) {
            legendItem("Done") { Circle().fill(Color.highlight) }
            legendItem("Today") { Circle().fill(Color.ink) }
            legendItem("Run day") { Circle().strokeBorder(Color.ink, lineWidth: 1.5) }
        }
        .font(.caption)
        .foregroundStyle(.muted)
        .padding(.horizontal, Spacing.xs)
        .accessibilityHidden(true)
    }

    private func legendItem(_ title: LocalizedStringKey, @ViewBuilder dot: () -> some View) -> some View {
        HStack(spacing: Spacing.xs) {
            dot().frame(width: 12, height: 12)
            Text(title)
        }
    }
}

/// One day: its number in a circle styled by status. Days outside the plan
/// or the month are gray; the selected day gets a soft ring.
private struct DayCell: View {
    let day: Day
    let workout: Workout?
    let isInMonth: Bool
    let isSelected: Bool
    let action: () -> Void

    private var isToday: Bool { day == .today }
    private var isRun: Bool { workout.map { !$0.isRest } ?? false }
    private var isDone: Bool { workout?.status == .completed }

    var body: some View {
        Button(action: action) {
            Text("\(day.day)")
                .font(.subheadline.weight(isRun || isToday ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(foreground)
                .frame(width: 38, height: 38)
                .background { background }
                .overlay {
                    if isSelected && !isToday {
                        Circle().strokeBorder(Color.muted.opacity(0.5), lineWidth: 1).padding(-3)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(workout == nil)
        .opacity(isInMonth ? 1 : 0.35)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        if isToday { return .paper }
        if isDone { return .onHighlight }
        if isRun { return .ink }
        return .muted
    }

    @ViewBuilder
    private var background: some View {
        if isToday {
            Circle().fill(Color.ink)
        } else if isDone {
            Circle().fill(Color.highlight)
        } else if isRun {
            Circle().strokeBorder(Color.ink, lineWidth: 1.5)
        }
    }

    private var accessibilityText: String {
        let date = day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        guard let workout else { return date }
        let status = isDone ? "done" : (workout.isRest ? "rest" : "run day")
        return "\(date), \(workout.title), \(status)"
    }
}

extension Day {
    var firstOfMonth: Day { Day(year: year, month: month, day: 1) }

    func addingMonths(_ months: Int) -> Day {
        let total = year * 12 + (month - 1) + months
        return Day(year: total / 12, month: total % 12 + 1, day: 1)
    }
}
