import Foundation

/// Limited access (no Kiki Pro): the app works, but the plan is visible for
/// the first week only, and the AI features (adjusting the plan or a day,
/// changing the goal) and sharing need Pro. Locked spots open the paywall.
extension Plan {
    /// The last day free users can see: the end of the plan's first
    /// Monday-based week, or of the second when the plan starts late in the
    /// week (so there are always a few days to try).
    var freeThrough: Day {
        let sunday = startDate.mondayOfWeek.adding(days: 6)
        return startDate.days(until: sunday) < 3 ? sunday.adding(days: 7) : sunday
    }
}

extension Subscriptions {
    /// Whether this day of the plan is behind the paywall.
    func isLocked(_ day: Day, plan: Plan?) -> Bool {
        guard !hasAccess, let plan else { return false }
        return day > plan.freeThrough
    }
}
