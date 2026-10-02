import CoreLocation
import Foundation
import HealthKit

/// Apple Health: the universal connection to other running apps. Strava,
/// Garmin, Nike Run Club and the Apple Watch all save runs to Health, so
/// Kiki reads runs from there (and checks off the matching planned run) and
/// writes its own GPS runs back.
///
/// iOS never says which *read* permissions were granted, so reads are
/// best-effort: whatever comes back is used, anything missing is asked for.
@Observable
final class HealthService {
    static let isAvailable = HKHealthStore.isHealthDataAvailable()

    private let store = HKHealthStore()
    private static let connectedKey = "health.connected"

    /// The runner connected Apple Health (we asked and they finished the
    /// permission sheet). Their exact choices stay private to iOS.
    private(set) var isConnected = UserDefaults.standard.bool(forKey: HealthService.connectedKey)

    /// Metadata on runs Kiki writes to Health, so they're never imported back.
    private static let kikiRunKey = "KikiRunID"

    private var observer: HKObserverQuery?
    private var isSyncing = false

    // MARK: Permissions

    private var readTypes: Set<HKObjectType> {
        [
            .workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRate),
            HKQuantityType(.height),
            HKQuantityType(.bodyMass),
            HKCharacteristicType(.dateOfBirth),
        ]
    }

    private var shareTypes: Set<HKSampleType> {
        [.workoutType(), HKSeriesType.workoutRoute(), HKQuantityType(.distanceWalkingRunning)]
    }

    /// Shows the Health permission sheet. Returns false if Health isn't
    /// available or the request failed (not when the runner declines items).
    @discardableResult
    func connect() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            isConnected = true
            UserDefaults.standard.set(true, forKey: Self.connectedKey)
            Analytics.track("health_connected")
            return true
        } catch {
            Analytics.captureError(error, context: ["step": "health_authorization"])
            return false
        }
    }

    // MARK: About you

    struct BodyInfo {
        var age: Int?
        var heightCm: Double?
        var weightKg: Double?
    }

    /// Age, height and weight, whichever Health has and shares.
    func bodyInfo() async -> BodyInfo {
        var info = BodyInfo()
        if let birthday = try? store.dateOfBirthComponents().date {
            info.age = Calendar.current.dateComponents([.year], from: birthday, to: .now).year
        }
        info.heightCm = await latest(.height, unit: .meterUnit(with: .centi))
        info.weightKg = await latest(.bodyMass, unit: .gramUnit(with: .kilo))
        return info
    }

    private func latest(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try? await descriptor.result(for: store).first?.quantity.doubleValue(for: unit)
    }

    // MARK: Importing runs

    /// Imports runs saved to Health by other apps since the plan started.
    /// A run on a day with a planned run checks it off; others go to Run
    /// history (so miles stay right) without touching the calendar.
    /// Never double counts: Kiki's own runs are skipped, and so is any run
    /// that overlaps one already in Kiki (Kiki's recording wins).
    func sync(into training: TrainingStore) async {
        guard isConnected, !isSyncing, let plan = training.plan else { return }
        isSyncing = true
        defer { isSyncing = false }

        let since = Calendar.current.date(byAdding: .day, value: -1, to: plan.startDate.date) ?? plan.startDate.date
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForWorkouts(with: .running),
                HKQuery.predicateForSamples(withStart: since, end: nil),
            ]))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let workouts = try? await descriptor.result(for: store) else { return }

        var imported = 0
        for workout in workouts {
            // Kiki's own runs, written back to Health.
            if workout.metadata?[Self.kikiRunKey] != nil { continue }
            let externalID = workout.uuid.uuidString
            // Imported runs the runner deleted stay deleted, including copies
            // of the same run saved by another app.
            if Self.isIgnored(start: workout.startDate, end: workout.endDate) { continue }
            if training.runs.contains(where: { $0.externalId == externalID || $0.id == workout.uuid }) { continue }
            // The same run recorded by two apps (say Strava and Kiki).
            if training.runs.contains(where: { $0.overlaps(workout.startDate, workout.endDate) }) { continue }

            let meters = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meter()) ?? 0
            guard meters > 100 else { continue }
            let heartRate = workout.statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

            let day = Day(workout.startDate)
            let planned = training.workouts.first { candidate in
                candidate.date == day && !candidate.isRest && candidate.status != .completed
                    && !training.runs.contains { $0.workoutId == candidate.id }
            }
            training.save(Run(
                // The Health workout's ID, so re-syncing is idempotent.
                id: workout.uuid,
                workoutId: planned?.id,
                source: .appleHealth,
                externalId: externalID,
                startedAt: workout.startDate,
                distanceM: meters,
                durationS: Int(workout.duration.rounded()),
                avgHeartRate: heartRate.map { Int($0.rounded()) }
            ))
            imported += 1
        }
        if imported > 0 {
            Analytics.track("health_runs_imported", ["count": imported])
        }
    }

    /// Re-syncs whenever Health gets a new workout, even in the background.
    func startObserving(_ training: TrainingStore) {
        guard isConnected, observer == nil else { return }
        let query = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { [weak self] _, completion, _ in
            Task { @MainActor in
                await self?.sync(into: training)
                completion()
            }
        }
        observer = query
        store.execute(query)
        store.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate) { _, _ in }
    }

    /// Time windows of imported runs the runner deleted, as "start|end"
    /// (seconds since 1970).
    private static let ignoredKey = "health.ignoredRuns"

    private static func isIgnored(start: Date, end: Date) -> Bool {
        (UserDefaults.standard.stringArray(forKey: ignoredKey) ?? []).contains { window in
            let parts = window.split(separator: "|").compactMap { Double($0) }
            guard parts.count == 2 else { return false }
            return start.timeIntervalSince1970 < parts[1] && end.timeIntervalSince1970 > parts[0]
        }
    }

    /// Never import a Health run in this window again (the runner deleted
    /// it in Kiki), whichever app saved it.
    static func ignore(_ run: Run) {
        let start = run.startedAt.timeIntervalSince1970
        let window = "\(start)|\(start + Double(max(run.durationS, 60)))"
        var windows = UserDefaults.standard.stringArray(forKey: ignoredKey) ?? []
        windows.append(window)
        UserDefaults.standard.set(windows, forKey: ignoredKey)
    }

    // MARK: Writing Kiki's runs

    /// Saves a run recorded in Kiki to Health, with its route.
    func saveRun(_ run: Run, locations: [CLLocation]) async {
        guard isConnected, store.authorizationStatus(for: .workoutType()) == .sharingAuthorized else { return }
        let start = run.startedAt
        let end = locations.last?.timestamp ?? start.addingTimeInterval(TimeInterval(run.durationS))
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        do {
            let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
            try await builder.beginCollection(at: start)
            let distance = HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meter(), doubleValue: run.distanceM),
                start: start,
                end: end
            )
            try await builder.addSamples([distance])
            try await builder.addMetadata([Self.kikiRunKey: run.id.uuidString])
            try await builder.endCollection(at: end)
            guard let workout = try await builder.finishWorkout() else { return }

            if !locations.isEmpty, store.authorizationStatus(for: HKSeriesType.workoutRoute()) == .sharingAuthorized {
                let route = HKWorkoutRouteBuilder(healthStore: store, device: .local())
                try await route.insertRouteData(locations)
                try await route.finishRoute(with: workout, metadata: nil)
            }
            Analytics.track("health_run_saved")
        } catch {
            Analytics.captureError(error, context: ["step": "health_save_run"])
        }
    }
}

extension Run {
    /// True if this run's time overlaps the given interval.
    func overlaps(_ start: Date, _ end: Date) -> Bool {
        let runEnd = startedAt.addingTimeInterval(TimeInterval(max(durationS, 60)))
        return startedAt < end && runEnd > start
    }
}
