import SwiftUI

struct OnboardingFlow: View {
    @Environment(OnboardingModel.self) private var model
    @State private var isForward = true

    var body: some View {
        ZStack {
            step(model.current)
                .id(model.current)
                .transition(.asymmetric(
                    insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)
                ))
        }
        .animation(.snappy(duration: 0.35), value: model.current)
        .onChange(of: model.path.count) { old, new in
            isForward = new >= old
        }
        .onChange(of: model.current) { _, step in
            Analytics.screen("Onboarding", ["step": step.rawValue])
        }
    }

    @ViewBuilder
    private func step(_ step: OnboardingModel.Step) -> some View {
        switch step {
        case .distance: DistanceStep()
        case .raceDate: RaceDateStep()
        case .experience: ExperienceStep()
        case .weeklyVolume: WeeklyVolumeStep()
        case .longestRun: LongestRunStep()
        case .goal: GoalStep()
        case .goalTime: GoalTimeStep()
        case .recentRace: RecentRaceStep()
        case .adaptInfo: AdaptInfoStep()
        case .runDays: RunDaysStep()
        case .longRunDay: LongRunDayStep()
        case .name: NameStep()
        case .age: AgeStep()
        case .body: BodyStep()
        case .injury: InjuryStep()
        case .notifications: NotificationsStep()
        case .account: AccountStep()
        case .generating: GeneratingStep()
        case .preview: PlanPreviewStep()
        }
    }
}
