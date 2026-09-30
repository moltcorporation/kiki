import SwiftUI

/// Shared layout for onboarding questions: a large title, the question
/// content, and an optional pinned Continue button. The back button and
/// progress bar live in `OnboardingFlow` so they stay fixed between screens.
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
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.screenTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content
                        .padding(.top, 28)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            if showsContinue {
                VStack(spacing: 4) {
                    PrimaryButton(continueTitle, isEnabled: canContinue) {
                        (onContinue ?? model.advance)()
                    }
                    if let secondaryTitle {
                        Button(secondaryTitle) { (onSecondary ?? model.advance)() }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.haptic)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .background(Color.paper)
            }
        }
        .background(Color.paper)
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
        HStack(spacing: 14) {
            BackButton(action: onBack)
                // Keeps its space when hidden so the bar never shifts.
                .opacity(canGoBack ? 1 : 0)
                .disabled(!canGoBack)

            HStack(spacing: 5) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Capsule()
                        .fill(index < step ? Color.ink : Color.primary.opacity(0.1))
                        .frame(height: 4)
                }
            }
            .animation(.snappy, value: step)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("Step \(step) of \(total)")
        }
        // The 44pt tap area overhangs the circle by 2pt; this keeps the
        // circle itself on the 24pt margin.
        .padding(.leading, 22)
        .padding(.trailing, 24)
        .padding(.top, 4)
    }
}

/// The round back button used at the top of full-screen flows: a 40pt
/// circle in `wash` inside a 44pt tap area.
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(Color.wash, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.haptic)
        .foregroundStyle(.ink)
        .accessibilityLabel("Back")
    }
}
