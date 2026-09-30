import Foundation
import Network

/// Single source of truth for the runner's profile, plan, workouts and runs.
///
/// Reads come from a disk cache first so the app opens instantly (and works
/// offline), then refresh from the server. Writes are optimistic: the UI
/// updates immediately and changes sync through a persistent outbox.
@Observable
final class TrainingStore {
    private(set) var profile: Profile?
    private(set) var plan: Plan?
    private(set) var workouts: [Workout] = []
    /// A newer plan that's generating or failed to generate.
    private(set) var pendingPlan: Plan?
    private(set) var runs: [Run] = []
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false
    /// Whether the server has an agreement to the Terms and Privacy Policy
    /// on record. Only trusted once `consentChecked` (never guessed from the
    /// offline cache).
    private(set) var consentVersion: String?
    private(set) var consentChecked = false

    /// True when the server confirms the user has never agreed (an account
    /// created from the welcome "Sign in" rather than onboarding).
    var needsConsent: Bool {
        consentChecked && consentVersion == nil
    }

    func markConsented() {
        consentVersion = Config.legalVersion
    }
    private(set) var isOnline = true
    private(set) var lastError: APIError?

    private let api = APIClient.shared
    private let cache = DiskCache()
    private var outbox: [PendingChange] = []
    private var isFlushing = false
    private let monitor = NWPathMonitor()

    var units: Units { profile?.units ?? .localeDefault }

