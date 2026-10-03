import MapKit
import SwiftUI

/// The Log tab: every run, logged, tracked or synced from other apps,
/// newest first and grouped by month. The plan stays the plan; this is
/// the record. Tap a run to see, edit or delete it; + logs one by hand.
struct RunLogView: View {
    @Environment(TrainingStore.self) private var store
    @State private var path = NavigationPath()
    @State private var sheet: AppSheet?

    var body: some View {
        let units = store.units
        NavigationStack(path: $path) {
            TabPage("Log", accessory: AnyView(HeaderButton("Log a run", systemImage: "plus") { sheet = .log(nil, nil) })) {
                if store.runs.isEmpty {
                    MessageCard(icon: "figure.run", title: "No runs yet", message: "Runs you track, log or sync from other apps show up here.")
                } else {
                    ForEach(months, id: \.month) { month, runs in
                        PageSection(LocalizedStringKey(month.date.formatted(.dateTime.month(.wide).year())),
                                    detail: summary(runs, units)) {
                            ListCard {
                                ForEach(runs) { run in
                                    NavigationLink(value: run) { RunRow(run: run, units: units) }
                                        .buttonStyle(.haptic)
                                }
                            }
                        }
                    }
                }
            }
            .refreshable { await store.refresh() }
            .hidesTabBar(!path.isEmpty)
            .navigationDestination(for: Run.self) { RunDetailView(run: $0) }
            .appSheets($sheet)
        }
        .onAppear { Analytics.screen("Log") }
    }

    /// Runs grouped by month, newest first.
    private var months: [(month: Day, runs: [Run])] {
        Dictionary(grouping: store.runs) { Day($0.startedAt).firstOfMonth }
            .map { ($0.key, $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.month > $1.month }
    }

    /// "8 runs · 32.4 mi"
    private func summary(_ runs: [Run], _ units: Units) -> String {
        let meters = runs.reduce(0) { $0 + $1.distanceM }
        return "\(runs.count) \(runs.count == 1 ? "run" : "runs") · \(Format.distance(meters, units))"
    }
}

/// One run: what it was (the workout it checked off, or "Run"), the day
/// and distance (plus "Apple Health" when synced), then time and pace. The
/// icon says where it came from.
struct RunRow: View {
    @Environment(TrainingStore.self) private var store
    let run: Run
    let units: Units

    private var title: String {
        run.workoutId.flatMap { id in store.workouts.first { $0.id == id }?.title } ?? "Run"
    }


    var body: some View {
        ListRow(
            icon: run.source.icon,
            title: Text(title),
            subtitles: [[
                run.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                Format.distance(run.distanceM, units),
                run.source.isSynced ? run.source.label : nil,
            ].compactMap { $0 }.joined(separator: " · ")],
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
    @State private var confirmDelete = false

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
                            }
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            // Where it came from: tracked, synced or logged.
                            Label(current.source == .appleHealth ? "Synced from Apple Health" : current.source.label,
                                  systemImage: current.source.icon)
                                .font(.detail)
                                .foregroundStyle(.muted)
                            if let feeling = current.feeling {
                                Text("Felt: \(feeling.question)").font(.rowTitle)
                            }
                            if let notes = current.notes, !notes.isEmpty {
                                Text("“\(notes)”").font(.detail).foregroundStyle(.muted)
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
        // Actions at the bottom, like every other page (never in a menu).
        .bottomActions {
            SecondaryButton("Edit run", systemImage: "pencil") {
                sheet = .log(store.workouts.first { $0.id == current.workoutId }, current)
            }
            Button("Delete run", role: .destructive) { confirmDelete = true }
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.destructive)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
                .buttonStyle(.haptic)
                .confirmationDialog("Delete this run?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete run", role: .destructive) {
                        store.delete(current)
                        Haptics.success()
                        dismiss()
                    }
                } message: {
                    Text("It's removed from your log and your plan.")
                }
        }
        .appSheets($sheet)
        .task { full = await store.fullRun(run) }
    }
}

extension RunSource {
    /// Tracked in Kiki: a runner; synced: a heart; logged by hand: a pencil.
    var icon: String {
        switch self {
        case .kiki: "figure.run"
        case .appleHealth, .strava: "heart.fill"
        case .manual: "pencil"
        }
    }

    var label: String {
        switch self {
        case .kiki: "Tracked with Kiki"
        case .appleHealth: "Apple Health"
        case .strava: "Strava"
        case .manual: "Logged by hand"
        }
    }

    var isSynced: Bool { self == .appleHealth || self == .strava }
}
