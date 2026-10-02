import SwiftUI

/// Hosts the onboarding screens. The back button and progress bar stay fixed
/// while each screen slides in from the direction of travel.
struct OnboardingFlow: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if model.showsHeader {
                OnboardingHeader(step: model.stepPosition.step, total: model.stepPosition.total, canGoBack: model.canGoBack) {
                    model.back()
                }
                .transition(.opacity)
            }

            ZStack {
                step(model.current)
                    .id(model.current)
                    .transition(.push(from: model.direction == .forward ? .trailing : .leading))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .background { PageBackground() }
        .animation(.snappy(duration: 0.35), value: model.current)
        .onChange(of: model.current) { _, step in
            Analytics.screen("Onboarding", ["step": step.rawValue])
        }
    }

    @ViewBuilder
    private func step(_ step: OnboardingModel.Step) -> some View {
        switch step {
        case .goal: GoalStep()
        case .units: UnitsStep()
        case .distance: DistanceStep()
        case .raceDate: RaceDateStep()
        case .raceGoal: RaceGoalStep()
        case .goalTime: GoalTimeStep()
        case .timeframe: TimeframeStep()
        case .experience: ExperienceStep()
        case .weeklyVolume: WeeklyVolumeStep()
        case .runDays: RunDaysStep()
        case .coachingStyle: CoachingStyleStep()
        case .goalCheck: GoalCheckStep()
        case .name: NameStep()
        case .health: HealthStep()
        case .age: AgeStep()
        case .height: HeightStep()
        case .weight: WeightStep()
        case .flexibility: FlexibilityStep()
        case .referral: ReferralStep()
        case .notifications: NotificationsStep()
        case .summary: SummaryStep()
        case .account: AccountStep()
        case .generating: GeneratingStep()
        case .preview: PlanPreviewStep()
        }
    }
}
