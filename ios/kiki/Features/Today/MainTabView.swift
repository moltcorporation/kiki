import SwiftUI

struct MainTabView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker
    @State private var tab: AppTab = .today

    enum AppTab: Hashable { case today, plan, run, learn, you }

    var body: some View {
        @Bindable var tracker = tracker
        // The run button never becomes the selection: the setter opens the
        // tracker instead, so the tab bar's highlight doesn't jump to it.
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
            // Not a page: tapping it starts a run (see the selection binding).
            Tab(value: .run) {
                Color.clear
            } label: {
                Image(uiImage: Self.runIcon)
                    .accessibilityLabel("Start a run")
            }
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
        .onChange(of: tab) { Haptics.select() }
        .background(RunButtonCatcher { startRun() })
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
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = (filled ? UIImage(systemName: symbol + ".fill", withConfiguration: configuration) : nil)
            ?? UIImage(systemName: symbol, withConfiguration: configuration)
            ?? UIImage()
        // Template, so the tab bar still tints selected and unselected.
        return image.withRenderingMode(.alwaysTemplate)
    }

    /// The tab bar's run button: a white play glyph on a black circle, drawn
    /// in its own colors so the tab bar doesn't tint it.
    static let runIcon: UIImage = {
        let size = CGSize(width: 46, height: 46)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor(red: 0x15 / 255, green: 0x18 / 255, blue: 0x1D / 255, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            let play = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            if let play {
                // Nudged right so the triangle looks centered.
                let origin = CGPoint(x: (size.width - play.size.width) / 2 + 2, y: (size.height - play.size.height) / 2)
                play.draw(at: origin)
            }
        }
        return image.withRenderingMode(.alwaysOriginal)
    }()

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

/// Catches taps on the tab bar's run button before the tab bar sees them,
/// so its selection highlight never slides over to it: a clear control laid
/// over the middle tab item, inside the tab bar (so it hides with it).
private struct RunButtonCatcher: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        let action = action
        DispatchQueue.main.async {
            guard let tabBar = Self.tabBar(in: view.window?.rootViewController) else { return }
            if let catcher = tabBar.subviews.compactMap({ $0 as? CatcherControl }).first {
                catcher.action = action
                return
            }
            let catcher = CatcherControl()
            catcher.action = action
            catcher.isAccessibilityElement = false
            catcher.translatesAutoresizingMaskIntoConstraints = false
            tabBar.addSubview(catcher)
            NSLayoutConstraint.activate([
                catcher.centerXAnchor.constraint(equalTo: tabBar.centerXAnchor),
                catcher.topAnchor.constraint(equalTo: tabBar.topAnchor),
                catcher.bottomAnchor.constraint(equalTo: tabBar.safeAreaLayoutGuide.bottomAnchor),
                catcher.widthAnchor.constraint(equalToConstant: 64),
            ])
        }
    }

    private static func tabBar(in controller: UIViewController?) -> UITabBar? {
        guard let controller else { return nil }
        if let tabs = controller as? UITabBarController { return tabs.tabBar }
        for child in controller.children {
            if let found = tabBar(in: child) { return found }
        }
        return tabBar(in: controller.presentedViewController)
    }

    final class CatcherControl: UIControl {
        var action: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            addAction(UIAction { [weak self] _ in self?.action?() }, for: .touchUpInside)
        }

        required init?(coder: NSCoder) { fatalError() }
    }
}
