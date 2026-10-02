import CoreLocation
import SwiftUI

/// Home's "Get set up": nudges for what's still off (Apple Health to sync
/// runs from other apps, location to track runs), in the same tiles as
/// "Help Kiki grow". Only what's missing shows; nothing shows once done.
struct GetSetUpSection: View {
    @Environment(HealthService.self) private var health
    @Environment(TrainingStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var location = LocationPermission()

    var body: some View {
        let needsHealth = HealthService.isAvailable && !health.isConnected
        let needsLocation = location.status != .authorizedWhenInUse && location.status != .authorizedAlways
        if needsHealth || needsLocation {
            PageSection("Get set up") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Metrics.stackSpacing) {
                        if needsHealth {
                            Button {
                                Analytics.track("setup_tapped", ["item": "health"])
                                Task {
                                    if await health.connect() {
                                        Haptics.success()
                                        await health.sync(into: store)
                                        health.startObserving(store)
                                    }
                                }
                            } label: {
                                GrowTile(icon: "heart", title: "Apple Health", subtitle: "Sync other apps")
                            }
                            .buttonStyle(.haptic)
                        }
                        if needsLocation {
                            Button {
                                Analytics.track("setup_tapped", ["item": "location"])
                                if location.status == .notDetermined {
                                    location.request()
                                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            } label: {
                                GrowTile(icon: "location", title: "Location", subtitle: "Track your runs")
                            }
                            .buttonStyle(.haptic)
                        }
                    }
                }
                .contentMargins(.horizontal, Metrics.screenMargin, for: .scrollContent)
                .padding(.horizontal, -Metrics.screenMargin)
                .scrollClipDisabled()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { location.refresh() }
            }
        }
    }
}

/// Location permission, kept current (it changes in Settings or after the
/// prompt).
@Observable
final class LocationPermission: NSObject, CLLocationManagerDelegate {
    private(set) var status: CLAuthorizationStatus
    private let manager = CLLocationManager()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func request() { manager.requestWhenInUseAuthorization() }

    func refresh() { status = manager.authorizationStatus }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.status = status }
    }
}
