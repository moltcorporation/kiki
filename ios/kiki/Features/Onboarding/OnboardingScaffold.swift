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
                        .font(.system(.largeTitle, weight: .bold))
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

/// Back arrow above a segmented bar: one segment per question, filled up to
/// the current one, so runners can see how far along they are.
struct OnboardingHeader: View {
    let step: Int
    let total: Int
    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.title3.weight(.medium))
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.haptic)
            .foregroundStyle(.ink)
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)
            .accessibilityLabel("Back")

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
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }
}
