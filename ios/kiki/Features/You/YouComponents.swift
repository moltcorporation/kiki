import SwiftUI

// Building blocks for the You tab: rounded groups of rows in the same style
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
                    .padding(.horizontal, 4)
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
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .frame(width: 28)
                        .accessibilityHidden(true)
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
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .contentShape(.rect)
            }
            .buttonStyle(.haptic)
            if showsDivider { Divider().padding(.leading, 60) }
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
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    Text(label)
                }
            }
            .tint(.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            if showsDivider { Divider().padding(.leading, 60) }
        }
    }
}
