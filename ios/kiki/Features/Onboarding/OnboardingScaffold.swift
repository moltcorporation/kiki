import SwiftUI

/// Shared layout for onboarding questions: a `FlowPage` with the Continue
/// button (and an optional text button like "Skip") pinned at the bottom.
/// The back button and progress bar live in `OnboardingFlow` so they stay
/// fixed between screens.
struct OnboardingScaffold<Content: View>: View {
    @Environment(OnboardingModel.self) private var model

    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var continueTitle: LocalizedStringKey = "Continue"
    var canContinue = true
    var showsContinue = true
    var onContinue: (() -> Void)?
    /// Optional text button under Continue, e.g. "Skip".
    var secondaryTitle: LocalizedStringKey?
    var onSecondary: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        FlowPage(title: title, subtitle: subtitle) {
            content
        } actions: {
            if showsContinue {
                PrimaryButton(continueTitle, isEnabled: canContinue) {
                    (onContinue ?? model.advance)()
                }
                if let secondaryTitle {
                    TextButton(secondaryTitle) { (onSecondary ?? model.advance)() }
                }
            }
        }
    }
}

/// A round back button beside a segmented bar: one segment per question,
/// filled up to the current one, so runners can see how far along they are.
struct OnboardingHeader: View {
    let step: Int
    let total: Int
    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            BackButton(action: onBack)
                // Keeps its space when hidden so the bar never shifts.
                .opacity(canGoBack ? 1 : 0)
                .disabled(!canGoBack)

            HStack(spacing: Spacing.xs) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Capsule()
                        .fill(index < step ? Color.ink : Color.track)
                        .frame(height: 4)
                }
            }
            .animation(.snappy, value: step)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("Step \(step) of \(total)")
        }
        // The 44pt tap area overhangs the 36pt circle by 4pt; this keeps the
        // circle itself on the screen margin.
        .padding(.leading, Metrics.screenMargin - 4)
        .padding(.trailing, Metrics.screenMargin)
        .padding(.top, Spacing.xs)
    }
}
