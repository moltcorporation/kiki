import SwiftUI

/// The plan as a month calendar, for runners who prefer one: a legend, then
/// one card with month arrows, Monday-first day circles (done = Volt, today
/// = ink, run day = outline, rest = plain) and the selected day's workout
/// in a footer (tap a day to pick it; the footer opens the workout).
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
        VStack(alignment: .leading, spacing: Spacing.m) {
            legend
            VStack(spacing: 0) {
                VStack(spacing: Spacing.m) {
                    header
                    grid(byDay)
                }
                .padding(.horizontal, Spacing.m)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.l)
                if let workout = byDay[selected] {
                    // A straight-topped strip: a hairline, then the day on
                    // the page color; only the card's bottom corners round it.
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                        SelectedDay(workout: workout, units: units)
                    }
                    .background(Color.canvas)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: Radius.card))
            .elevatedCard()
        }
        .onAppear {
            // Start on this month, or the plan's first month if it hasn't begun.
            let today = Day.today
            month = min(max(today.firstOfMonth, firstMonth), lastMonth)
            if byDay[today] == nil, let first = workouts.map(\.date).min() { selected = first }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            arrow("chevron.left", label: "Previous month", isEnabled: month > firstMonth) { month = month.addingMonths(-1) }
            Spacer()
            Text(month.date.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
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

    /// Plain rows, not a lazy grid: the month is always fully visible, and
    /// a lazy grid inside the scrolling page mis-measures after a push and
    /// pop, shrinking the card.
    private func grid(_ byDay: [Day: Workout]) -> some View {
        let days = monthDays
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        return VStack(spacing: Spacing.xs) {
            HStack(spacing: 0) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.muted)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
            ForEach(weeks, id: \.first) { week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
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
        .padding(.horizontal, Spacing.xxs)
        .accessibilityHidden(true)
    }

    private func legendItem(_ title: LocalizedStringKey, @ViewBuilder dot: () -> some View) -> some View {
        HStack(spacing: Spacing.xs) {
            dot().frame(width: 12, height: 12)
            Text(title)
        }
    }
}

/// The card's footer: the selected day ("THU" over "1"), its workout and
/// "Today · 2 mi", opening the workout (rest days just say Rest).
private struct SelectedDay: View {
    let workout: Workout
    let units: Units
    /// One fixed height for every day, so the card never changes size as
    /// you pick days (it still grows with Dynamic Type).
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    var body: some View {
        // One structure for every day (rest just can't be opened), so the
        // footer is exactly the same size whichever day is picked.
        NavigationLink(value: workout) { content }
            .buttonStyle(.plain)
            .disabled(workout.isRest)
    }

    private var content: some View {
        HStack(spacing: Spacing.l) {
            VStack(spacing: 0) {
                Text(workout.date.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.muted)
                Text("\(workout.date.day)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(minWidth: 32)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(workout.isRest ? "Rest" : workout.title)
                    .font(.body.weight(.semibold))
                if let detail {
                    Text(detail).font(.detail).foregroundStyle(.muted)
                }
            }
            Spacer(minLength: Spacing.s)
            if !workout.isRest { RowChevron() }
        }
        .frame(height: height)
        .foregroundStyle(.ink)
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    /// "Today · 2 mi", "2 mi", "Done · 2 mi", or "Recovery day". Always a
    /// line, so the card keeps its height from day to day.
    private var detail: String? {
        let amount = workout.isRest ? "Recovery day" : workout.distanceM.map { Format.distance(Double($0), units) }
            ?? workout.durationS.map { Format.minutes($0) }
        let when: String? = workout.status == .completed ? "Done" : (workout.date == .today ? "Today" : nil)
        let parts = [when, amount].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// One day: its number in a circle styled by status. Days outside the plan
/// or the month are gray; the selected day sits in a black-outlined square.
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
                .frame(width: 34, height: 34)
                .background { background }
                .padding(Spacing.xs)
                .background {
                    // Selected: a black outline on a gray square, clearly
                    // apart from the round today / run-day markers.
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.inner)
                            .fill(Color.wash)
                            .overlay(RoundedRectangle(cornerRadius: Radius.inner).strokeBorder(Color.ink, lineWidth: 1.5))
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
