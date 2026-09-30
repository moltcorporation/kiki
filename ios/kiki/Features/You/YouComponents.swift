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
                HStack(spacing: RowMetrics.spacing) {
                    RowIcon(systemName: icon, isDestructive: role == .destructive)
                    Text(label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(role == .destructive ? Color.red : Color.ink)
                    Spacer(minLength: 12)
                    if let value {
                        Text(value)
                            .foregroundStyle(.muted)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                    if role != .destructive {
                        RowChevron()
                    }
                }
                .foregroundStyle(role == .destructive ? Color.red : Color.ink)
                .padding(.horizontal, RowMetrics.horizontalPadding)
                .padding(.vertical, RowMetrics.verticalPadding)
                .contentShape(.rect)
            }
            .buttonStyle(.haptic)
            if showsDivider { Divider().padding(.leading, RowMetrics.textInset) }
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
                HStack(spacing: RowMetrics.spacing) {
                    RowIcon(systemName: icon)
                    Text(label).font(.body.weight(.semibold))
                }
            }
            .tint(.ink)
            .padding(.horizontal, RowMetrics.horizontalPadding)
            .padding(.vertical, RowMetrics.verticalPadding - 2)
            if showsDivider { Divider().padding(.leading, RowMetrics.textInset) }
        }
    }
}
