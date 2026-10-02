import SwiftUI

/// One week of the plan as a schedule, like a calendar's list view: every
/// day is an equal-height row split by hairlines, the date on the left and
/// the day's workout as a tile (status circle, title, "2.0 mi · Easy", and a
/// chevron to open it). Today's tile has a thin ink outline. Done workouts get a filled check and are
/// struck through; rest days are just the word. Only the tile is interactive.
struct WeekSchedule: View {
    let workouts: [Workout]
    let units: Units
    /// Off where there's nowhere to go (onboarding, the adjust sheet).
    var isNavigable = true
    /// Called when a workout is dropped on another day. Nil turns dragging
    /// off (Home, onboarding).
    var onMove: ((_ workoutID: UUID, _ day: Day) -> Void)?
    /// Off when the schedule sits inside another card (a completed week).
    var isCard = true

    var body: some View {
        ListCard(dividerInset: Spacing.m, verticalPadding: Spacing.xs, isCard: isCard) {
            ForEach(workouts.sorted { $0.date < $1.date }) { workout in
                DayRow(workout: workout, units: units, isNavigable: isNavigable, onMove: onMove)
            }
        }
    }
}

/// One day: the date column and the day's workout (or "Rest"). The row is
/// a drop target when moving is on; it outlines where a dragged workout
/// would land.
private struct DayRow: View {
    let workout: Workout
    let units: Units
    let isNavigable: Bool
    let onMove: ((UUID, Day) -> Void)?

    @State private var isTargeted = false

    /// Every day is the same height, rest days included, so the hairlines
    /// fall evenly (and rest days stay a full-size drop target).
    static let height: CGFloat = 54

    var body: some View {
        let row = HStack(spacing: Spacing.m) {
            DayLabel(day: workout.date)
            content
                .overlay {
                    if isTargeted {
                        RoundedRectangle(cornerRadius: Radius.inner)
                            .strokeBorder(Color.ink, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .padding(.vertical, -Spacing.xs)
                    }
                }
                .animation(.snappy(duration: 0.15), value: isTargeted)
        }
        .padding(.leading, Spacing.m)
        .padding(.trailing, RowMetrics.horizontalPadding)
        .frame(height: Self.height)

        if let onMove {
            row.dropDestination(for: String.self) { items, _ in
                guard let id = items.first.flatMap(UUID.init(uuidString:)), id != workout.id else { return false }
                Haptics.success()
                onMove(id, workout.date)
                return true
            } isTargeted: { targeted in
                if targeted && !isTargeted { Haptics.select() }
                isTargeted = targeted
            }
        } else {
            row
        }
    }

    @ViewBuilder
    private var content: some View {
        if workout.isRest {
            Text("Rest")
                .font(.subheadline)
                .foregroundStyle(.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("\(workout.date.date.formatted(.dateTime.weekday(.wide))), rest")
        } else if isNavigable {
            let link = NavigationLink(value: workout) {
                WorkoutEvent(workout: workout, units: units, showsChevron: true)
                    .contentShape(.rect(cornerRadius: Radius.inner))
            }
            .buttonStyle(.haptic)
            if onMove != nil, workout.status == .planned {
                link.draggable(workout.id.uuidString) {
                    WorkoutEvent(workout: workout, units: units)
                        .frame(width: 260)
                        .background(Color.surface, in: .rect(cornerRadius: Radius.inner))
                }
            } else {
                link
            }
        } else {
            WorkoutEvent(workout: workout, units: units)
        }
    }
}

/// The date column: weekday over the day number. Past days are gray;
/// today's number sits in an ink circle, like a calendar.
private struct DayLabel: View {
    let day: Day

    var body: some View {
        let isToday = day == .today
        let isPast = day < .today
        VStack(spacing: Spacing.xxs) {
            Text(Format.weekday(day, style: .abbreviated))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isPast ? Color.muted : Color.ink)
            Text("\(day.day)")
                .font(.body.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.paper : isPast ? Color.muted : Color.ink)
                .frame(width: 26, height: 26)
                .background(isToday ? Color.ink : Color.clear, in: .circle)
        }
        .frame(width: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
    }
}

/// A workout tile: a status circle (empty to do, filled check when done),
/// the title over "2.0 mi · Easy", and a chevron when it opens the workout.
private struct WorkoutEvent: View {
    let workout: Workout
    let units: Units
    /// A chevron when tapping the tile opens the workout.
    var showsChevron = false

    var body: some View {
        let isToday = workout.date == .today
        // One line: status, title, and the amount on the right.
        HStack(spacing: Spacing.s + Spacing.xxs) {
            StatusCircle(status: workout.status, isToday: isToday)
            Text(workout.title)
                .font(.subheadline.weight(.semibold))
                // Done and skipped are struck through, so finished days read at a glance.
                .strikethrough(workout.status != .planned)
                .foregroundStyle(workout.status == .planned ? Color.ink : Color.muted)
                .lineLimit(1)
            Spacer(minLength: Spacing.s)
            Text(amount)
                .font(.subheadline)
                .foregroundStyle(.muted)
                .monospacedDigit()
                .lineLimit(1)
            if showsChevron {
                RowChevron()
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        // Today's workout: white with a crisp ink outline, like a calendar's
        // today marker. Other days sit on a soft gray.
        .background(isToday ? Color.surface : Color.wash, in: .rect(cornerRadius: Radius.inner))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: Radius.inner)
                    .strokeBorder(Color.ink, lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(workout.status == .completed ? "Done" : workout.status == .skipped ? "Skipped" : "")
    }

    /// "2 mi", "1.5 mi", "30 min", or "Skipped".
    private var amount: String {
        if workout.status == .skipped { return "Skipped" }
        if let meters = workout.distanceM {
            let number = Format.distanceNumber(Double(meters), units)
            return "\(number.hasSuffix(".0") ? String(number.dropLast(2)) : number) \(units.rawValue)"
        }
        return workout.durationS.map { Format.minutes($0) } ?? ""
    }
}

/// Empty ring to do (ink today), a filled ink check when done, a dash when
/// skipped.
private struct StatusCircle: View {
    let status: Workout.Status
    let isToday: Bool

    var body: some View {
        ZStack {
            switch status {
            case .completed:
                Circle().fill(Color.highlight)
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Color.onHighlight)
            case .skipped:
                Circle().strokeBorder(Color.track, lineWidth: 1.5)
                Image(systemName: "minus")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.muted)
            case .planned:
                Circle().strokeBorder(isToday ? Color.ink : Color.ink.opacity(0.25), lineWidth: isToday ? 2 : 1.5)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}
