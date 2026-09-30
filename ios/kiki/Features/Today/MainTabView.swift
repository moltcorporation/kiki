import SwiftUI

struct MainTabView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker
    @State private var tab: AppTab = .today

    enum AppTab: Hashable { case today, plan, you }

    var body: some View {
        @Bindable var tracker = tracker
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house.fill", value: .today) {
                TodayView()
            }
            Tab("Plan", systemImage: "calendar", value: .plan) {
                PlanView()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .you) {
                YouView()
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
                AdjustPlanView()
            }
        }
    }
}
