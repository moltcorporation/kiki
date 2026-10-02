import MapKit
import SwiftUI

struct RunTrackerView: View {
    @Environment(RunTracker.self) private var tracker
    @Environment(TrainingStore.self) private var store
    @Environment(HealthService.self) private var health
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

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
                HStack(spacing: Spacing.s) {
                    if let title = tracker.workout?.title {
                        Text(title).font(.headline).foregroundStyle(.muted)
                    }
                    if tracker.state == .ready, !tracker.authorizationDenied {
                        GPSStatus(isReady: tracker.hasGoodGPS)
                    }
                }

                if !tracker.authorizationDenied {
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
                }

                if tracker.authorizationDenied {
                    LocationOffCard { openSettings() }
                } else {
                    if tracker.isApproximateLocation {
                        Button(action: openSettings) {
                            Label("Precise Location is off, so distance may be off. Turn it on in Settings.", systemImage: "location.slash")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.muted)
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.haptic)
                    }
                    controls
                }
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
                if tracker.state != .finished {
                    // Before Start it just closes; during a run it asks first,
                    // so an accidental start is easy to throw away.
                    Button(tracker.state == .ready ? "Close" : "Discard run", systemImage: "xmark") {
                        if tracker.state == .ready { tracker.close() } else { confirmDiscard = true }
                    }
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
        // Coming back from Settings: pick up the new permission.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { tracker.refreshAuthorization() }
        }
        .onAppear {
            tracker.setUnits(units)
            Analytics.screen("Run Tracker")
        }
        .sheet(item: $draft, onDismiss: { tracker.close() }) { run in
            LogRunView(workout: tracker.workout, existing: nil, draft: run) { saved in
                // Kiki's GPS runs also go to Apple Health, with the route.
                let locations = tracker.locations
                Task { await health.saveRun(saved, locations: locations) }
            }
                .interactiveDismissDisabled()
        }
        .confirmationDialog("Discard this run?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard run", role: .destructive) { tracker.discard() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("It won't be saved.")
        }
    }

    /// Kiki's page in the Settings app (location, notifications).
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    @ViewBuilder
    private var controls: some View {
        switch tracker.state {
        case .ready:
            PrimaryButton("Start", isHighlighted: true) { tracker.begin() }
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

/// Whether GPS has a good fix yet, shown before the run starts.
private struct GPSStatus: View {
    let isReady: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if isReady {
                Image(systemName: "location.fill")
            } else {
                ProgressView().controlSize(.mini)
            }
            Text(isReady ? "GPS ready" : "Finding GPS…")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isReady ? Color.ink : Color.muted)
        .padding(.horizontal, Spacing.s + Spacing.xxs)
        .padding(.vertical, Spacing.xs)
        .background(Color.wash, in: .capsule)
        .animation(.snappy, value: isReady)
        .accessibilityElement(children: .combine)
    }
}

/// Shown instead of Start when location is off: why it's needed and a
/// button straight to Kiki's page in Settings.
private struct LocationOffCard: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "location.slash.fill")
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(Color.wash, in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xs) {
                Text("Turn on location to track runs").font(.cardTitle)
                Text("Kiki uses your location only while you run, to measure distance, pace and your route. In Settings, tap Location and choose While Using the App.")
                    .font(.detail)
                    .foregroundStyle(.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton("Open Settings", systemImage: "gear", action: openSettings)
        }
        .frame(maxWidth: .infinity)
    }
}
