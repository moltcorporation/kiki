import ActivityKit
import Foundation

/// Live Activity for an in-progress run (Lock Screen + Dynamic Island).
struct RunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Start of the timer, shifted forward by paused time so
        /// `Text(timerInterval:)` shows moving time without updates.
        var timerStart: Date
        /// Frozen elapsed seconds while paused.
        var pausedElapsed: Double?
        var distanceM: Double
        /// Recent pace in seconds per km.
        var paceSPerKm: Double?

        var isPaused: Bool { pausedElapsed != nil }
    }

    var workoutTitle: String
    var usesMiles: Bool
}

extension RunActivityAttributes {
    func distanceText(_ meters: Double) -> String {
        let value = usesMiles ? meters / 1609.344 : meters / 1000
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    var distanceUnit: String { usesMiles ? "mi" : "km" }

    func paceText(_ secondsPerKm: Double?) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else { return "–:––" }
        let seconds = Int((usesMiles ? secondsPerKm * 1.609344 : secondsPerKm).rounded())
        guard seconds < 60 * 60 else { return "–:––" }
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    static func elapsedText(_ seconds: Double) -> String {
        let s = Int(seconds)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}
