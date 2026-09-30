import SwiftUI

/// Home: the goal countdown and progress, today's workout, and the next few
/// days, on the shared tab layout.
struct TodayView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker

    @State private var sheet: AppSheet?
    @State private var path: [Workout] = []

    var body: some View {
        let units = store.units

        NavigationStack(path: $path) {
            TabPage(.wordmark, accessory: greeting) {
                if let plan = store.plan {
                    GoalProgressCard(plan: plan, units: units)
                }

                if let pending = store.pendingPlan, pending.status == .generating {
                    Card {
                        Label("Building your new plan…", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                TabSection("Today") {
                    if let workout = store.workouts.first(where: { $0.date == .today }) {
                        WorkoutHeroCard(
                            workout: workout,
                            run: store.run(for: workout),
                            units: units,
                            paces: store.plan?.paces,
                            onDone: { sheet = .log(workout, store.run(for: workout)) },
                            onStart: workout.isRest ? nil : { tracker.start(for: workout) }
                        )
                        .contentShape(.rect(cornerRadius: 28))
                        .onTapGesture { path.append(workout) }
                        .accessibilityAction(named: "Show details") { path.append(workout) }
                    } else {
                        OutsidePlanCard(day: .today, plan: store.plan)
                    }
                }

                if !upcoming.isEmpty {
                    TabSection("Upcoming") {
                        WorkoutListCard(workouts: upcoming, units: units)
                    }
                }

                Button {
                    sheet = .adjust
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.body.weight(.semibold))
                            .frame(width: 40, height: 40)
                            .background(Color.wash, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Adjust my plan").font(.body.weight(.semibold))
                            Text("Tired, busy or sore? Tell Kiki.").font(.subheadline).foregroundStyle(.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .elevatedCard(cornerRadius: 24)
                }
                .buttonStyle(.haptic)
            }
            .refreshable { await store.refresh() }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workoutID: $0.id) }
            .appSheets($sheet)
            .overlay(alignment: .bottom) { OfflineBanner() }
        }
        .onAppear { Analytics.screen("Home") }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return store.profile?.firstName.map { "\(part), \($0)!" } ?? "\(part)!"
    }

    /// The next several days after today (rest days included, so the
    /// runner sees the shape of the week).
    private var upcoming: [Workout] {
        Array(store.workouts.filter { $0.date > .today }.prefix(5))
    }
}

/// A list of workouts in one card (Home's Upcoming, each week on Plan).
/// Rows open the workout.
struct WorkoutListCard: View {
    let workouts: [Workout]
    let units: Units

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                    NavigationLink(value: workout) {
                        WorkoutRow(workout: workout, units: units)
                    }
                    .buttonStyle(.plain)
                    if index < workouts.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
    }
}

/// The first thing on Today: a countdown to the goal and progress so far.
private struct GoalProgressCard: View {
    @Environment(TrainingStore.self) private var store
    let plan: Plan
    let units: Units

    var body: some View {
        let finale = store.workouts.last { $0.type == .race }
        let endDate = finale?.date ?? plan.raceDate
        let daysLeft = max(0, Day.today.days(until: endDate))
        let week = store.currentWeekNumber
        let total = max(store.totalWeeks, 1)

        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your goal")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.paper.opacity(0.6))
                Text(plan.goalHeadline(units: units))
                    .font(.system(.title, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(plan.goalSubline(units: units, endDate: endDate))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.paper.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(daysLeft == 0 ? "It's today!" : daysLeft == 1 ? "1 day to go" : "\(daysLeft) days to go")
                        .font(.headline)
                    Spacer()
                    if let week {
                        Text("Week \(week) of \(total)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.paper.opacity(0.7))
                    }
                }
                ProgressView(value: Double(min(week ?? 0, total)), total: Double(total))
                    .tint(.paper)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.paper)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background { AsphaltBackground() }
        .clipShape(.rect(cornerRadius: 28))
        .shadow(color: .black.opacity(0.22), radius: 22, y: 10)
        .accessibilityElement(children: .combine)
    }
}

extension Plan {
    /// What the runner is working toward, in plain words: "Finish the
    /// Chicago Marathon", "10K in 45:00", "Run 30 minutes non-stop".
    func goalHeadline(units: Units) -> String {
        let distance = distanceLabel(units: units)
        switch goalKind {
        case .race:
            if goalType == .time, let time = goalTimeS {
                return "\(raceName ?? distance) in \(Format.duration(time))"
            }
            return "Finish the \(raceName ?? distance)"
        case .faster:
            if let time = goalTimeS { return "\(distance) in \(Format.duration(time))" }
            return "A faster \(distance)"
        case .start:
            return "Run 30 minutes non-stop"
        case .fit:
            return "Run consistently"
        }
    }

