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

    // The type scale for titles. Use these instead of per-screen sizes.

    /// Full-screen titles: onboarding questions, gates, status screens.
    static let screenTitle = Font.system(.largeTitle, weight: .bold)
    /// Titles at the top of sheets.
    static let sheetTitle = Font.system(.title3, weight: .bold)
    /// Titles of sections and cards within a screen.
    static let sectionTitle = Font.system(.title3, weight: .bold)
}

/// Shared control sizes.
enum Metrics {
    /// Height of full-width primary and secondary buttons.
    static let buttonHeight: CGFloat = 56
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

/// Full-width black pill used for primary actions (including Sign in with
/// Apple, with the Apple logo as its icon).
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, isLoading: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: 6) {
                    if let systemImage { Image(systemName: systemImage) }
                    Text(title)
                }
                .opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.paper) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            .foregroundStyle(.paper)
            .background(isEnabled ? Color.ink : Color.secondary.opacity(0.35), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.haptic)
        .disabled(!isEnabled || isLoading)
        .animation(.snappy, value: isEnabled)
    }
}

/// Full-width translucent pill for the secondary action next to a
/// `PrimaryButton` (same size, quieter).
struct SecondaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.ink)
                .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                .background(Color.ink.opacity(0.14), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.haptic)
    }
}

/// Selectable card used throughout onboarding: a light card with a radio (or
/// checkbox) on the right; the selected card gets an ink outline.
struct OptionCard: View {
    enum Indicator { case radio, checkbox }

    let title: String
    var subtitle: String?
    var icon: String?
    /// 1–4: draws an ability ring that fills with the level.
    var level: Int?
    var indicator: Indicator = .radio
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 16) {
                if let level {
                    LevelRing(level: level)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                SelectionIndicator(style: indicator, isSelected: isSelected)
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, subtitle == nil ? 20 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.wash, in: .rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.ink : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SelectionIndicator: View {
    let style: OptionCard.Indicator
    let isSelected: Bool

    var body: some View {
        Group {
            switch style {
            case .radio:
                ZStack {
                    Circle().stroke(isSelected ? Color.ink : Color.secondary.opacity(0.35), lineWidth: isSelected ? 2 : 1.5)
                    if isSelected { Circle().fill(Color.ink).padding(6) }
                }
            case .checkbox:
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.ink : .clear)
                    .stroke(isSelected ? Color.ink : Color.secondary.opacity(0.35), lineWidth: 1.5)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.paper)
                        }
                    }
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}

/// Ring that fills a quarter per level (1–4).
private struct LevelRing: View {
    let level: Int

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.1), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(level, 1), 4)) / 4)
                .stroke(Color.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
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

/// The app icon artwork as an in-app avatar (e.g. the coach in chats).
struct KikiLogo: View {
    var size: CGFloat = 64

    var body: some View {
        Image(.kikiIcon)
            .resizable()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
            .accessibilityLabel("Kiki")
    }
}
