import Foundation

/// Where today falls in a plan, shared by Home's goal card and the Plan
/// tab's progress ring so they always agree (before, during, on the goal
/// day, and after it).
struct PlanTimeline {
    enum Phase { case underway, goalDay, finished }

    /// The goal day: the race or time-trial workout, else the plan's end.
    let endDate: Day
    /// Days until the goal day (0 on it, never negative).
    let daysLeft: Int
    /// 0…1 by days from the plan's start to the goal day.
    let progress: Double
    let phase: Phase
    /// The current week, or the last one once the plan is over.
    let week: Int
    let totalWeeks: Int

    init(plan: Plan, store: TrainingStore, today: Day = .today) {
        endDate = store.workouts.last { $0.type == .race }?.date ?? plan.raceDate
        let days = today.days(until: endDate)
        daysLeft = max(0, days)
        phase = days > 0 ? .underway : days == 0 ? .goalDay : .finished
        let planDays = max(plan.startDate.days(until: endDate), 1)
        progress = min(max(Double(plan.startDate.days(until: today)) / Double(planDays), 0), 1)
        totalWeeks = max(store.totalWeeks, 1)
        week = phase == .finished ? totalWeeks : min(store.currentWeekNumber ?? totalWeeks, totalWeeks)
    }
}