    init() {
        if let snapshot = cache.load() {
            profile = snapshot.profile
            plan = snapshot.plan
            workouts = snapshot.workouts
            runs = snapshot.runs
            outbox = snapshot.outbox
            hasLoaded = snapshot.plan != nil
        }
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let online = path.status == .satisfied
                let cameOnline = online && !self.isOnline
                self.isOnline = online
                if cameOnline { await self.flush() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "kiki.network"))
    }

    // MARK: Derived data

    var today: Day { Day.today }

    var todayWorkout: Workout? { workouts.first { $0.date == today } }

    var nextRun: Workout? {
        workouts.first { $0.date > today && !$0.isRest && $0.status == .planned }
    }

    func workouts(inWeekOf day: Day) -> [Workout] {
        let monday = day.mondayOfWeek
        let sunday = monday.adding(days: 6)
        return workouts.filter { $0.date >= monday && $0.date <= sunday }
    }

    var weeks: [(week: Int, workouts: [Workout])] {
        Dictionary(grouping: workouts, by: \.week)
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    var currentWeekNumber: Int? {
        workouts.first { $0.date >= today.mondayOfWeek }?.week
    }

    var totalWeeks: Int { workouts.map(\.week).max() ?? 0 }

    func run(for workout: Workout) -> Run? {
        runs.first { $0.workoutId == workout.id }
    }

    // MARK: Loading

    /// Returns true when the server answered and local state is current.
    @discardableResult
    func refresh() async -> Bool {
        guard Keychain.sessionToken != nil else { return false }
        isRefreshing = true
        defer { isRefreshing = false }
        await flush()
        do {
            async let me: MeResponse = api.get("api/me")
            async let current: CurrentPlanResponse = api.get("api/plans/current")
            async let recent: RunsResponse = api.get("api/runs", query: ["limit": "200"])
            let (meResult, currentResult, runsResult) = try await (me, current, recent)

            profile = meResult.profile
            consentVersion = meResult.consentVersion
            consentChecked = true
            apply(currentResult)
            runs = mergePending(runsResult.runs)
            hasLoaded = true
            lastError = nil
            persist()
            return true
        } catch let error as APIError {
            lastError = error
            hasLoaded = true
        } catch is CancellationError {
        } catch {
            lastError = .unexpected
        }
        return false
    }

    private func apply(_ response: CurrentPlanResponse) {
        plan = response.plan
        workouts = response.workouts.map { local in
            // Keep optimistic status changes that haven't synced yet.
            if let pending = outbox.lastStatus(for: local.id) {
                var w = local
                w.status = pending
                return w
            }
            return local
        }
        pendingPlan = response.pending
    }

    private func mergePending(_ server: [Run]) -> [Run] {
        let pendingIDs = Set(outbox.pendingRunIDs)
        let deleted = Set(outbox.deletedRunIDs)
        let local = runs.filter { pendingIDs.contains($0.id) }
        let merged = local + server.filter { !pendingIDs.contains($0.id) && !deleted.contains($0.id) }
        return merged.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: Profile & plans

    func saveProfile(_ profile: Profile) async throws {
        struct Response: Decodable { let profile: Profile }
        let response: Response = try await api.put("api/me/profile", profile)
        self.profile = response.profile
        persist()
    }

    /// Starts generating a plan and returns it (status `generating`).
    func createPlan(_ request: PlanRequest) async throws -> Plan {
        struct Response: Decodable { let plan: Plan }
        let response: Response = try await api.post("api/plans", request)
        pendingPlan = response.plan
        Analytics.track("plan_requested", ["goal_kind": request.goalKind.rawValue, "race_distance": request.raceDistance?.rawValue ?? "none", "goal": request.goalType.rawValue])
        return response.plan
    }

    /// Polls until the plan is ready (then makes it current) or fails.
    func waitForPlan(_ id: UUID, onProgress: (Int) -> Void = { _ in }) async throws -> Plan {
        let deadline = Date.now.addingTimeInterval(300)
        while Date.now < deadline {
            try Task.checkCancellation()
            let response: PlanResponse = try await api.get("api/plans/\(id.uuidString.lowercased())")
            onProgress(response.plan.progress)
            switch response.plan.status {
            case .ready:
                plan = response.plan
                workouts = response.workouts ?? []
                pendingPlan = nil
                persist()
                Analytics.track("plan_ready", ["weeks": totalWeeks])
                return response.plan
            case .failed:
                pendingPlan = response.plan
                Analytics.track("plan_failed")
                throw APIError.server(code: "plan_failed", message: "We couldn't build your plan. Please try again.")
            case .generating, .archived:
                try await Task.sleep(for: .seconds(2))
            }
        }
        throw APIError.server(code: "timeout", message: "Building your plan is taking longer than expected. Please try again.")
    }

    // MARK: Workouts

    func setStatus(_ status: Workout.Status, for workout: Workout) {
        updateWorkout(workout.id) { $0.status = status }
        enqueue(.workoutStatus(id: workout.id, status: status))
        Analytics.track("workout_status_changed", ["status": status.rawValue, "type": workout.type.rawValue])
    }

    /// Swaps a workout with another day of the plan (online only).
    func move(_ workout: Workout, to day: Day) async throws {
        struct Body: Encodable { let moveTo: Day }
        struct Response: Decodable { let workouts: [Workout] }
        let response: Response = try await api.patch("api/workouts/\(workout.id.uuidString.lowercased())", Body(moveTo: day))
        for updated in response.workouts {
            updateWorkout(updated.id) { $0 = updated }
        }
        persist()
        Analytics.track("workout_moved", ["type": workout.type.rawValue])
    }

    private func updateWorkout(_ id: UUID, _ change: (inout Workout) -> Void) {
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        change(&workouts[index])
    }

    // MARK: Runs

    func save(_ run: Run) {
        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            let previous = runs[index].workoutId
            runs[index] = run
            if let previous, previous != run.workoutId,
               !runs.contains(where: { $0.workoutId == previous }) {
                updateWorkout(previous) { if $0.status == .completed { $0.status = .planned } }
            }
        } else {
            runs.insert(run, at: 0)
            runs.sort { $0.startedAt > $1.startedAt }
        }
        if let workoutID = run.workoutId {
            updateWorkout(workoutID) { $0.status = .completed }
        }
        enqueue(.upsertRun(run))
        Analytics.track("run_saved", [
            "source": run.source.rawValue,
            "linked_workout": run.workoutId != nil,
            "feeling": run.feeling?.rawValue ?? "none",
        ])
    }

    func delete(_ run: Run) {
        runs.removeAll { $0.id == run.id }
        if let workoutID = run.workoutId, !runs.contains(where: { $0.workoutId == workoutID }) {
            updateWorkout(workoutID) { if $0.status == .completed { $0.status = .planned } }
        }
        enqueue(.deleteRun(id: run.id))
    }

    /// Fetches a run with its full route, if we only have the summary.
    func fullRun(_ run: Run) async -> Run {
        guard run.route == nil, run.source == .kiki else { return run }
        struct Response: Decodable { let run: Run }
        guard let response: Response = try? await api.get("api/runs/\(run.id.uuidString.lowercased())") else { return run }
        if let index = runs.firstIndex(where: { $0.id == run.id }) { runs[index] = response.run }
        return response.run
    }

    // MARK: Coach adjustments

    func requestAdjustment(reason: AdjustReason, message: String?) async throws -> Adjustment {
        struct Body: Encodable { let id: UUID; let reason: AdjustReason; let message: String?; let today: Day }
        struct Response: Decodable { let adjustment: Adjustment }
        await flush()
        let id = UUID()
        let started: Response = try await api.post("api/adjustments", Body(id: id, reason: reason, message: message, today: .today))
        Analytics.track("adjustment_requested", ["reason": reason.rawValue])

        var adjustment = started.adjustment
        let deadline = Date.now.addingTimeInterval(180)
        while adjustment.status == .pending, Date.now < deadline {
            try await Task.sleep(for: .seconds(2))
            let poll: Response = try await api.get("api/adjustments/\(id.uuidString.lowercased())")
            adjustment = poll.adjustment
        }
        switch adjustment.status {
        case .applied:
            await refresh()
            Analytics.track("adjustment_applied", ["changes": adjustment.changedDates?.count ?? 0])
            return adjustment
        case .failed, .pending:
            throw APIError.server(code: "adjust_failed", message: "Kiki couldn't update your plan right now. Please try again.")
        }
    }

    // MARK: Outbox

    private func enqueue(_ change: PendingChange) {
        outbox.append(change)
        persist()
        Task { await flush() }
    }

    /// Sends pending changes in order. Stops on connectivity problems and
    /// drops changes the server rejects outright.
    func flush() async {
        guard !isFlushing, !outbox.isEmpty, Keychain.sessionToken != nil else { return }
        isFlushing = true
        defer { isFlushing = false }

        while let change = outbox.first {
            do {
                try await send(change)
                outbox.removeFirst()
                persist()
            } catch let error as APIError where error.isRetryable {
                return
            } catch APIError.unauthorized {
                return
            } catch {
                Analytics.captureError(error, context: ["step": "outbox", "change": change.kind])
                outbox.removeFirst()
                persist()
            }
        }
    }

    private func send(_ change: PendingChange) async throws {
        switch change {
        case .upsertRun(let run):
            let _: Empty = try await api.post("api/runs", run)
        case .deleteRun(let id):
            try await api.delete("api/runs/\(id.uuidString.lowercased())")
        case .workoutStatus(let id, let status):
            struct Body: Encodable { let status: Workout.Status }
            let _: Empty = try await api.patch("api/workouts/\(id.uuidString.lowercased())", Body(status: status))
        }
    }

    // MARK: Persistence

    func reset() {
        profile = nil
        plan = nil
        workouts = []
        pendingPlan = nil
        runs = []
        outbox = []
        hasLoaded = false
        consentVersion = nil
        consentChecked = false
        cache.clear()
    }

    private func persist() {
        cache.save(.init(profile: profile, plan: plan, workouts: workouts, runs: runs, outbox: outbox))
    }
}

