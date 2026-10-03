import RevenueCat
import RevenueCatUI
import SwiftUI

/// The paywall built in the RevenueCat dashboard ("Kiki Paywall 1" on the
/// `default` offering), loaded by the SDK. Shown full screen so it can't be
/// swiped away; its own "Continue with limited access" button closes it
/// (`onRequestedDismissal`), as does a purchase or a successful restore.
struct KikiPaywall: View {
    @Environment(Subscriptions.self) private var subscriptions

    var body: some View {
        PaywallView()
            .onPurchaseCompleted { _ in
                Haptics.success()
                Analytics.track("paywall_purchased")
                Task { await subscriptions.refresh() }
                subscriptions.closePaywall()
            }
            .onRestoreCompleted { info in
                Task { await subscriptions.refresh() }
                if info.entitlements.active[Config.entitlementID] != nil { subscriptions.closePaywall() }
            }
            .onRequestedDismissal {
                Analytics.track("paywall_dismissed", ["source": subscriptions.paywallSource])
                subscriptions.closePaywall()
            }
            .interactiveDismissDisabled()
            .onAppear { Analytics.screen("Paywall", ["source": subscriptions.paywallSource]) }
    }
}

/// Shown where a locked feature would be: a lock, a short line, and Unlock
/// (which opens the paywall).
struct LockedCard: View {
    @Environment(Subscriptions.self) private var subscriptions
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let source: String

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "lock.fill")
                .font(.title3.weight(.semibold))
                .frame(width: 48, height: 48)
                .background(Color.wash, in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xs) {
                Text(title).font(.cardTitle)
                Text(message)
                    .font(.detail)
                    .foregroundStyle(.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton("Unlock with Kiki Pro") { subscriptions.presentPaywall(source) }
                .controlSize(.small)
        }
        .foregroundStyle(.ink)
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity)
        .elevatedCard()
    }
}

/// A Pro-only sheet (adjusting the plan, sharing it): the content for
/// subscribers, otherwise a small sheet that leads to the paywall.
struct ProOnly<Content: View>: View {
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let source: String
    @ViewBuilder let content: Content
    @State private var height: CGFloat = 300

    var body: some View {
        if subscriptions.hasAccess {
            content
        } else {
            VStack(spacing: Spacing.l) {
                Image(systemName: "lock.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 52, height: 52)
                    .background(Color.wash, in: .circle)
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.xs) {
                    Text(title).font(.heroTitle).multilineTextAlignment(.center)
                    Text(message)
                        .font(.detail)
                        .foregroundStyle(.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PrimaryButton("Unlock with Kiki Pro") {
                    dismiss()
                    // After the sheet has gone, so the paywall can present.
                    Task {
                        try? await Task.sleep(for: .seconds(0.4))
                        subscriptions.presentPaywall(source)
                    }
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
        }
    }
}
