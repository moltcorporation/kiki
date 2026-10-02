import SwiftUI

// Lists: one row anatomy everywhere (workouts, profile, settings, runs,
// goal details, the onboarding summary). A circled icon, a title
// (semibold for content, regular for settings), optional gray subtitles,
// an optional gray value, and a chevron when the row opens something.
// Rows go in a `ListCard`, which adds the dividers.

enum RowMetrics {
    static let horizontalPadding: CGFloat = Spacing.l
    static let verticalPadding: CGFloat = Spacing.m
    static let iconSize: CGFloat = 36
    static let spacing: CGFloat = Spacing.m
    /// Where row text starts, for inset dividers.
    static let textInset: CGFloat = horizontalPadding + iconSize + spacing
}

/// A white card holding rows, with an inset divider between each one.
/// Conditional rows and `ForEach` work; dividers follow what's shown.
struct ListCard<Content: View>: View {
    var dividerInset: CGFloat = RowMetrics.textInset
    /// Extra space above the first row and below the last, for rows that
    /// sit close to their edges (e.g. the Plan tab's day rows).
    var verticalPadding: CGFloat = 0
    /// Off when the rows sit inside another card (no surface or shadow).
    var isCard = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    row
                    if row.id != rows.last?.id {
                        Divider().padding(.leading, dividerInset)
                    }
                }
            }
        }
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isCard {
                Color.surface
                    .clipShape(.rect(cornerRadius: Radius.card))
                    .elevation(.card)
            }
        }
    }
}

/// The standard row layout. Wrap it in a `Button` or `NavigationLink`
/// (with `.buttonStyle(.haptic)`) when it's tappable.
struct ListRow<Trailing: View>: View {
    enum Emphasis {
        /// Semibold title: things (a workout, a goal, a run).
        case content
        /// Medium title: lighter content rows (Learn articles).
        case medium
        /// Regular title: settings labels.
        case setting
    }

    var icon: String?
    let title: Text
    var subtitles: [String] = []
    var value: String?
    var emphasis: Emphasis = .content
    var isDestructive = false
    var showsChevron = false
    let trailing: Trailing

    init(
        icon: String? = nil,
        title: Text,
        subtitles: [String] = [],
        value: String? = nil,
        emphasis: Emphasis = .content,
        isDestructive: Bool = false,
        showsChevron: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitles = subtitles
        self.value = value
        self.emphasis = emphasis
        self.isDestructive = isDestructive
        self.showsChevron = showsChevron
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: RowMetrics.spacing) {
            if let icon {
                RowIcon(systemName: icon, isDestructive: isDestructive)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title
                    .font(emphasis == .content ? .rowTitle : emphasis == .medium ? .body.weight(.medium) : .body)
                    .foregroundStyle(isDestructive ? Color.destructive : Color.ink)
                    .multilineTextAlignment(.leading)
                ForEach(subtitles, id: \.self) { line in
                    Text(line)
                        .font(.detail)
                        .foregroundStyle(.muted)
                }
            }
            Spacer(minLength: Spacing.m)
            if let value {
                Text(value)
                    .font(.body)
                    .foregroundStyle(.muted)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            trailing
            if showsChevron {
                RowChevron()
            }
        }
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .padding(.vertical, RowMetrics.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

extension ListRow where Trailing == EmptyView {
    init(
        icon: String? = nil,
        title: Text,
        subtitles: [String] = [],
        value: String? = nil,
        emphasis: Emphasis = .content,
        isDestructive: Bool = false,
        showsChevron: Bool = false
    ) {
        self.init(icon: icon, title: title, subtitles: subtitles, value: value, emphasis: emphasis,
                  isDestructive: isDestructive, showsChevron: showsChevron) { EmptyView() }
    }
}

/// A tappable settings row: icon, regular label, gray value, chevron.
/// Destructive rows are red with no chevron.
struct SettingsRow: View {
    let icon: String
    let label: LocalizedStringKey
    var value: String?
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            ListRow(
                icon: icon,
                title: Text(label),
                value: value,
                emphasis: .setting,
                isDestructive: role == .destructive,
                showsChevron: role != .destructive
            )
        }
        .buttonStyle(.haptic)
    }
}

/// A settings row with a switch instead of a chevron.
struct SettingsToggleRow: View {
    let icon: String
    let label: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        ListRow(icon: icon, title: Text(label), emphasis: .setting) {
            Toggle(isOn: $isOn) { Text(label) }
                .labelsHidden()
                .tint(.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

/// An outlined glyph in a light circle: the icon style for every row.
struct RowIcon: View {
    enum Size {
        case small, regular, large

        var points: CGFloat {
            switch self {
            case .small: 32
            case .regular: RowMetrics.iconSize
            case .large: 44
            }
        }
    }

    let systemName: String
    var isDestructive = false
    var size: Size = .regular

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size.points * 0.42, weight: .medium))
            .foregroundStyle(isDestructive ? Color.destructive : Color.ink)
            .frame(width: size.points, height: size.points)
            .background(isDestructive ? Color.destructive.opacity(0.1) : Color.wash, in: .circle)
            .accessibilityHidden(true)
    }
}

/// The trailing chevron on rows that open something.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

/// A benefit or fact on its own line, outside a card: circled icon + text.
struct InfoRow: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: RowMetrics.spacing) {
            RowIcon(systemName: symbol)
            Text(text).font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A list of `InfoRow`s with standard spacing.
struct InfoList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            content
        }
    }
}
