import SwiftUI

struct PlanView: View {
    @Environment(TrainingStore.self) private var store
    @AppStorage("plan.viewMode") private var mode: Mode = .week
    @State private var sheet: AppSheet?

    enum Mode: String, CaseIterable {
        case week = "Week", month = "Month"
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .week: WeekListView()
                case .month: MonthCalendarView()
                }
            }
            .navigationTitle(store.plan?.displayName ?? "Plan")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workoutID: $0.id) }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .onChange(of: mode) { Haptics.select() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Adjust plan", systemImage: "sparkles") { sheet = .adjust }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .appSheets($sheet)
        }
        .onAppear { Analytics.screen("Plan", ["mode": mode.rawValue]) }
    }
}

private struct WeekListView: View {
    @Environment(TrainingStore.self) private var store

    var body: some View {
        let units = store.units
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8, pinnedViews: .sectionHeaders) {
                    if let plan = store.plan {
                        PlanHeader(plan: plan).padding(.bottom, 12)
                    }
                    ForEach(store.weeks, id: \.week) { week, workouts in
                        Section {
                            ForEach(workouts) { workout in
                                NavigationLink(value: workout) {
                                    WorkoutRow(workout: workout, units: units)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            WeekHeader(week: week, workouts: workouts, units: units, phase: phase(for: week))
                        }
                        .id(week)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable { await store.refresh() }
            .onAppear {
                if let current = store.currentWeekNumber, current > 1 {
                    proxy.scrollTo(current, anchor: .top)
                }
            }
        }
    }

    private func phase(for week: Int) -> String? {
        store.plan?.phases?.first { week >= $0.startWeek && week <= $0.endWeek }?.name
    }
}

private struct WeekHeader: View {
    let week: Int
    let workouts: [Workout]
    let units: Units
    let phase: String?

    var body: some View {
        let planned = workouts.compactMap(\.distanceM).reduce(0, +)
        let done = workouts.filter { $0.status == .completed }.count
        let runs = workouts.filter { !$0.isRest }.count
        HStack(alignment: .firstTextBaseline) {
            Text("Week \(week)").font(.title3.weight(.bold))
            if let phase { Text(phase).font(.subheadline).foregroundStyle(.secondary) }
            Spacer()
            Text("\(done)/\(runs) · \(Format.distance(Double(planned), units, decimals: 0))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color.paper)
    }
}

struct PlanHeader: View {
    let plan: Plan

    var body: some View {
        let days = Day.today.days(until: plan.raceDate)
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(plan.title ?? plan.displayName).font(.title3.weight(.bold))
                HStack(spacing: 20) {
                    Label(Format.shortDate(plan.raceDate), systemImage: "flag.checkered")
                    if days > 0 { Label("\(days) days", systemImage: "hourglass") }
                    if let predicted = plan.predictedTimeS {
                        Label(Format.duration(predicted), systemImage: "stopwatch")
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                if let summary = plan.summary {
                    Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
            }
        }
    }
}

private struct MonthCalendarView: View {
    @Environment(TrainingStore.self) private var store
    @State private var month = Day.today.firstOfMonth
    @State private var selected = Day.today

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let byDate = Dictionary(store.workouts.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(month.date, format: .dateTime.month(.wide).year())
                        .font(.title2.weight(.bold))
                    Spacer()
                    Button("Previous month", systemImage: "chevron.left") { change(by: -1) }
                        .labelStyle(.iconOnly)
                        .disabled(!canGo(-1))
                    Button("Next month", systemImage: "chevron.right") { change(by: 1) }
                        .labelStyle(.iconOnly)
                        .disabled(!canGo(1))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(1...7, id: \.self) { d in
                        Text(Calendar.current.veryShortWeekdaySymbols[d % 7])
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(0..<month.leadingBlankDays, id: \.self) { _ in Color.clear.frame(height: 52) }
                    ForEach(month.daysInMonth, id: \.self) { day in
                        DayCell(day: day, workout: byDate[day], isSelected: day == selected)
                            .onTapGesture {
                                Haptics.select()
                                selected = day
                            }
                    }
                }
                .gesture(DragGesture(minimumDistance: 40).onEnded { value in
                    change(by: value.translation.width < 0 ? 1 : -1)
                })

                if let workout = byDate[selected] {
                    NavigationLink(value: workout) {
                        WorkoutRow(workout: workout, units: store.units)
                            .background(Color.wash, in: .rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 16) {
                    LegendDot(filled: true, label: "Key workout")
                    LegendDot(filled: false, label: "Easy / long")
                    Label("Done", systemImage: "checkmark").labelStyle(.titleAndIcon)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func canGo(_ delta: Int) -> Bool {
        guard let plan = store.plan else { return true }
        let target = month.addingMonths(delta)
        return target >= plan.startDate.firstOfMonth && target <= plan.raceDate.firstOfMonth
    }

    private func change(by delta: Int) {
        guard canGo(delta) else { return }
        Haptics.select()
        withAnimation(.snappy) { month = month.addingMonths(delta) }
    }

    private struct LegendDot: View {
        let filled: Bool
        let label: String
        var body: some View {
            HStack(spacing: 4) {
                Circle()
                    .fill(filled ? Color.ink : .clear)
                    .stroke(Color.ink, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                Text(label)
            }
        }
    }
}

private struct DayCell: View {
    let day: Day
    let workout: Workout?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(day.day)")
                .font(.subheadline.weight(day == .today ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.paper : day == .today ? Color.ink : .primary)
            Group {
                if let workout, workout.status == .completed {
                    Image(systemName: "checkmark").font(.caption2.weight(.heavy))
                } else if let workout, !workout.isRest {
                    Circle()
                        .fill(workout.type.isQuality ? (isSelected ? Color.paper : Color.ink) : .clear)
                        .stroke(isSelected ? Color.paper : Color.ink, lineWidth: 1.5)
                        .frame(width: 8, height: 8)
                } else {
                    Color.clear.frame(width: 8, height: 8)
                }
            }
            .foregroundStyle(isSelected ? Color.paper : Color.ink)
            .frame(height: 10)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(isSelected ? Color.ink : day == .today ? Color.wash : .clear, in: .rect(cornerRadius: 14))
        .opacity(workout == nil ? 0.35 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day()))
        .accessibilityValue(workout.map { "\($0.title), \($0.status.rawValue)" } ?? "No workout")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

extension Day {
    var firstOfMonth: Day { Day(year: year, month: month, day: 1) }

    func addingMonths(_ months: Int) -> Day {
        Day(Calendar.current.date(byAdding: .month, value: months, to: firstOfMonth.date)!)
    }

    var daysInMonth: [Day] {
        let count = Calendar.current.range(of: .day, in: .month, for: date)!.count
        return (1...count).map { Day(year: year, month: month, day: $0) }
    }

    /// Blank cells before the 1st in a Monday-first grid.
    var leadingBlankDays: Int { firstOfMonth.isoWeekday - 1 }
}
