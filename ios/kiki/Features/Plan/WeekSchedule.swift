import SwiftUI

/// One week of the plan as a schedule, like a calendar's list view: every
/// day is an equal-height row split by hairlines, the date on the left and
/// the day's workout as a simple event block (accent bar, title, amount).
/// Done workouts lose the block and are struck through; rest days are just
/// the word. Only the block is interactive: tap to open the workout, and
/// (with `onMove`) press and hold to drag an upcoming workout to another day.
struct WeekSchedule: View {
    let workouts: [Workout]
    let units: Units
    /// Off where there's nowhere to go (onboarding, the adjust sheet).
    var isNavigable = true
    /// Called when a workout is dropped on another day. Nil turns dragging
    /// off (Home, onboarding).
    var onMove: ((_ workoutID: UUID, _ day: Day) -> Void)?

    var body: some View {
        ListCard(dividerInset: RowMetrics.horizontalPadding, verticalPadding: Spacing.s) {
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

    static let height: CGFloat = 60

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
        .padding(.horizontal, RowMetrics.horizontalPadding)
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
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .accessibilityLabel("\(workout.date.date.formatted(.dateTime.weekday(.wide))), rest")
        } else if isNavigable {
            let link = NavigationLink(value: workout) {
                WorkoutEvent(workout: workout, units: units)
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

/// The date column: weekday over the day number. Today's number sits in an
/// ink circle, like a calendar.
private struct DayLabel: View {
    let day: Day

    var body: some View {
        let isToday = day == .today
        VStack(spacing: Spacing.xs) {
            Text(Format.weekday(day, style: .abbreviated).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? Color.ink : Color.muted)
            Text("\(day.day)")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.paper : Color.ink)
                .frame(width: 26, height: 26)
                .background(isToday ? Color.ink : Color.clear, in: .circle)
        }
        .frame(width: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
    }
}

/// A workout as a calendar event: a gray block with an ink accent bar, the
/// title, and how much on the right. Done: no block, gray, struck through.
/// Skipped: the same, with "Skipped" in place of the amount.
private struct WorkoutEvent: View {
    let workout: Workout
    let units: Units

    var body: some View {
        let isPlanned = workout.status == .planned
        HStack(spacing: Spacing.s) {
            switch workout.status {
            case .planned:
                Capsule()
                    .fill(Color.ink)
                    .frame(width: 3, height: 20)
            case .completed, .skipped:
                EmptyView()
            }
            Text(workout.title)
                .font(.subheadline.weight(isPlanned ? .semibold : .regular))
                .strikethrough(!isPlanned)
                .lineLimit(1)
            Spacer(minLength: Spacing.s)
            Text(workout.status == .skipped ? "Skipped" : amount ?? "")
                .font(.subheadline)
                .foregroundStyle(.muted)
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(isPlanned ? Color.ink : Color.muted)
        .padding(.horizontal, isPlanned ? Spacing.s : 0)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(isPlanned ? Color.wash : Color.clear, in: .rect(cornerRadius: Radius.inner))
        .accessibilityValue(workout.status == .completed ? "Done" : workout.status == .skipped ? "Skipped" : "")
    }

    /// Just how much, since the title already says what kind of run.
    private var amount: String? {
        if let meters = workout.distanceM { return Format.distance(Double(meters), units) }
        if let seconds = workout.durationS { return Format.minutes(seconds) }
        return nil
    }
}
