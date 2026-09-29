import RevenueCat
import SwiftUI

struct PaywallView: View {
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(TrainingStore.self) private var store
    @Environment(AuthService.self) private var auth

    @State private var selected: Package?
    @State private var trialEligible = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var message: String?
    @State private var confirmDelete = false

    private var offering: Offering? { subscriptions.offering }
    private var annual: Package? { offering?.annual }
    private var monthly: Package? { offering?.monthly }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(trialEligible ? "Start your free week" : "Unlock your plan")
                        .font(.display(.largeTitle))
                    Text(headline).foregroundStyle(.secondary)
                }

                if trialEligible {
                    TrialTimeline()
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        InfoRow(symbol: "calendar", text: "Your full plan, day by day")
                        InfoRow(symbol: "sparkles", text: "Unlimited coach adjustments")
                        InfoRow(symbol: "location.fill", text: "GPS run tracking and progress")
                    }
                }

                if let annual, let monthly {
                    VStack(spacing: 12) {
                        PackageOption(
                            title: "Yearly",
                            price: annual.storeProduct.localizedPriceString + "/year",
                            detail: annual.storeProduct.localizedPricePerMonth.map { "\($0)/month" },
                            badge: savings(annual: annual, monthly: monthly).map { "Save \($0)%" },
                            isSelected: selected == annual
                        ) { selected = annual }
                        PackageOption(
                            title: "Monthly",
                            price: monthly.storeProduct.localizedPriceString + "/month",
                            detail: nil,
                            badge: nil,
                            isSelected: selected == monthly
                        ) { selected = monthly }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 140)
                }
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                PrimaryButton(
                    trialEligible ? "Start my 7-day free trial" : "Continue",
                    isLoading: isPurchasing,
                    isEnabled: selected != nil && !isRestoring,
                    action: purchase
                )
                Text(priceTerms)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 18) {
                    Link("Terms", destination: Config.termsURL)
                    Link("Privacy", destination: Config.privacyURL)
                    Button(isRestoring ? "Restoring…" : "Restore", action: restore)
                        .disabled(isRestoring || isPurchasing)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.paper)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Restore purchases", systemImage: "arrow.clockwise", action: restore)
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task { await auth.signOut() }
                    }
                    Button("Delete account", systemImage: "trash", role: .destructive) {
                        confirmDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Account options")
            }
        }
        .background(Color.paper)
        .task { await load() }
        .alert(message ?? "", isPresented: .constant(message != nil)) {
            Button("OK") { message = nil }
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task {
                    do { try await auth.deleteAccount() } catch { message = error.localizedDescription }
                }
            }
        } message: {
            Text("This permanently deletes your plan, runs and profile.")
        }
        .onAppear { Analytics.screen("Paywall") }
    }

    private var headline: String {
        let race = store.plan?.displayName ?? "race"
        return "Your \(race) plan is ready. Get full access and train with Kiki."
    }

    private var priceTerms: String {
        guard let selected else { return " " }
        let price = selected.storeProduct.localizedPriceString
        let period = selected == annual ? "year" : "month"
        return trialEligible
            ? "7 days free, then \(price)/\(period). Cancel anytime."
            : "\(price)/\(period). Renews automatically. Cancel anytime."
    }

    private func savings(annual: Package, monthly: Package) -> Int? {
        let yearly = annual.storeProduct.price as Decimal
        let monthlyTotal = (monthly.storeProduct.price as Decimal) * 12
        guard monthlyTotal > 0 else { return nil }
        // NSDecimalNumber.intValue is unreliable for high-precision values.
        let percent = Int(NSDecimalNumber(decimal: (1 - yearly / monthlyTotal) * 100).doubleValue)
        return percent > 0 ? percent : nil
    }

    private func load() async {
        await subscriptions.loadOffering()
        selected = selected ?? annual ?? monthly
        let packages = [annual, monthly].compactMap { $0 }
        guard !packages.isEmpty else { return }
        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: packages)
        trialEligible = packages.contains { eligibility[$0]?.status == .eligible }
    }

    private func purchase() {
        guard let package = selected else { return }
        isPurchasing = true
        Analytics.track("purchase_started", ["package": package.identifier, "trial": trialEligible])
        Task {
            defer { isPurchasing = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased:
                    Haptics.success()
                    Analytics.track("purchase_completed", ["package": package.identifier, "trial": trialEligible])
                    let product = package.storeProduct
                    if subscriptions.isInTrial {
                        Attribution.startedTrial(productID: product.productIdentifier, currency: product.currencyCode)
                        await Notifications.scheduleTrialReminder(planName: package == annual ? "yearly" : "monthly")
                    } else {
                        Attribution.subscribed(productID: product.productIdentifier, currency: product.currencyCode)
                    }
                case .cancelled:
                    Analytics.track("purchase_cancelled", ["package": package.identifier])
                }
            } catch {
                Haptics.error()
                Analytics.captureError(error, context: ["step": "purchase"])
                message = error.localizedDescription
            }
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                let restored = try await subscriptions.restore()
                if !restored { message = "We couldn't find an active subscription for this Apple ID." }
                Analytics.track("restore_completed", ["found": restored])
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

private struct TrialTimeline: View {
    private let items: [(symbol: String, title: String, detail: String)] = [
        ("lock.open.fill", "Today", "Full access to your plan and coach"),
        ("bell.fill", "Day 5", "We'll remind you your trial is ending"),
        ("star.fill", "Day 7", "Your subscription starts. Cancel anytime before."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        Image(systemName: item.symbol)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.paper)
                            .frame(width: 40, height: 40)
                            .background(Color.ink, in: .circle)
                        if index < items.count - 1 {
                            Rectangle().fill(Color.ink.opacity(0.15)).frame(width: 3, height: 28)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.headline)
                        Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PackageOption: View {
    let title: String
    let price: String
    let detail: String?
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.ink : Color.secondary.opacity(0.5))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.paper)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.ink, in: .capsule)
                        }
                    }
                    Text(price).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let detail {
                    Text(detail).font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(.ink)
            .padding(18)
            .background(Color.wash, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.ink, lineWidth: isSelected ? 2 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
