import SwiftUI

/// One week of the plan as a schedule: every day is a row, with the date on
/// the left and the day's workout as its own tile on the right. Rest days
/// are a quiet dashed slot. Each workout being a separate tile is what will
/// let runners press and hold to move or edit it later.
struct WeekSchedule: View {
    let workouts: [Workout]
    let units: Units

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(workouts.sorted { $0.date < $1.date }) { workout in
                HStack(spacing: Spacing.m) {
                    DayLabel(day: workout.date)
                    if workout.isRest {
                        RestSlot()
                    } else {
                        NavigationLink(value: workout) {
                            WorkoutTile(workout: workout, units: units)
                        }
                        .buttonStyle(.haptic)
                    }
                }
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
    }
}

/// The date column: weekday over the day number. Today's number sits in an
/// ink circle, like a calendar.
private struct DayLabel: View {
    let day: Day

    static let width: CGFloat = 40

    var body: some View {
        let isToday = day == .today
        VStack(spacing: Spacing.xxs) {
            Text(Format.weekday(day, style: .abbreviated).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? Color.ink : Color.muted)
            Text("\(day.day)")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.paper : Color.ink)
                .frame(width: 30, height: 30)
                .background(isToday ? Color.ink : Color.clear, in: .circle)
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityAddTraits(isToday ? .isSelected : [])
    }
}

/// A workout as a tile: icon, title and how much (distance or time), with
/// a checkmark once done. Skipped workouts fade and strike through.
private struct WorkoutTile: View {
    let workout: Workout
    let units: Units

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: workout.type.symbol)
                .font(.subheadline.weight(.medium))
                .frame(width: 32, height: 32)
                .background(Color.surface, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(workout.title)
                    .font(.rowTitle)
                    .strikethrough(workout.status == .skipped)
                    .lineLimit(1)
                if let amount {
                    Text(amount)
                        .font(.detail)
                        .foregroundStyle(.muted)
                }
            }
            Spacer(minLength: Spacing.s)
            switch workout.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .accessibilityLabel("Done")
            case .skipped:
                Text("Skipped")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.muted)
            case .planned:
                EmptyView()
            }
        }
        .foregroundStyle(.ink)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s + Spacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wash, in: .rect(cornerRadius: Radius.inner))
        .opacity(workout.status == .skipped ? 0.55 : 1)
        .contentShape(.rect(cornerRadius: Radius.inner))
        .accessibilityElement(children: .combine)
    }

    /// Just how much, since the title already says what kind of run.
    private var amount: String? {
        if let meters = workout.distanceM { return Format.distance(Double(meters), units) }
        if let seconds = workout.durationS { return Format.minutes(seconds) }
        return nil
    }
}

/// A rest day: an empty dashed slot, quiet next to the workouts.
private struct RestSlot: View {
    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "moon.zzz")
                .font(.footnote.weight(.medium))
                .accessibilityHidden(true)
            Text("Rest")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.muted)
        .padding(.horizontal, Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.inner)
                .strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }
}
