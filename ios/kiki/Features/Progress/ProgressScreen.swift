import Charts
import MapKit
import SwiftUI

struct ProgressScreen: View {
    @Environment(TrainingStore.self) private var store
    @State private var sheet: AppSheet?

    var body: some View {
        let units = store.units
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    thisWeek(units)
                    volumeChart(units)
                    history(units)
                }
                .padding(20)
            }
            .refreshable { await store.refresh() }
            .navigationTitle("Progress")
            .navigationDestination(for: Run.self) { RunDetailView(run: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Log a run", systemImage: "plus") { sheet = .log(nil, nil) }
                }
            }
            .settingsToolbar($sheet)
            .appSheets($sheet)
        }
        .onAppear { Analytics.screen("Progress") }
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

        return HStack(spacing: 12) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("This week").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Format.distanceNumber(done, units)).font(.metric(.title))
                        Text("/ \(Format.distance(planned, units, decimals: 0))").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(done, planned), total: max(planned, 1)).tint(.ink)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Plan completion").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(past.isEmpty ? "–" : "\(Int(Double(completed) / Double(past.count) * 100))%")
                        .font(.metric(.title))
                    Text("\(completed) of \(past.count) runs").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func volumeChart(_ units: Units) -> some View {
        let data = weeklyVolume(units)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly distance").font(.headline)
                if data.isEmpty {
                    Text("Your weekly distance will appear here.").foregroundStyle(.secondary)
                } else {
                    Chart(data) { item in
                        BarMark(x: .value("Week", item.label), y: .value("Planned", item.planned), width: .ratio(0.6))
                            .foregroundStyle(Color.ink.opacity(0.15))
                        BarMark(x: .value("Week", item.label), y: .value("Done", item.done), width: .ratio(0.6))
                            .foregroundStyle(Color.ink)
                    }
                    .chartYAxisLabel(units.rawValue)
                    .frame(height: 180)
                    HStack(spacing: 16) {
                        Label("Done", systemImage: "square.fill").foregroundStyle(.ink)
                        Label("Planned", systemImage: "square.fill").foregroundStyle(Color.ink.opacity(0.2))
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

    private func history(_ units: Units) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Runs").font(.headline)
            if store.runs.isEmpty {
                Card {
                    Text("Runs you log or track will show up here.").foregroundStyle(.secondary)
                }
            } else {
                ForEach(store.runs) { run in
                    NavigationLink(value: run) {
                        RunRow(run: run, units: units)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RunRow: View {
    let run: Run
    let units: Units

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: run.source == .kiki ? "location.fill" : "figure.run")
                .font(.subheadline.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(Color.wash, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.distance(run.distanceM, units)).font(.body.weight(.semibold))
                Text(run.startedAt, format: .dateTime.weekday(.abbreviated).month().day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.duration(run.durationS)).font(.subheadline.weight(.semibold)).monospacedDigit()
                if let pace = run.pace {
                    Text(Format.pace(pace, units)).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let feeling = run.feeling { Text(feeling.emoji) }
        }
        .padding(12)
        .contentShape(.rect)
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

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if coordinates.count > 1 {
                    Map(initialPosition: .rect(Polyline.boundingRect(coordinates)), interactionModes: [.zoom, .pan]) {
                        MapPolyline(coordinates: coordinates)
                            .stroke(Color.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .frame(height: 260)
                    .clipShape(.rect(cornerRadius: 24))
                }

                Text(current.startedAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 20) {
                    MetricView(value: Format.distanceNumber(current.distanceM, units, decimals: 2), label: units == .km ? "km" : "miles")
                    MetricView(value: Format.duration(current.durationS), label: "time")
                    if let pace = current.pace {
                        MetricView(value: Format.pace(pace, units, withUnit: false), label: "avg pace /\(units.rawValue)")
                    }
                    if let effort = current.effort {
                        MetricView(value: "\(effort)/10", label: "effort")
                    }
                }

                if let feeling = current.feeling {
                    Label("Felt \(feeling.label.lowercased()) \(feeling.emoji)", systemImage: "heart.text.square")
                        .font(.headline)
                }
                if let notes = current.notes, !notes.isEmpty {
                    Text("“\(notes)”").foregroundStyle(.secondary)
                }

                if let splits = (full ?? current).splits, !splits.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Splits").font(.headline)
                        ForEach(Array(splits.enumerated()), id: \.offset) { index, split in
                            HStack {
                                Text("\(index + 1)").frame(width: 28, alignment: .leading).foregroundStyle(.secondary)
                                Text(Format.pace(split.durationS / (split.distanceM / 1000), units))
                                Spacer()
                            }
                            .font(.body.monospacedDigit())
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Run")
        .navigationBarTitleDisplayMode(.inline)
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
