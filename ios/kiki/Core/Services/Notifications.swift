import Foundation
import UserNotifications

/// Local notifications: the trial reminder and daily workout reminders.
enum Notifications {
    private static let center = UNUserNotificationCenter.current()
    private static let trialReminderID = "trial-reminder"
    private static let workoutPrefix = "workout-"

    static func requestPermission() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        Analytics.track("notifications_permission", ["granted": granted])
        return granted
    }

    static func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return [.authorized, .provisional].contains(settings.authorizationStatus)
    }

    /// Reminds the runner on day 5 that their 7-day free trial ends in 2 days.
    static func scheduleTrialReminder(trialStart: Date = .now, planName: String) async {
        guard await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends in 2 days"
        content.body = "You're on the \(planName) plan. Keep training with Kiki, or cancel anytime in Settings."
        content.sound = .default

        let fireDate = Calendar.current.date(byAdding: .day, value: 5, to: trialStart)!
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: trialReminderID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    /// Schedules a morning reminder for each upcoming run over the next two weeks.
    static func scheduleWorkoutReminders(_ workouts: [Workout], units: Units, hour: Int = 7) async {
        await cancelWorkoutReminders()
        let enabled = UserDefaults.standard.object(forKey: "reminders.enabled") as? Bool ?? true
        guard enabled, await isAuthorized() else { return }

        let today = Day.today
        let upcoming = workouts
            .filter { !$0.isRest && $0.status == .planned && $0.date >= today && $0.date < today.adding(days: 14) }
            .prefix(14)

        for workout in upcoming {
            var components = DateComponents(year: workout.date.year, month: workout.date.month, day: workout.date.day)
            components.hour = hour
            guard let fire = Calendar.current.date(from: components), fire > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Today: \(workout.title)"
            content.body = Format.workoutSummary(workout, units: units)
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: workoutPrefix + workout.date.description,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    static func cancelWorkoutReminders() async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(workoutPrefix) })
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