    /// The when (and the distance, if a named race hides it).
    func goalSubline(units: Units, endDate: Day) -> String {
        let date = endDate.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        switch goalKind {
        case .race:
            return raceName == nil ? date : "\(distanceLabel(units: units)) · \(date)"
        case .faster:
            return "Time trial · \(date)"
        case .start, .fit:
            return "By \(date)"
        }
    }
}

struct WorkoutHeroCard: View {
    let workout: Workout
    let run: Run?
    let units: Units
    let paces: PaceZones?
    let onDone: () -> Void
    let onStart: (() -> Void)?

    var body: some View {
        let inverted = !workout.isRest
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(workout.type.label.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(inverted ? Color.paper.opacity(0.6) : .secondary)
                Spacer()
                if workout.status == .completed {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                }
            }

            Text(workout.title)
                .font(.system(.title, weight: .bold))

            if let metric = Format.workoutMetric(workout, units: units) {
                HStack(alignment: .firstTextBaseline, spacing: 28) {
                    MetricView(value: metric.value, label: metric.unit, inverted: inverted)
                    if let zone = workout.type.paceZone, let range = paces?[zone] {
                        MetricView(
                            value: Format.pace(Double(range.max + range.min) / 2, units, withUnit: false),
                            label: "\(zone.rawValue) /\(units.rawValue)",
                            inverted: inverted
                        )
                    }
                }
            }

            Text(workout.description)
                .font(.subheadline)
                .foregroundStyle(inverted ? Color.paper.opacity(0.75) : .secondary)
                .lineLimit(4)

            if let run {
                RunSummaryLine(run: run, units: units, inverted: inverted)
            }

            if !workout.isRest {
                HStack(spacing: 10) {
                    Button(action: onDone) {
                        Text(workout.status == .completed ? "Edit run" : "Mark as done")
                            .font(.headline)
                            .foregroundStyle(.ink)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.paper, in: .capsule)
                    }
                    .buttonStyle(.haptic)

                    if let onStart, workout.status != .completed {
                        Button(action: onStart) {
                            Image(systemName: "figure.run")
                                .font(.headline)
                                .foregroundStyle(.paper)
                                .frame(width: 50, height: 50)
                                .overlay(Circle().stroke(Color.paper.opacity(0.35), lineWidth: 1.5))
                                .contentShape(.circle)
                        }
                        .buttonStyle(.haptic)
                        .accessibilityLabel("Start run with GPS")
                    }
                }
                .padding(.top, 4)
            } else {
                Button("Log a run anyway", action: onDone)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ink)
                    .buttonStyle(.haptic)
            }
        }
        .foregroundStyle(inverted ? Color.paper : Color.ink)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(inverted ? Color.ink : Color.surface, in: .rect(cornerRadius: 28))
        .shadow(color: .black.opacity(inverted ? 0.18 : 0.06), radius: 18, y: 8)
    }
}

struct MetricView: View {
    let value: String
    let label: String
    var inverted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.metric(.largeTitle))
            Text(label).font(.caption).foregroundStyle(inverted ? Color.paper.opacity(0.6) : .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RunSummaryLine: View {
    let run: Run
    let units: Units
    var inverted = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text([
                Format.distance(run.distanceM, units),
                Format.duration(run.durationS),
                run.pace.map { Format.pace($0, units) },
                run.feeling.map { "\($0.emoji) \($0.label)" },
            ].compactMap { $0 }.joined(separator: " · "))
        }
        .font(.subheadline.weight(.semibold))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((inverted ? Color.paper : Color.ink).opacity(0.1), in: .rect(cornerRadius: 14))
    }
}

private struct OutsidePlanCard: View {
    let day: Day
    let plan: Plan?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                if let plan, day < plan.startDate {
                    Text("Before your plan").font(.headline)
                    Text("Your plan starts \(Format.shortDate(plan.startDate)).").foregroundStyle(.muted)
                } else {
                    Text("Nothing scheduled").font(.headline)
                    Text("This day is outside your plan.").foregroundStyle(.muted)
                }
            }
        }
    }
}

struct OfflineBanner: View {
    @Environment(TrainingStore.self) private var store

    var body: some View {
        if !store.isOnline {
            Label("Offline. Changes will sync automatically.", systemImage: "wifi.slash")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect()
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// The splash's asphalt texture with a soft, warm "sun" that drifts slowly
/// across and back, so the card feels alive. Still under Reduce Motion.
struct AsphaltBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.launchBackground
                Image(.launchTexture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                RadialGradient(
                    colors: [
                        Color(red: 1, green: 0.74, blue: 0.4).opacity(0.28),
                        Color(red: 1, green: 0.55, blue: 0.2).opacity(0.08),
                        .clear,
                    ],
                    center: UnitPoint(x: -0.1 + 1.2 * phase, y: 0.1),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.75
                )
                .blendMode(.screen)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { phase = 0.7; return }
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }
}
