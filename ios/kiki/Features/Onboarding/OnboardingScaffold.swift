import SwiftUI

/// Shared layout for onboarding questions: back button + progress, a large
/// title, the question content, and an optional pinned Continue button.
struct OnboardingScaffold<Content: View>: View {
    @Environment(OnboardingModel.self) private var model

    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var continueTitle: LocalizedStringKey = "Continue"
    var canContinue = true
    var showsContinue = true
    var onContinue: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(progress: model.progress, canGoBack: model.path.count > 1) {
                model.back()
            }

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
                PrimaryButton(continueTitle, isEnabled: canContinue) {
                    (onContinue ?? model.advance)()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .background(Color.paper)
            }
        }
        .background(Color.paper)
    }
}

struct OnboardingHeader: View {
    let progress: Double
    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.wash, in: .circle)
            }
            .buttonStyle(.haptic)
            .foregroundStyle(.ink)
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)
            .accessibilityLabel("Back")

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.wash)
                    Capsule().fill(Color.ink)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 4)
            .animation(.snappy, value: progress)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

/// A single-choice list that advances to the next step after a selection.
struct ChoiceList<Value: Hashable>: View {
    @Environment(OnboardingModel.self) private var model

    let options: [(value: Value, title: String, subtitle: String?, icon: String?)]
    let selection: Value?
    let onSelect: (Value) -> Void
    var autoAdvance = true

    var body: some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.value) { option in
                OptionCard(
                    title: option.title,
                    subtitle: option.subtitle,
                    icon: option.icon,
                    isSelected: selection == option.value
                ) {
                    onSelect(option.value)
                    guard autoAdvance else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        model.advance()
                    }
                }
            }
        }
    }
}
