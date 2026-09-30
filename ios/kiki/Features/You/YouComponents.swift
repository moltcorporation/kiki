import SwiftUI

// Building blocks for the Profile tab: rounded groups of rows in the same style
// as the onboarding summary, instead of a stock Settings list.

/// A titled group of rows on a rounded `wash` card.
struct PreferenceGroup<Content: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.sectionTitle)
            }
            VStack(spacing: 0) {
                content
            }
            .elevatedCard(cornerRadius: 24)
        }
    }
}

/// One tappable row: icon, label, current value and a chevron.
struct PreferenceRow: View {
    let icon: String
    let label: LocalizedStringKey
    var value: String?
    var role: ButtonRole?
    var showsDivider = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(role: role, action: action) {
                HStack(spacing: 14) {
                    RowIcon(systemName: icon, isDestructive: role == .destructive)
                    Text(label)
                        .foregroundStyle(role == .destructive ? Color.red : Color.ink)
                    Spacer(minLength: 12)
                    if let value {
                        Text(value)
                            .foregroundStyle(.muted)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                    if role != .destructive {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .foregroundStyle(role == .destructive ? Color.red : Color.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(.rect)
            }
            .buttonStyle(.haptic)
            if showsDivider { Divider().padding(.leading, 16 + 36 + 14) }
        }
    }
}

/// A row with a switch instead of a chevron.
struct PreferenceToggleRow: View {
    let icon: String
    let label: LocalizedStringKey
    @Binding var isOn: Bool
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isOn) {
                HStack(spacing: 14) {
                    RowIcon(systemName: icon)
                    Text(label)
                }
            }
            .tint(.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            if showsDivider { Divider().padding(.leading, 16 + 36 + 14) }
        }
    }
}

/// A row or tile icon: an outlined glyph in a light circle, the same style
/// as workout icons, so the whole app shares one icon look.
struct RowIcon: View {
    let systemName: String
    var isDestructive = false
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(isDestructive ? Color.red : Color.ink)
            .frame(width: size, height: size)
            .background((isDestructive ? Color.red.opacity(0.1) : Color.wash), in: .circle)
            .accessibilityHidden(true)
    }
}

/// One answer as a small card: icon, label, and the value large. Used in a
/// two-column grid for the runner's training and details.
struct PreferenceTile: View {
    let icon: String
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                RowIcon(systemName: icon, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.muted)
                    Text(value)
                        .font(.headline)
                        .foregroundStyle(.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            // One fixed height (room for a two-line value) so tiles in a row match.
            .frame(maxWidth: .infinity, minHeight: 136, maxHeight: 136, alignment: .topLeading)
            .elevatedCard(cornerRadius: 20)
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.haptic)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to change")
    }
}

/// A titled two-column grid of tiles.
struct TileGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        TabSection(title) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                content
            }
        }
    }
}
