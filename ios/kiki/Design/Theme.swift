import SwiftUI
import UIKit

extension Font {
    /// Heavy italic display type that echoes the Kiki logo.
    static func display(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .default, weight: .black).italic()
    }

    /// Big numbers (distances, paces, times).
    static func metric(_ style: Font.TextStyle = .title) -> Font {
        .system(style, design: .default, weight: .heavy).italic().monospacedDigit()
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// Plays a light haptic on every press for a premium, tactile feel.
struct HapticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

extension ButtonStyle where Self == HapticButtonStyle {
    static var haptic: HapticButtonStyle { HapticButtonStyle() }
}

/// Full-width black pill used for primary actions.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    init(_ title: LocalizedStringKey, isLoading: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.paper) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.paper)
            .background(isEnabled ? Color.ink : Color.secondary.opacity(0.35), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.haptic)
        .disabled(!isEnabled || isLoading)
        .animation(.snappy, value: isEnabled)
    }
}

/// Selectable row used throughout onboarding and pickers.
struct OptionCard: View {
    let title: String
    var subtitle: String?
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(isSelected ? Color.paper.opacity(0.7) : .secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 20)
            .padding(.vertical, subtitle == nil ? 20 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isSelected ? Color.paper : Color.ink)
            .background(isSelected ? Color.ink : Color.wash, in: .rect(cornerRadius: 20))
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A rounded surface for grouping content.
struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.wash, in: .rect(cornerRadius: 24))
    }
}

struct KikiLogo: View {
    var size: CGFloat = 64

    var body: some View {
        Text("K")
            .font(.system(size: size * 0.62, weight: .black).italic())
            .foregroundStyle(.paper)
            .frame(width: size, height: size)
            .background(Color.ink, in: .rect(cornerRadius: size * 0.28))
            .accessibilityLabel("Kiki")
    }
}
