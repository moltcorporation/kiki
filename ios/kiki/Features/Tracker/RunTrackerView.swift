import MapKit
import SwiftUI

struct RunTrackerView: View {
    @Environment(RunTracker.self) private var tracker
    @Environment(TrainingStore.self) private var store
    @Environment(\.openURL) private var openURL

    @State private var draft: Run?
    @State private var confirmDiscard = false
    @State private var position: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
    @Namespace private var mapScope

    var body: some View {
        let units = store.units
        VStack(spacing: 0) {
            Map(position: $position, scope: mapScope) {
                UserAnnotation()
                if tracker.locations.count > 1 {
                    MapPolyline(coordinates: tracker.locations.map(\.coordinate))
                        .stroke(Color.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {}
            // Only the map runs under the status bar.
            .ignoresSafeArea(edges: .top)

            VStack(spacing: Spacing.xxl) {
                if let title = tracker.workout?.title {
                    Text(title).font(.headline).foregroundStyle(.muted)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Format.duration(Int(tracker.elapsed(at: context.date))))
                        .heroMetricFont()
                        .contentTransition(.numericText())
                }
                .accessibilityLabel("Time")

                HStack {
                    MetricView(value: Format.distanceNumber(tracker.distanceM, units, decimals: 2), label: units == .km ? "km" : "miles")
                        .frame(maxWidth: .infinity)
                    MetricView(value: tracker.currentPaceSPerKm.map { Format.pace($0, units, withUnit: false) } ?? "–:––", label: "pace /\(units.rawValue)")
                        .frame(maxWidth: .infinity)
                    MetricView(value: tracker.averagePaceSPerKm.map { Format.pace($0, units, withUnit: false) } ?? "–:––", label: "avg /\(units.rawValue)")
                        .frame(maxWidth: .infinity)
                }

                if tracker.authorizationDenied {
                    Button("Allow location access in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(.footnote.weight(.semibold))
                }

                controls
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.m)
            .background(Color.canvas)
        }
        // Inside the safe area, clear of the clock and Dynamic Island:
        // close on the left, recenter on the right.
        .overlay(alignment: .top) {
            HStack {
                if tracker.state == .ready {
                    Button("Close", systemImage: "xmark") { tracker.close() }
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .foregroundStyle(.ink)
                        .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                Spacer()
                MapUserLocationButton(scope: mapScope)
                    .buttonBorderShape(.circle)
                    .tint(.ink)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, Spacing.s)
        }
        .mapScope(mapScope)
        .onAppear {
            tracker.setUnits(units)
            Analytics.screen("Run Tracker")
        }
        .sheet(item: $draft, onDismiss: { tracker.close() }) { run in
            LogRunView(workout: tracker.workout, existing: nil, draft: run)
                .interactiveDismissDisabled()
        }
        .confirmationDialog("Discard this run?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard run", role: .destructive) { tracker.discard() }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch tracker.state {
        case .ready:
            PrimaryButton("Start") { tracker.begin() }
                .disabled(tracker.authorizationDenied)
        case .running:
            PrimaryButton("Pause") { tracker.pause() }
        case .paused:
            HStack(spacing: Spacing.m) {
                PrimaryButton("Resume") { tracker.resume() }
                SecondaryButton("Finish") {
                    if let run = tracker.finish() {
                        draft = run
                    } else {
                        confirmDiscard = true
                    }
                }
            }
        case .finished:
            ProgressView()
        }
    }
}
