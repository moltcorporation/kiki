import SwiftUI

// Small content components: the logo, pills, metrics, chat bubbles and
// message cards.

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

/// A small ink capsule with a short label ("Today", "Save 50%").
struct Pill: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.paper)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Color.ink, in: .capsule)
    }
}

/// A big number with its unit below ("5.0" / "km").
struct MetricView: View {
    let value: String
    let label: String
    var style: Font.TextStyle = .largeTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.metric(style))
            Text(label).font(.caption).foregroundStyle(.muted)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A message from Kiki: the logo beside an ink bubble.
struct CoachBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.m) {
            KikiLogo(size: 32)
            Text(text)
                .foregroundStyle(.paper)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
                .background(Color.ink, in: .rect(cornerRadius: Radius.bubble))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, Spacing.xxxl)
    }
}

/// A message from the runner: a white bubble on the right.
struct UserBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .controlSurface(cornerRadius: Radius.bubble)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, Spacing.xxxl)
    }
}

/// A short status or empty state in a card: a bold line and a gray one,
/// with an optional icon.
struct MessageCard: View {
    var icon: String?
    let title: LocalizedStringKey
    var message: LocalizedStringKey?

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: RowMetrics.spacing) {
                if let icon { RowIcon(systemName: icon) }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title).font(.rowTitle)
                    if let message {
                        Text(message).font(.detail).foregroundStyle(.muted)
                    }
                }
                .frame(minHeight: icon == nil ? 0 : RowMetrics.iconSize)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A card's footer: a hairline, then two (or more) equal actions split by
/// short hairlines, each an icon and a label ("Adjust plan | View plan").
struct CardActions: View {
    struct Action: Identifiable {
        let id = UUID()
        let title: LocalizedStringKey
        let systemImage: String
        let perform: () -> Void

        init(_ title: LocalizedStringKey, systemImage: String, perform: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.perform = perform
        }
    }

    let actions: [Action]

    init(_ actions: Action...) {
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.hairline).frame(height: 1)
            HStack(spacing: 0) {
                ForEach(actions) { action in
                    if action.id != actions.first?.id {
                        Rectangle().fill(Color.hairline).frame(width: 1, height: Spacing.xl)
                    }
                    Button(action: action.perform) {
                        Label(action.title, systemImage: action.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.ink)
                            .frame(maxWidth: .infinity, minHeight: Metrics.compactButtonHeight)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.haptic)
                }
            }
        }
    }
}
