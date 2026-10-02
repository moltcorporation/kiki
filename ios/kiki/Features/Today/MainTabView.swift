import SwiftUI

struct MainTabView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker
    @State private var tab: AppTab = .today

    enum AppTab: Hashable { case today, plan, run, learn, you }

    var body: some View {
        @Bindable var tracker = tracker
        TabView(selection: $tab) {
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
            // Not a page: tapping it starts a run (see onChange below).
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
        .onChange(of: tab) { old, new in
            if new == .run {
                // Stay on the current tab and open the tracker.
                tab = old
                startRun()
                return
            }
            Haptics.select()
        }
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
    /// Outline icons, filled only for the selected tab.
    func tabLabel(_ title: LocalizedStringKey, _ symbol: String, _ value: AppTab) -> some View {
        Label(title, systemImage: symbol)
            .environment(\.symbolVariants, tab == value ? .fill : .none)
    }

    /// The tab bar's run button: a Volt play glyph on a black circle, drawn
    /// in its own colors so the tab bar doesn't tint it.
    static let runIcon: UIImage = {
        let size = CGSize(width: 46, height: 46)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor(Color.onHighlight).setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            let play = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold))?
                .withTintColor(UIColor(Color.highlight), renderingMode: .alwaysOriginal)
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
