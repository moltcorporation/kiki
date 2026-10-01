import Charts
import MapKit
import SwiftUI

/// The runner's week, weekly distance and every logged or tracked run.
/// Pushed from the Profile tab, which owns the navigation stack.
struct RunsView: View {
    @Environment(TrainingStore.self) private var store
    @State private var sheet: AppSheet?

    var body: some View {
        let units = store.units
        DetailPage("Run history") {
            PageSection("This week") { thisWeek(units) }
            PageSection("Weekly distance") { volumeChart(units) }
            PageSection("Runs") { history(units) }
        }
        .refreshable { await store.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log a run", systemImage: "plus") { sheet = .log(nil, nil) }
            }
        }
        .appSheets($sheet)
        .onAppear { Analytics.screen("Runs") }
    }

    private func thisWeek(_ units: Units) -> some View {
        let week = store.workouts(inWeekOf: .today)
        let planned = Double(week.compactMap(\.distanceM).reduce(0, +))
        let monday = Day.today.mondayOfWeek
        let done = store.runs
            .filter { Day($0.startedAt) >= monday && Day($0.startedAt) <= monday.adding(days: 6) }
            .reduce(0) { $0 + $1.distanceM }
        let past = store.workouts.filter { !$0.isRest && $0.date < .today }
        let completed = past.filter { $0.status == .completed }.count

        return HStack(spacing: Metrics.stackSpacing) {
            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Distance").font(.eyebrow).foregroundStyle(.muted)
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(Format.distanceNumber(done, units)).font(.metric(.title))
                        Text("/ \(Format.distance(planned, units, decimals: 0))").font(.detail).foregroundStyle(.muted)
                    }
                    ProgressView(value: min(done, planned), total: max(planned, 1)).tint(.ink)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Plan completion").font(.eyebrow).foregroundStyle(.muted)
                    Text(past.isEmpty ? "–" : "\(Int(Double(completed) / Double(past.count) * 100))%")
                        .font(.metric(.title))
                    Text("\(completed) of \(past.count) runs").font(.detail).foregroundStyle(.muted)
                }
            }
        }
    }

    private func volumeChart(_ units: Units) -> some View {
        let data = weeklyVolume(units)
        return Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if data.isEmpty {
                    Text("Your weekly distance will appear here.").foregroundStyle(.muted)
                } else {
                    Chart(data) { item in
                        BarMark(x: .value("Week", item.label), y: .value("Planned", item.planned), width: .ratio(0.6))
                            .foregroundStyle(Color.track)
                        BarMark(x: .value("Week", item.label), y: .value("Done", item.done), width: .ratio(0.6))
                            .foregroundStyle(Color.ink)
                    }
                    .chartYAxisLabel(units.rawValue)
                    .frame(height: 180)
                    HStack(spacing: Spacing.l) {
                        Label("Done", systemImage: "square.fill").foregroundStyle(.ink)
                        Label("Planned", systemImage: "square.fill").foregroundStyle(Color.track)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private struct WeekVolume: Identifiable {
        let id: Int
        let label: String
        let planned: Double
        let done: Double
    }

    private func weeklyVolume(_ units: Units) -> [WeekVolume] {
        guard let current = store.currentWeekNumber else { return [] }
        return store.weeks
            .filter { $0.week >= current - 6 && $0.week <= current + 1 }
            .map { week, workouts in
                let monday = workouts.map(\.date).min()!.mondayOfWeek
                let sunday = monday.adding(days: 6)
                let done = store.runs
                    .filter { let d = Day($0.startedAt); return d >= monday && d <= sunday }
                    .reduce(0) { $0 + $1.distanceM }
                return WeekVolume(
                    id: week,
                    label: "W\(week)",
                    planned: Format.distanceValue(Double(workouts.compactMap(\.distanceM).reduce(0, +)), units),
                    done: Format.distanceValue(done, units)
                )
            }
    }

    @ViewBuilder
    private func history(_ units: Units) -> some View {
        if store.runs.isEmpty {
            MessageCard(icon: "figure.run", title: "No runs yet", message: "Runs you log or track will show up here.")
        } else {
            ListCard {
                ForEach(store.runs) { run in
                    NavigationLink(value: run) {
                        RunRow(run: run, units: units)
                    }
                    .buttonStyle(.haptic)
                }
            }
        }
    }
}

struct RunRow: View {
    let run: Run
    let units: Units

    var body: some View {
        ListRow(
            icon: run.source == .kiki ? "location.fill" : "figure.run",
            title: Text(Format.distance(run.distanceM, units)),
            subtitles: [
                [run.startedAt.formatted(.dateTime.weekday(.abbreviated).month().day()), run.feeling?.emoji]
                    .compactMap { $0 }.joined(separator: " "),
            ],
            showsChevron: true
        ) {
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(Format.duration(run.durationS)).font(.subheadline.weight(.semibold)).monospacedDigit()
                if let pace = run.pace {
                    Text(Format.pace(pace, units)).font(.detail).foregroundStyle(.muted)
                }
            }
            .foregroundStyle(.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RunDetailView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let run: Run
    @State private var full: Run?
    @State private var sheet: AppSheet?

    var body: some View {
        let units = store.units
        let current = store.runs.first { $0.id == run.id } ?? run
        let coordinates = Polyline.decode((full ?? current).route)

        DetailPage("Run") {
                if coordinates.count > 1 {
                    Map(initialPosition: .rect(Polyline.boundingRect(coordinates)), interactionModes: [.zoom, .pan]) {
                        MapPolyline(coordinates: coordinates)
                            .stroke(Color.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .frame(height: 260)
                    .clipShape(.rect(cornerRadius: Radius.card))
                    .elevation(.card)
                }

                PageHeader(
                    eyebrow: LocalizedStringKey(current.startedAt.formatted(.dateTime.hour().minute())),
                    title: LocalizedStringKey(current.startedAt.formatted(.dateTime.weekday(.wide).month().day()))
                )

                Card {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        Grid(alignment: .leading, horizontalSpacing: Spacing.xl, verticalSpacing: Spacing.xl) {
                            GridRow {
                                MetricView(value: Format.distanceNumber(current.distanceM, units, decimals: 2), label: units == .km ? "km" : "miles")
                                MetricView(value: Format.duration(current.durationS), label: "time")
                            }
                            GridRow {
                                if let pace = current.pace {
                                    MetricView(value: Format.pace(pace, units, withUnit: false), label: "avg pace /\(units.rawValue)")
                                }
                                if let effort = current.effort {
                                    MetricView(value: "\(effort)/10", label: "effort")
                                }
                            }
                        }
                        if current.feeling != nil || current.notes?.isEmpty == false {
                            Divider()
                            VStack(alignment: .leading, spacing: Spacing.s) {
                                if let feeling = current.feeling {
                                    Text("Felt \(feeling.label.lowercased()) \(feeling.emoji)").font(.rowTitle)
                                }
                                if let notes = current.notes, !notes.isEmpty {
                                    Text("“\(notes)”").font(.detail).foregroundStyle(.muted)
                                }
                            }
                        }
                    }
                }

                if let splits = (full ?? current).splits, !splits.isEmpty {
                    PageSection("Splits") {
                        ListCard(dividerInset: RowMetrics.horizontalPadding) {
                            ForEach(Array(splits.enumerated()), id: \.offset) { index, split in
                                HStack {
                                    Text("\(index + 1)").foregroundStyle(.muted)
                                    Spacer()
                                    Text(Format.pace(split.durationS / (split.distanceM / 1000), units)).font(.rowTitle)
                                }
                                .monospacedDigit()
                                .padding(.horizontal, RowMetrics.horizontalPadding)
                                .padding(.vertical, RowMetrics.verticalPadding)
                            }
                        }
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") {
                        sheet = .log(store.workouts.first { $0.id == current.workoutId }, current)
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        store.delete(current)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .appSheets($sheet)
        .task { full = await store.fullRun(run) }
    }
}
