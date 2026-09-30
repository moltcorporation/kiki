import SwiftUI

/// The shared layout for every tab (Home, Plan, You), so the top area is
/// identical by construction: a large left-aligned title that scrolls with
/// the content (no floating bar), the same spacing above and below it, the
/// page background, and a fade under the status bar.
struct TabPage<Content: View>: View {
    let title: TabTitle.Kind
    /// Optional quiet text on the right of the title row (Home's greeting).
    var accessory: String?
    @ViewBuilder let content: Content

    init(_ title: TabTitle.Kind, accessory: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Accessory is centered on the title's height.
                HStack(alignment: .center, spacing: 12) {
                    TabTitle(kind: title)
                        .fixedSize()
                    Spacer(minLength: 0)
                    if let accessory {
                        // 15pt medium in `muted` (5.3:1 on the canvas, WCAG AA):
                        // clearly secondary to the 34pt title but easy to read.
                        Text(accessory)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(.bottom, Metrics.titleSpacing)
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    content
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { PageBackground() }
        .statusBarFade(.canvas)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

/// A tab's title: 34pt (the iOS large-title size), aligned left. Home's
/// wordmark uses the logo's black italic at the same size.
struct TabTitle: View {
    enum Kind {
        /// The Kiki wordmark (Home).
        case wordmark
        /// A plain title (Plan, You).
        case text(LocalizedStringKey)
    }

    let kind: Kind

    var body: some View {
        Group {
            switch kind {
            case .wordmark:
                Text("Kiki").font(.system(size: 34, weight: .black).italic())
            case .text(let text):
                Text(text).font(.system(size: 34, weight: .bold))
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// A section inside a tab: a title (with optional trailing detail) above
/// its card. All section titles share one size.
struct TabSection<Content: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let content: Content

    init(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.sectionTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.muted)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 4)
            content
        }
    }
}
