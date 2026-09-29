import MapKit
import SwiftUI

struct RunTrackerView: View {
    @Environment(RunTracker.self) private var tracker
    @Environment(TrainingStore.self) private var store
    @Environment(\.openURL) private var openURL

    @State private var draft: Run?
    @State private var confirmDiscard = false
    @State private var position: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)

    var body: some View {
        let units = store.units
        VStack(spacing: 0) {
            Map(position: $position) {
                UserAnnotation()
                if tracker.locations.count > 1 {
                    MapPolyline(coordinates: tracker.locations.map(\.coordinate))
                        .stroke(Color.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls { MapUserLocationButton() }
            .overlay(alignment: .topLeading) {
                if tracker.state == .ready {
                    Button("Close", systemImage: "xmark") { tracker.close() }
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .padding()
                }
            }

            VStack(spacing: 24) {
                if let title = tracker.workout?.title {
                    Text(title).font(.headline).foregroundStyle(.secondary)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Format.duration(Int(tracker.elapsed(at: context.date))))
                        .font(.system(size: 64, weight: .heavy).italic().monospacedDigit())
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
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .background(Color.paper)
        }
        .ignoresSafeArea(edges: .top)
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
            HStack(spacing: 12) {
                PrimaryButton("Resume") { tracker.resume() }
                Button {
                    if let run = tracker.finish() {
                        draft = run
                    } else {
                        confirmDiscard = true
                    }
                } label: {
                    Text("Finish")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .overlay(Capsule().stroke(Color.ink, lineWidth: 2))
                        .foregroundStyle(.ink)
                }
                .buttonStyle(.haptic)
            }
        case .finished:
            ProgressView()
        }
    }
}
