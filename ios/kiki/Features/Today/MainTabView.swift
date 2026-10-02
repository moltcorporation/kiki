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
            // The run button: the search role gives it iOS's own floating
            // circle beside the bar. It's not a page: selecting it starts a
            // run instead (see the selection binding).
            Tab(value: .run, role: .search) {
                Color.clear
            } label: {
                Label {
                    Text("Start a run")
                } icon: {
                    Image(uiImage: Self.runIcon)
                }
            }
        }
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

    /// The run button: a Volt play triangle on a black circle that fills
    /// iOS's floating glass circle, drawn in its own colors so the tab bar
    /// doesn't tint it.
    static let runIcon: UIImage = {
        let size = CGSize(width: 60, height: 60)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor(Color.onHighlight).setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            let play = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))?
                .withTintColor(UIColor(Color.highlight), renderingMode: .alwaysOriginal)
            if let play {
                // Nudged right so the triangle looks centered.
                play.draw(at: CGPoint(x: (size.width - play.size.width) / 2 + 1.5, y: (size.height - play.size.height) / 2))
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
