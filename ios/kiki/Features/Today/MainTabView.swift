import SwiftUI

struct MainTabView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker
    @State private var tab: AppTab = .today
    @State private var tabBar = TabBarState()

    enum AppTab: Hashable { case today, plan, run, log, you }

    var body: some View {
        @Bindable var tracker = tracker
        // Safety net: the glass bar lets you drag its highlight across tabs,
        // so the middle slot could still be picked that way. It opens the
        // tracker instead of becoming the selection.
        TabView(selection: Binding(
            get: { tab },
            set: { new in
                if new == .run { startRun() } else { tab = new }
            }
        )) {
            Tab(value: .today) {
                TodayView(onViewPlan: { tab = .plan })
            } label: {
                tabLabel("Home", "house", .today)
            }
            Tab(value: .plan) {
                PlanView()
            } label: {
                tabLabel("Plan", "calendar", .plan)
            }
            // Holds the middle slot for the run button laid over it.
            Tab(value: AppTab.run) {
                Color.clear
            } label: {
                Text(verbatim: "")
            }
            .disabled(true)
            Tab(value: .log) {
                RunLogView()
            } label: {
                tabLabel("Log", "list.bullet.clipboard", .log)
            }
            Tab(value: .you) {
                YouView()
            } label: {
                tabLabel("Profile", "person.crop.circle", .you)
            }
        }
        .tabBarMinimizeBehavior(.never)
        // The run button sits over the empty middle tab, outside the tab bar,
        // so the bar never sees the touch and its glass highlight stays put.
        .overlay {
            RunTabButton(isHidden: tabBar.isHidden, state: tracker.state, action: startRun)
        }
        .environment(\.tabBarState, tabBar)
        .onChange(of: tab) { Haptics.select() }
        // A sheet, so a run in progress can be swiped down to use the rest
        // of the app (it keeps recording; the floating pill brings it back).
        .sheet(isPresented: $tracker.isPresented, onDismiss: {
            // Swiped away before starting: stop warming up GPS.
            if tracker.state == .ready { tracker.close() }
        }) {
            RunTrackerView()
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(tracker.state == .finished)
        }
        .task {
            await store.refresh()
            if let units = store.profile?.units {
                await Notifications.scheduleWorkoutReminders(store.workouts, units: units)
            }
        }
    }
}

extension MainTabView {
    /// Outline icons, filled only for the selected tab, drawn a touch
    /// smaller and lighter than the system default.
    func tabLabel(_ title: LocalizedStringKey, _ symbol: String, _ value: AppTab) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: Self.tabIcon(symbol, filled: tab == value))
        }
    }

    static func tabIcon(_ symbol: String, filled: Bool) -> UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = (filled ? UIImage(systemName: symbol + ".fill", withConfiguration: configuration) : nil)
            ?? UIImage(systemName: symbol, withConfiguration: configuration)
            ?? UIImage()
        // Template, so the tab bar still tints selected and unselected.
        return image.withRenderingMode(.alwaysTemplate)
    }

    /// The middle button. With no run going: opens the tracker, linked to
    /// today's workout if there's one still to do, otherwise a free run
    /// (rest days, extra runs). During a run it shows pause (or play when
    /// paused): it pauses or resumes and brings the tracker back.
    func startRun() {
        Haptics.tap()
        switch tracker.state {
        case .running:
            tracker.pause()
            tracker.isPresented = true
            return
        case .paused:
            tracker.resume()
            tracker.isPresented = true
            return
        case .finished:
            tracker.isPresented = true
            return
        case .ready:
            break
        }
        let today = store.workouts.first { $0.date == .today && !$0.isRest && $0.status == .planned }
        tracker.start(for: today)
    }
}

/// Sheets that can be opened from any tab.
enum AppSheet: Identifiable {
    case log(Workout?, Run?)
    case adjustDay(Workout)
    case adjustPlan

    var id: String {
        switch self {
        case .log(let workout, let run): "log-\(workout?.id.uuidString ?? "")-\(run?.id.uuidString ?? "")"
        case .adjustDay(let workout): "adjust-\(workout.id.uuidString)"
        case .adjustPlan: "adjust-plan"
        }
    }
}

extension View {
    func appSheets(_ sheet: Binding<AppSheet?>) -> some View {
        self.sheet(item: sheet) { item in
            switch item {
            case .log(let workout, let run):
                LogRunView(workout: workout, existing: run)
            case .adjustDay(let workout):
                ProOnly(title: "Adjust with Kiki Pro", message: "Kiki reworks your runs when you're tired, busy or sore.", source: "adjust_day") {
                    AdjustSheet(scope: .day(workout))
                }
            case .adjustPlan:
                ProOnly(title: "Adjust with Kiki Pro", message: "Kiki reworks your plan when life happens.", source: "adjust_plan") {
                    AdjustSheet(scope: .plan)
                }
            }
        }
    }
}

