import SwiftUI

/// The workout type as an outlined glyph in a light circle. One style for
/// every type, so rows read evenly.
struct WorkoutIcon: View {
    let workout: Workout
    var size: RowIcon.Size = .regular

    var body: some View {
        RowIcon(systemName: workout.type.symbol, size: size)
    }
}

/// Done or skipped, on the workout page.
struct StatusBadge: View {
    let status: Workout.Status

    var body: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.ink)
                .accessibilityLabel("Completed")
        case .skipped:
            Text("Skipped").font(.caption.weight(.semibold)).foregroundStyle(.muted)
        case .planned:
            EmptyView()
        }
    }
}

/// The target pace zone for a workout type.
extension WorkoutType {
    var paceZone: PaceZone? {
        switch self {
        case .easy: .easy
        case .recovery: .recovery
        case .long: .long
        case .tempo, .progression: .tempo
        case .intervals, .fartlek, .hills: .interval
        case .racePace, .race: .race
        case .rest, .crossTraining, .runWalk: nil
        }
    }
}

extension PaceZone {
    /// How the pace should feel, in plain words for beginners.
    var effort: String {
        switch self {
        case .easy, .recovery: "Easy. You can chat in full sentences."
        case .long: "Steady and relaxed. Save energy for the finish."
        case .tempo: "Comfortably hard. You can say a few words at a time."
        case .interval: "Hard. Push during each rep, then catch your breath."
        case .race: "Your goal race pace. Practice how it feels."
        }
    }
}
