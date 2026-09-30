import SwiftUI

struct TodayView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker

    @State private var selected = Day.today
    @State private var sheet: AppSheet?
    @State private var path: [Workout] = []

    var body: some View {
        let units = store.units
        let weekDays = (0..<7).map { selected.mondayOfWeek.adding(days: $0) }

        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    // Placeholder until the coach writes daily messages.
                    CoachMessage(text: "Rest up today, Sam. Tomorrow's tempo run is your first real test, and you're ready for it.")

                    if let pending = store.pendingPlan, pending.status == .generating {
                        Card {
                            Label("Building your new plan…", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    WeekStrip(days: weekDays, workouts: store.workouts, selected: $selected)
                        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                            let delta = value.translation.width < 0 ? 7 : -7
                            withAnimation(.snappy) { selected = selected.adding(days: delta) }
                            Haptics.select()
                        })

                    if let workout = store.workouts.first(where: { $0.date == selected }) {
                        WorkoutHeroCard(
                            workout: workout,
                            run: store.run(for: workout),
                            units: units,
                            paces: store.plan?.paces,
                            onDone: { sheet = .log(workout, store.run(for: workout)) },
                            onStart: selected == .today && !workout.isRest ? { tracker.start(for: workout) } : nil
                        )
                        .contentShape(.rect(cornerRadius: 28))
                        .onTapGesture { path.append(workout) }
                        .accessibilityAction(named: "Show details") { path.append(workout) }
                    } else {
                        OutsidePlanCard(day: selected, plan: store.plan)
                    }

                    if selected == .today, let next = store.nextRun {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Up next").font(.headline)
                            NavigationLink(value: next) {
                                WorkoutRow(workout: next, units: units)
                                    .background(Color.wash, in: .rect(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
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
                                Text("Tired, busy or sore? Tell Kiki.").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.ink)
                        .padding(14)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.1)))
                    }
                    .buttonStyle(.haptic)
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, 24)
            }
            .refreshable { await store.refresh() }
            .navigationTitle(greeting)
            .toolbar {
                // Wordmark centered in the bar, like a home tab logo.
                ToolbarItem(placement: .principal) {
                    Text("Kiki")
                        .font(.system(size: 20, weight: .black).italic())
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workoutID: $0.id) }
            .appSheets($sheet)
            .overlay(alignment: .bottom) { OfflineBanner() }
        }
        .onAppear { Analytics.screen("Today") }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return store.profile?.firstName.map { "\(part), \($0)!" } ?? "\(part)!"
    }

    /// Week progress plus a countdown to the plan's final workout (race, time
    /// trial or goal run), whatever the goal.
    @ViewBuilder
    private var header: some View {
        if store.plan != nil {
            VStack(alignment: .leading, spacing: 4) {
                if let week = store.currentWeekNumber {
                    Text("Week \(week) of \(store.totalWeeks)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if let finale = store.workouts.last(where: { $0.type == .race }) {
                    let daysLeft = Day.today.days(until: finale.date)
                    if daysLeft >= 0 {
                        Text(daysLeft == 0 ? "\(finale.title) is today 🏁" : "\(daysLeft) days to your \(finale.title)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
        .background(inverted ? Color.ink : Color.wash, in: .rect(cornerRadius: 28))
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
                    Text("Your plan starts \(Format.shortDate(plan.startDate)).").foregroundStyle(.secondary)
                } else {
                    Text("Nothing scheduled").font(.headline)
                    Text("This day is outside your plan.").foregroundStyle(.secondary)
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

/// A short note from Kiki (one or two sentences): the coach's avatar and a
/// chat bubble. Not a conversation, just the coach checking in.
struct CoachMessage: View {
    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            KikiLogo(size: 32)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.wash, in: UnevenRoundedRectangle(
                    topLeadingRadius: 20, bottomLeadingRadius: 6,
                    bottomTrailingRadius: 20, topTrailingRadius: 20
                ))
            Spacer(minLength: 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Message from Kiki: \(text)")
    }
}
