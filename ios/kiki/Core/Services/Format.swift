import Foundation

/// Formatting for distances, paces and durations in the runner's units.
enum Format {
    static let metersPerMile = 1609.344

    static func distanceValue(_ meters: Double, _ units: Units) -> Double {
        units == .km ? meters / 1000 : meters / metersPerMile
    }

    static func meters(fromDistance value: Double, _ units: Units) -> Double {
        units == .km ? value * 1000 : value * metersPerMile
    }

    /// "8.0" (value only).
    static func distanceNumber(_ meters: Double, _ units: Units, decimals: Int = 1) -> String {
        distanceValue(meters, units).formatted(.number.precision(.fractionLength(decimals)))
    }

    /// "8.0 km" / "5.0 mi".
    static func distance(_ meters: Double, _ units: Units, decimals: Int = 1) -> String {
        "\(distanceNumber(meters, units, decimals: decimals)) \(units.rawValue)"
    }

    /// Short distances for interval steps: "400 m" / "800 m" or "1.0 mi".
    static func stepDistance(_ meters: Int, _ units: Units) -> String {
        if meters < 1600 || (units == .km && meters < 5000 && meters % 1000 != 0) {
            return "\(meters) m"
        }
        return distance(Double(meters), units)
    }

    /// Pace from seconds per km: "5:30 /km" or "8:51 /mi".
    static func pace(_ secondsPerKm: Double, _ units: Units, withUnit: Bool = true) -> String {
        let seconds = units == .km ? secondsPerKm : secondsPerKm * metersPerMile / 1000
        let total = Int(seconds.rounded())
        let value = "\(total / 60):\(String(format: "%02d", total % 60))"
        return withUnit ? "\(value) /\(units.rawValue)" : value
    }

    static func paceRange(_ range: PaceRange, _ units: Units) -> String {
        "\(pace(Double(range.min), units, withUnit: false))–\(pace(Double(range.max), units))"
    }

    /// "1:05:30" or "45:10".
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// "45 min" / "1 h 15 min".
    static func minutes(_ seconds: Int) -> String {
        let m = Int((Double(seconds) / 60).rounded())
        return m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
    }

    static func workoutSummary(_ workout: Workout, units: Units) -> String {
        if let d = workout.distanceM { return "\(workout.type.label) · \(distance(Double(d), units))" }
        if let s = workout.durationS { return "\(workout.type.label) · \(minutes(s))" }
        return workout.type.label
    }

    /// Primary metric for a workout card: ("8.0", "km") or ("45", "min").
    static func workoutMetric(_ workout: Workout, units: Units) -> (value: String, unit: String)? {
        if let d = workout.distanceM { return (distanceNumber(Double(d), units), units == .km ? "km" : "miles") }
        if let s = workout.durationS { return ("\(Int((Double(s) / 60).rounded()))", "min") }
        return nil
    }

    static func weekday(_ day: Day, style: Date.FormatStyle.Symbol.Weekday = .wide) -> String {
        day.date.formatted(.dateTime.weekday(style))
    }

    static func shortDate(_ day: Day) -> String {
        day.date.formatted(.dateTime.month(.abbreviated).day())
    }
}
