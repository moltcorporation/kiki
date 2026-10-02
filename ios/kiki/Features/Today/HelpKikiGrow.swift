import SwiftUI

/// The end of Home: "Help Kiki grow", a row of compact tiles that scrolls
/// sideways (share feedback, leave a review, invite a friend).
struct HelpKikiGrowSection: View {
    @Environment(\.openURL) private var openURL
    @State private var showFeedback = false

    var body: some View {
        PageSection("Help Kiki grow") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.stackSpacing) {
                    Button {
                        showFeedback = true
                        Analytics.track("help_kiki_grow_tapped", ["item": "feedback"])
                    } label: {
                        GrowTile(icon: "bubble.left.and.text.bubble.right", title: "Share feedback", subtitle: "Help shape Kiki")
                    }
                    .buttonStyle(.haptic)

                    Button {
                        Analytics.track("help_kiki_grow_tapped", ["item": "review"])
                        openURL(Config.writeReviewURL)
                    } label: {
                        GrowTile(icon: "star", title: "Leave a review", subtitle: "On the App Store")
                    }
                    .buttonStyle(.haptic)
                    ShareLink(
                        item: Config.appStoreURL,
                        message: Text("I'm training with Kiki, an AI running coach that builds your plan around your goal. Try it:")
                    ) {
                        GrowTile(icon: "person.2", title: "Invite a friend", subtitle: "Run together")
                    }
                    .buttonStyle(.haptic)
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track("help_kiki_grow_tapped", ["item": "invite"])
                    })

                }
                // Room for the cards' shadows inside the scroll view.
                .padding(.vertical, Spacing.l)
            }
            // Scroll edge to edge, starting on the page margin.
            .contentMargins(.horizontal, Metrics.screenMargin, for: .scrollContent)
            .padding(.horizontal, -Metrics.screenMargin)
            .padding(.vertical, -Spacing.l)
        }
        .sheet(isPresented: $showFeedback) { FeedbackSheet() }
    }
}

/// A compact tile: icon at the top, title and subtitle at the bottom.
private struct GrowTile: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    static let width: CGFloat = 148
    static let height: CGFloat = 124

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RowIcon(systemName: icon)
            Spacer(minLength: Spacing.s)
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
        .frame(width: Self.width, height: Self.height, alignment: .leading)
        .elevatedCard()
        .contentShape(.rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }
}

/// Asks for feedback and opens an email to the team.
private struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        CompactSheet("Share feedback") {
            Text("Kiki is brand new, and your feedback shapes what we build next. Tell us what's working, what isn't, or what you'd love to see. We read every message.")
                .font(.body)
                .foregroundStyle(.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Spacing.xs) {
                PrimaryButton("Share feedback", systemImage: "envelope") {
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
