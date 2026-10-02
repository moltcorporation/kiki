import SwiftUI

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
