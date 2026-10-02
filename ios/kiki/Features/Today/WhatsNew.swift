import SwiftUI

/// Home's "What's new": two square tiles (the launch note and a feedback
/// prompt), each opening a short bottom sheet.
struct WhatsNewSection: View {
    private enum Item: String, Identifiable {
        case launch, feedback
        var id: String { rawValue }
    }

    @State private var item: Item?

    var body: some View {
        PageSection("What's new") {
            HStack(spacing: Metrics.stackSpacing) {
                NewsTile(icon: "sparkles", title: "Kiki launch", subtitle: "Read the news") {
                    item = .launch
                }
                NewsTile(icon: "bubble.left.and.text.bubble.right", title: "Send feedback", subtitle: "Help shape Kiki") {
                    item = .feedback
                }
            }
        }
        .sheet(item: $item) { item in
            switch item {
            case .launch: LaunchSheet()
            case .feedback: FeedbackSheet()
            }
        }
        .onChange(of: item) { _, item in
            if let item { Analytics.track("whats_new_opened", ["item": item.rawValue]) }
        }
    }
}

/// A square tile: icon at the top, title and subtitle at the bottom.
private struct NewsTile: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                RowIcon(systemName: icon)
                Spacer(minLength: Spacing.l)
                Text(title)
                    .font(.rowTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.detail)
                    .foregroundStyle(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, Spacing.xxs)
            }
            .foregroundStyle(.ink)
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(1.15, contentMode: .fit)
            .elevatedCard()
            .contentShape(.rect(cornerRadius: Radius.card))
        }
        .buttonStyle(.haptic)
        .accessibilityElement(children: .combine)
    }
}

/// The launch announcement.
private struct LaunchSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CompactSheet("Welcome to Kiki") {
            Text("Kiki is your AI running coach: a plan built around your goal that adapts as you train. Tired, busy or sore? Tap Adjust plan and Kiki reworks your week.\n\nThis is just the start. More is on the way.")
                .font(.body)
                .foregroundStyle(.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("Let's run") { dismiss() }
                .padding(.top, Spacing.s)
        }
    }
}

/// Asks for feedback and opens an email to the team.
private struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        CompactSheet("Send feedback") {
            Text("Kiki is brand new, and your feedback shapes what we build next. Tell us what's working, what isn't, or what you'd love to see. We read every message.")
                .font(.body)
                .foregroundStyle(.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Spacing.xs) {
                PrimaryButton("Send feedback", systemImage: "envelope") {
                    Analytics.track("feedback_email_opened")
                    if let url = URL(string: "mailto:\(Config.supportEmail)?subject=Kiki%20feedback") {
                        openURL(url)
                    }
                    dismiss()
                }
                TextButton("Not now") { dismiss() }
            }
            .padding(.top, Spacing.s)
        }
    }
}