private nonisolated struct RunsResponse: Decodable {
    let runs: [Run]
}

// MARK: - Outbox changes

enum PendingChange: Codable {
    case upsertRun(Run)
    case deleteRun(id: UUID)
    case workoutStatus(id: UUID, status: Workout.Status)

    var kind: String {
        switch self {
        case .upsertRun: "upsert_run"
        case .deleteRun: "delete_run"
        case .workoutStatus: "workout_status"
        }
    }
}

private extension [PendingChange] {
    var pendingRunIDs: [UUID] {
        compactMap { if case .upsertRun(let run) = $0 { run.id } else { nil } }
    }

    var deletedRunIDs: [UUID] {
        compactMap { if case .deleteRun(let id) = $0 { id } else { nil } }
    }

    func lastStatus(for workoutID: UUID) -> Workout.Status? {
        last { if case .workoutStatus(let id, _) = $0 { id == workoutID } else { false } }
            .flatMap { if case .workoutStatus(_, let status) = $0 { status } else { nil } }
    }
}

// MARK: - Disk cache

private struct DiskCache {
    struct Snapshot: Codable {
        var profile: Profile?
        var plan: Plan?
        var workouts: [Workout]
        var runs: [Run]
        var outbox: [PendingChange]
    }

    private let url = URL.applicationSupportDirectory.appending(path: "training-cache.json")

    func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? APIClient.shared.decode(Snapshot.self, from: data)
    }

    func save(_ snapshot: Snapshot) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try APIClient.shared.encode(snapshot).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Analytics.captureError(error, context: ["step": "cache_save"])
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
