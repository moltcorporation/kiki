import SwiftUI

struct MainTabView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(RunTracker.self) private var tracker
    @State private var tab: AppTab = .today

    enum AppTab: Hashable { case today, plan, progress }

    var body: some View {
        @Bindable var tracker = tracker
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sun.max.fill", value: .today) {
                TodayView()
            }
            Tab("Plan", systemImage: "calendar", value: .plan) {
                PlanView()
            }
            Tab("Progress", systemImage: "chart.bar.fill", value: .progress) {
                ProgressScreen()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
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
    case settings

    var id: String {
        switch self {
        case .log(let workout, let run): "log-\(workout?.id.uuidString ?? "")-\(run?.id.uuidString ?? "")"
        case .adjust: "adjust"
        case .settings: "settings"
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
            case .settings:
                SettingsView()
            }
        }
    }

    func settingsToolbar(_ sheet: Binding<AppSheet?>) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "person.crop.circle") {
                    sheet.wrappedValue = .settings
                }
            }
        }
    }
}