/// The run button over the tab bar's middle slot: a black circle with a
/// Volt play triangle. Placed where the tab bar is (`TabBarFrameReader`)
/// and hidden with it on pushed screens.
private struct RunTabButton: View {
    let isHidden: Bool
    let state: RunTracker.State
    let action: () -> Void
    @State private var tabBarFrame: CGRect?
    private static let glassOffset: CGFloat = 11

    private var symbol: String { state == .running ? "pause.fill" : "play.fill" }

    private var label: String {
        switch state {
        case .ready: "Start a run"
        case .running: "Pause run"
        case .paused: "Resume run"
        case .finished: "Finish run"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            if let frame = tabBarFrame {
                let origin = proxy.frame(in: .global).origin
                let center = CGPoint(x: frame.midX - origin.x, y: frame.midY - origin.y - Self.glassOffset)
                Button(action: action) {
                    Image(systemName: symbol)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(Color.highlight)
                        .contentTransition(.symbolEffect(.replace))
                        // Nudged right so the triangle looks centered.
                        .offset(x: state == .running ? 0 : 1.5)
                        .frame(width: 44, height: 44)
                        .background(Color.onHighlight, in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                // The bar's frame runs into the home indicator area; its
                // visible glass is centered a little higher.
                .position(center)
                .opacity(isHidden ? 0 : 1)
                .allowsHitTesting(!isHidden)
                .accessibilityHidden(isHidden)

                // A run in progress: a pill above the bar, on the right.
                ActiveRunPill()
                    .frame(width: max(frame.width - Metrics.screenMargin * 2, 0), alignment: .trailing)
                    .position(x: frame.midX - origin.x,
                              y: frame.minY - origin.y - Self.glassOffset - Spacing.s - 25)
                    .opacity(isHidden ? 0 : 1)
                    .allowsHitTesting(!isHidden)
                    .accessibilityHidden(isHidden)
            }
        }
        .ignoresSafeArea()
        .background(TabBarFrameReader { tabBarFrame = $0 })
    }
}

/// While a run is going and the tracker is swiped away: the time and
/// distance in a black pill with a Volt dot (pulsing while recording).
/// Tap it to go back to the run.
private struct ActiveRunPill: View {
    @Environment(RunTracker.self) private var tracker
    @Environment(TrainingStore.self) private var store

    private var isVisible: Bool {
        !tracker.isPresented && (tracker.state == .running || tracker.state == .paused)
    }

    var body: some View {
        if isVisible {
            Button {
                Haptics.tap()
                tracker.isPresented = true
            } label: {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: Spacing.s + Spacing.xxs) {
                        Circle()
                            .fill(Color.highlight)
                            .frame(width: 10, height: 10)
                            .opacity(tracker.state == .paused ? 0.4 : 1)
                            .symbolEffect(.pulse, isActive: tracker.state == .running)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(tracker.state == .paused ? "Paused" : "Running")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.65))
                            Text(Format.duration(Int(tracker.elapsed(at: context.date))))
                                .font(.body.weight(.bold))
                                .monospacedDigit()
                        }
                        Text(Format.distance(tracker.distanceM, store.units, decimals: 2))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .monospacedDigit()
                    }
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.leading, Spacing.l)
                    .padding(.trailing, Spacing.l + Spacing.xxs)
                    .frame(height: 50)
                    .background(Color.onHighlight, in: .capsule)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                }
            }
            .buttonStyle(.haptic)
            .fixedSize()
            .accessibilityLabel(tracker.state == .paused ? "Run paused. Open run" : "Run in progress. Open run")
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}

/// Reports the system tab bar's frame in window coordinates.
private struct TabBarFrameReader: UIViewRepresentable {
    let onChange: (CGRect) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let tabBar = Self.tabBar(in: view.window?.rootViewController) else { return }
            let frame = tabBar.convert(tabBar.bounds, to: nil)
            onChange(frame)
        }
    }

    private static func tabBar(in controller: UIViewController?) -> UITabBar? {
        guard let controller else { return nil }
        if let tabs = controller as? UITabBarController { return tabs.tabBar }
        for child in controller.children {
            if let found = tabBar(in: child) { return found }
        }
        return nil
    }
}
