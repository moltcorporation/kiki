import SwiftUI

/// The end of Home: "Help Kiki grow", a row of compact tiles that scrolls
/// sideways (request a feature, invite a friend, leave a review).
struct HelpKikiGrowSection: View {
    @Environment(\.openURL) private var openURL
    @State private var showFeedback = false

    var body: some View {
        PageSection("Help Kiki grow") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.stackSpacing) {
                    Button {
                        showFeedback = true
                        Analytics.track("help_kiki_grow_tapped", ["item": "feature_request"])
                    } label: {
                        GrowTile(icon: "lightbulb", title: "Request a feature", subtitle: "Help shape Kiki")
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

                    Button {
                        Analytics.track("help_kiki_grow_tapped", ["item": "review"])
                        openURL(Config.writeReviewURL)
                    } label: {
                        GrowTile(icon: "star", title: "Leave a review", subtitle: "On the App Store")
                    }
                    .buttonStyle(.haptic)
                }
            }
            // Scroll edge to edge, starting on the page margin.
            .contentMargins(.horizontal, Metrics.screenMargin, for: .scrollContent)
            .padding(.horizontal, -Metrics.screenMargin)
            // Let the cards' shadows fade out instead of being cut off at
            // the row's edge.
            .scrollClipDisabled()
        }
        .sheet(isPresented: $showFeedback) { FeatureRequestSheet() }
    }
}

/// A compact tile: icon at the top, title and subtitle at the bottom.
/// Used by Home's "Help Kiki grow" and "Get set up" rows.
struct GrowTile: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    static let width: CGFloat = 160
    static let height: CGFloat = 124

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RowIcon(systemName: icon)
            Spacer(minLength: Spacing.s)
            // No shrink-to-fit, so every tile's text is the same size.
            Text(title)
                .font(.rowTitle)
                .lineLimit(1)
            Text(subtitle)
                .font(.detail)
                .foregroundStyle(.muted)
                .lineLimit(1)
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

/// "Request a feature": a fitted bottom sheet like the Adjust sheet. Write
/// it, Send, and it's emailed to the team (replies go to the runner).
struct FeatureRequestSheet: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable { case writing, sending, sent, failed(String) }

    @State private var phase: Phase = .writing
    @State private var message = ""
    @State private var height: CGFloat = 360
    @FocusState private var focused: Bool

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            switch phase {
            case .writing, .sending, .failed:
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Request a feature")
                        .font(.heroTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text("What should Kiki do next? We read every request.")
                        .font(.detail)
                        .foregroundStyle(.muted)
                }
                TextField("e.g. Show my heart rate on each run", text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focused)
                    .inputField()
                    .disabled(phase == .sending)
                if case .failed(let error) = phase {
                    Footnote(LocalizedStringKey(error))
                }
                PrimaryButton(phase == .sending ? "Sending…" : "Send", isEnabled: !trimmed.isEmpty && phase != .sending, action: send)
            case .sent:
                VStack(spacing: Spacing.m) {
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.onHighlight)
                        .frame(width: 56, height: 56)
                        .background(Color.highlight, in: .circle)
                        .accessibilityHidden(true)
                    Text("Thanks for the idea!")
                        .font(.heroTitle)
                    Text("It's on its way to the team.")
                        .font(.detail)
                        .foregroundStyle(.muted)
                }
                .frame(maxWidth: .infinity)
                PrimaryButton("Done") { dismiss() }
            }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, Spacing.xxxl)
        .padding(.bottom, Spacing.l)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surface)
        .interactiveDismissDisabled(phase == .sending)
        .animation(.smooth(duration: 0.35), value: phase)
        .task {
            try? await Task.sleep(for: .seconds(0.4))
            focused = true
        }
        .onAppear { Analytics.screen("Feature Request") }
    }

    private func send() {
        focused = false
        phase = .sending
        Task {
            do {
                try await store.requestFeature(trimmed)
                Haptics.success()
                phase = .sent
            } catch {
                Haptics.error()
                phase = .failed("Couldn't send it. Check your connection and try again.")
            }
        }
    }
}
