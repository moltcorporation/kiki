import SwiftUI

struct MainTabView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker
    @State private var tab: AppTab = .today
    @State private var tabBar = TabBarState()

    enum AppTab: Hashable { case today, plan, run, learn, you }

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
            Tab(value: .learn) {
                LearnView()
            } label: {
                tabLabel("Learn", "book", .learn)
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
            RunTabButton(isHidden: tabBar.isHidden, action: startRun)
        }
        .environment(\.tabBarState, tabBar)
        .onChange(of: tab) { Haptics.select() }
        .fullScreenCover(isPresented: $tracker.isPresented) {
            RunTrackerView()
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

    /// Starts a run: linked to today's workout if there's one still to do,
    /// otherwise a free run (rest days, extra runs).
    func startRun() {
        Haptics.tap()
        let today = store.workouts.first { $0.date == .today && !$0.isRest && $0.status == .planned }
        tracker.start(for: today)
    }
}

/// Sheets that can be opened from any tab.
enum AppSheet: Identifiable {
    case log(Workout?, Run?)
    case adjust

    var id: String {
        switch self {
        case .log(let workout, let run): "log-\(workout?.id.uuidString ?? "")-\(run?.id.uuidString ?? "")"
        case .adjust: "adjust"
        }
    }
}

extension View {
    func appSheets(_ sheet: Binding<AppSheet?>) -> some View {
        self.sheet(item: sheet) { item in
            switch item {
            case .log(let workout, let run):
                LogRunView(workout: workout, existing: run)
            case .adjust:
                AdjustMenuSheet()
            }
        }
    }
}

/// The run button over the tab bar's middle slot: a black circle with a
/// Volt play triangle. Placed where the tab bar is (`TabBarFrameReader`)
/// and hidden with it on pushed screens.
private struct RunTabButton: View {
    let isHidden: Bool
    let action: () -> Void
    @State private var tabBarFrame: CGRect?
    private static let glassOffset: CGFloat = 11

    var body: some View {
        GeometryReader { proxy in
            if let frame = tabBarFrame {
                let origin = proxy.frame(in: .global).origin
                Button(action: action) {
                    Image(systemName: "play.fill")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(Color.highlight)
                        // Nudged right so the triangle looks centered.
                        .offset(x: 1.5)
                        .frame(width: 50, height: 50)
                        .background(Color.onHighlight, in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start a run")
                // The bar's frame runs into the home indicator area; its
                // visible glass is centered a little higher.
                .position(x: frame.midX - origin.x, y: frame.midY - origin.y - Self.glassOffset)
                .opacity(isHidden ? 0 : 1)
                .allowsHitTesting(!isHidden)
                .accessibilityHidden(isHidden)
            }
        }
        .ignoresSafeArea()
        .background(TabBarFrameReader { tabBarFrame = $0 })
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
