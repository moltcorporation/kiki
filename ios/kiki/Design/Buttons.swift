import SwiftUI

// Buttons, by importance:
//   PrimaryButton    the one main action on a screen (black pill)
//   SecondaryButton  an alternative beside or below it (white pill, hairline)
//   TextButton       a quiet way out: Skip, Not now, Sign out
//   CircleButton     an icon-only action beside a pill (Start GPS run)
// Pills are 56pt tall, or 48pt inside cards with `.controlSize(.small)`.
// Every button plays a light haptic on press. Custom tappable views (cards,
// rows) use `.buttonStyle(.haptic)`.

/// Plays a light haptic and shrinks slightly on press.
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

/// Pill height for the current control size.
private struct PillHeight: ViewModifier {
    @Environment(\.controlSize) private var controlSize

    func body(content: Content) -> some View {
        content.frame(
            maxWidth: .infinity,
            minHeight: controlSize == .small || controlSize == .mini ? Metrics.compactButtonHeight : Metrics.buttonHeight
        )
    }
}

/// Full-width black pill for the main action (including Sign in with Apple,
/// with the Apple logo as its icon). White on dark cards.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    var isEnabled = true
    /// The highlight fill (volt) for the signature action, Start run.
    var isHighlighted = false
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, isLoading: Bool = false, isEnabled: Bool = true, isHighlighted: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.isHighlighted = isHighlighted
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: Spacing.s) {
                    if let systemImage { Image(systemName: systemImage) }
                    Text(title)
                }
                .opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(isHighlighted ? .onHighlight : .paper) }
            }
            .font(.button)
            .modifier(PillHeight())
            .foregroundStyle(isHighlighted ? Color.onHighlight : Color.paper)
            .background(!isEnabled ? Color.ink.opacity(0.25) : isHighlighted ? Color.highlight : Color.ink, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.haptic)
        .disabled(!isEnabled || isLoading)
        .animation(.snappy, value: isEnabled)
    }
}

/// Full-width pill for the alternative to a `PrimaryButton`: same size,
/// quieter (a white surface with a hairline, like a control).
struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.button)
            .foregroundStyle(.ink)
            .modifier(PillHeight())
            .background(Color.surface, in: .capsule)
            .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 1))
            .contentShape(.capsule)
        }
        .buttonStyle(.haptic)
    }
}

/// A quiet full-width text button (Skip, Not now, Sign out), 44pt tall.
struct TextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.muted)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.haptic)
    }
}

/// A round icon button the height of a pill, styled like `SecondaryButton`.
struct CircleButton: View {
    @Environment(\.controlSize) private var controlSize
    let systemImage: String
    let label: LocalizedStringKey
    let action: () -> Void

    init(_ label: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        let size = controlSize == .small || controlSize == .mini ? Metrics.compactButtonHeight : Metrics.buttonHeight
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.button)
                .foregroundStyle(.ink)
                .frame(width: size, height: size)
                .background(Color.surface, in: .circle)
                .overlay(Circle().strokeBorder(Color.hairline, lineWidth: 1))
                .contentShape(.circle)
        }
        .buttonStyle(.haptic)
        .accessibilityLabel(label)
    }
}

/// The round back button at the top of full-screen flows. Quiet so the
/// title leads; the tap area is still 44pt.
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.callout)
                .foregroundStyle(.muted)
                .frame(width: 36, height: 36)
                .background(Color.surface, in: .circle)
                .overlay(Circle().strokeBorder(Color.hairline, lineWidth: 1))
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .contentShape(.circle)
        }
        .buttonStyle(.haptic)
        .accessibilityLabel("Back")
    }
}
