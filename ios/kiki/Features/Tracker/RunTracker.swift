import ActivityKit
import CoreLocation
import Foundation

/// Records a run with GPS: distance, moving time, pace, splits and route,
/// mirrored to a Live Activity. Keeps running in the background.
@Observable
final class RunTracker {
    enum State { case ready, running, paused, finished }

    var isPresented = false
    private(set) var state: State = .ready
    private(set) var workout: Workout?
    private(set) var distanceM: Double = 0
    private(set) var currentPaceSPerKm: Double?
    private(set) var locations: [CLLocation] = []
    private(set) var authorizationDenied = false

    private(set) var startedAt: Date?
    private var activeSince: Date?
    private var accumulated: TimeInterval = 0
    private var elevationGain: Double = 0
    private var splits: [Run.Split] = []
    private var splitStart: (distance: Double, time: TimeInterval) = (0, 0)
    private var segmentBreak = false
    private var units: Units = .km

    private var updatesTask: Task<Void, Never>?
    private var backgroundSession: CLBackgroundActivitySession?
    private var serviceSession: CLServiceSession?
    private var activity: Activity<RunActivityAttributes>?
    private var lastActivityUpdate = Date.distantPast

    /// Moving time in seconds (excludes pauses).
    func elapsed(at date: Date = .now) -> TimeInterval {
        accumulated + (activeSince.map { date.timeIntervalSince($0) } ?? 0)
    }

    var averagePaceSPerKm: Double? {
        distanceM > 50 ? elapsed() / (distanceM / 1000) : nil
    }

    // MARK: Lifecycle

    func start(for workout: Workout?) {
        reset()
        self.workout = workout
        isPresented = true
        // Ask for location permission up front so the run starts instantly.
        serviceSession = CLServiceSession(authorization: .whenInUse, fullAccuracyPurposeKey: "RunTracking")
        authorizationDenied = [.denied, .restricted].contains(CLLocationManager().authorizationStatus)
        Analytics.track("tracker_opened", ["linked_workout": workout != nil])
    }

    func setUnits(_ units: Units) { self.units = units }

    func begin() {
        guard state == .ready else { return }
        startedAt = .now
        activeSince = .now
        state = .running
        backgroundSession = CLBackgroundActivitySession()
        startUpdates()
        startActivity()
        Haptics.success()
        Analytics.track("run_tracking_started")
    }

    func pause() {
        guard state == .running, let since = activeSince else { return }
        accumulated += Date.now.timeIntervalSince(since)
        activeSince = nil
        state = .paused
        currentPaceSPerKm = nil
        Haptics.tap()
        updateActivity(force: true)
    }

    func resume() {
        guard state == .paused else { return }
        activeSince = .now
        // Don't count the distance between the pause and resume points.
        segmentBreak = true
        state = .running
        Haptics.tap()
        updateActivity(force: true)
    }

    /// Stops recording and returns a draft run to review and save.
    func finish() -> Run? {
        if state == .running { pause() }
        state = .finished
        stopUpdates()
        endActivity()
        guard let startedAt, distanceM > 0 else { return nil }

        let duration = Int(elapsed().rounded())
        Analytics.track("run_tracking_finished", ["distance_m": Int(distanceM), "duration_s": duration])
        return Run(
            id: UUID(),
            workoutId: workout?.id,
            source: .kiki,
            startedAt: startedAt,
            distanceM: distanceM,
            durationS: duration,
            elevationGainM: elevationGain > 0 ? elevationGain : nil,
            route: Polyline.encode(simplifiedRoute()),
            splits: splits.isEmpty ? nil : splits
        )
    }

    func discard() {
        stopUpdates()
        endActivity()
        reset()
        isPresented = false
        Analytics.track("run_tracking_discarded")
    }

    func close() {
        reset()
        isPresented = false
    }

    private func reset() {
        stopUpdates()
        state = .ready
        workout = nil
        distanceM = 0
        currentPaceSPerKm = nil
        locations = []
        startedAt = nil
        activeSince = nil
        accumulated = 0
        elevationGain = 0
        splits = []
        splitStart = (0, 0)
        segmentBreak = false
        serviceSession = nil
    }

    // MARK: Location

    private func startUpdates() {
        updatesTask = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    guard let self else { return }
                    if update.authorizationDenied || update.authorizationDeniedGlobally {
                        self.authorizationDenied = true
                    }
                    if let location = update.location { self.ingest(location) }
                }
            } catch {
                Analytics.captureError(error, context: ["step": "location_updates"])
            }
        }
    }

    private func stopUpdates() {
        updatesTask?.cancel()
        updatesTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
    }

    private func ingest(_ location: CLLocation) {
        guard state == .running,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 30,
              location.timestamp.timeIntervalSinceNow > -10
        else {
            return
        }

        if let last = locations.last, !segmentBreak {
            let delta = location.distance(from: last)
            let dt = location.timestamp.timeIntervalSince(last.timestamp)
            // Ignore GPS jumps faster than ~12 m/s (a sub-1:30/km pace).
            guard dt > 0, delta / dt < 12 else { return }
            guard delta >= 2 else { return }
            distanceM += delta
            let climb = location.altitude - last.altitude
            if climb > 0, location.verticalAccuracy >= 0, location.verticalAccuracy < 15 { elevationGain += climb }
        }
        segmentBreak = false
        locations.append(location)
        updatePace()
        recordSplitIfNeeded()
        updateActivity()
    }

    /// Pace over roughly the last 30 seconds.
    private func updatePace() {
        guard let latest = locations.last else { return }
        let window = locations.suffix(40).filter { latest.timestamp.timeIntervalSince($0.timestamp) <= 30 }
        guard let first = window.first, window.count > 2 else { return }
        var distance: Double = 0
        for (a, b) in zip(window, window.dropFirst()) { distance += b.distance(from: a) }
        let time = latest.timestamp.timeIntervalSince(first.timestamp)
        currentPaceSPerKm = distance > 20 ? time / (distance / 1000) : nil
    }

    private func recordSplitIfNeeded() {
        let splitLength = units == .km ? 1000.0 : Format.metersPerMile
        let covered = distanceM - splitStart.distance
        guard covered >= splitLength else { return }
        let now = elapsed()
        splits.append(.init(distanceM: covered, durationS: now - splitStart.time))
        splitStart = (distanceM, now)
        Haptics.success()
    }

    /// Keeps at most ~2,000 points for a compact route.
    private func simplifiedRoute() -> [CLLocationCoordinate2D] {
        let step = max(1, locations.count / 2000)
        return locations.enumerated()
            .filter { $0.offset % step == 0 || $0.offset == locations.count - 1 }
            .map(\.element.coordinate)
    }

    // MARK: Live Activity

    private var contentState: RunActivityAttributes.ContentState {
        RunActivityAttributes.ContentState(
            timerStart: Date.now.addingTimeInterval(-elapsed()),
            pausedElapsed: state == .paused ? elapsed() : nil,
            distanceM: distanceM,
            paceSPerKm: currentPaceSPerKm
        )
    }

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RunActivityAttributes(workoutTitle: workout?.title ?? "Run", usesMiles: units == .mi)
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: contentState, staleDate: nil)
        )
    }

    private func updateActivity(force: Bool = false) {
        guard let activity, force || Date.now.timeIntervalSince(lastActivityUpdate) > 10 else { return }
        lastActivityUpdate = .now
        let content = ActivityContent(state: contentState, staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endActivity() {
        guard let activity else { return }
        let content = ActivityContent(state: contentState, staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .immediate) }
        self.activity = nil
    }
}
