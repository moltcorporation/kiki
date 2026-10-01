import SwiftUI

// Page layouts. Every screen is one of these, so margins, title sizes and
// section rhythm match by construction:
//   TabPage     a tab's root (Home, Plan, Profile): scrolling 34pt title
//   DetailPage  a screen pushed from a tab or a full sheet: inline nav bar
//   FlowPage    a step in a full-screen flow (onboarding, paywall):
//               title + subtitle, content, actions pinned at the bottom
// Inside a page, content is grouped into `PageSection`s (a title above a
// card) spaced `Metrics.sectionSpacing` apart.

/// The shared layout for every tab: a 34pt title that scrolls with the
/// content (no floating bar) at Apple's large-title position, the same
/// spacing below it, the page background, and a fade under the status bar.
struct TabPage<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TabTitle(title)
                    .padding(.bottom, Metrics.titleSpacing)
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    content
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, Metrics.largeTitleTopInset)
            .padding(.bottom, Metrics.bottomInset)
        }
        .background { PageBackground() }
        .statusBarFade()
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

extension View {
    /// Put on a tab's root screen with `!path.isEmpty`: hides the tab bar
    /// while a screen is pushed. Driving it from the root makes the bar
    /// slide away with the push and fade back in during the pop; hiding it
    /// from the pushed screen brings it back only after the pop ends.
    func hidesTabBar(_ hidden: Bool) -> some View {
        toolbarVisibility(hidden ? .hidden : .visible, for: .tabBar)
            .animation(.default, value: hidden)
    }
}

/// A tab's title: 34pt bold, aligned left, where Apple's large titles sit.
/// Home's is the greeting ("Good morning, Stuart!").
struct TabTitle: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.screenTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A screen pushed from a tab (or the root of a full sheet): the page
/// background, standard margins and section spacing, and an inline
/// navigation title. Add `.bottomActions { }` for pinned buttons. The tab
/// bar hides while it's pushed (see `hidesTabBar(_:)`).
struct DetailPage<Content: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, Metrics.detailTopInset)
            .padding(.bottom, Metrics.bottomInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { PageBackground() }
        .modifier(InlineTitle(title: title))
    }
}

/// Sets an inline navigation title only when there is one, so a page
/// without a title keeps its container's (e.g. a sheet's).
private struct InlineTitle: ViewModifier {
    let title: LocalizedStringKey?

    func body(content: Content) -> some View {
        if let title {
            content.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        } else {
            content.navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// A screen in a full-screen flow: header, content, and actions pinned at
/// the bottom. The host (e.g. `OnboardingFlow`) draws the page background
/// so it stays still while steps slide.
struct FlowPage<Content: View, Actions: View>: View {
    var eyebrow: LocalizedStringKey?
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var titleStyle: PageHeader.Style = .standard
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    init(
        eyebrow: LocalizedStringKey? = nil,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        titleStyle: PageHeader.Style = .standard,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.titleStyle = titleStyle
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                PageHeader(eyebrow: eyebrow, title: title, subtitle: subtitle, style: titleStyle)
                content
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .bottomActions { actions }
    }
}

/// A page's title block: optional eyebrow, the title, an optional subtitle.
struct PageHeader: View {
    enum Style {
        /// Bold, for most pages and questions.
        case standard
        /// Black italic, for big moments (plan ready, paywall).
        case display
    }

    var eyebrow: LocalizedStringKey?
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var style: Style = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.headline)
                    .foregroundStyle(.muted)
            }
            Text(title)
                .font(style == .display ? .display(.largeTitle) : .screenTitle)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A section inside a page: a title (with optional trailing detail) above
/// its card. All section titles share one size.
struct PageSection<Content: View>: View {
    let title: LocalizedStringKey
    var detail: String?
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
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
            content
        }
    }
}

/// A titled `ListCard`: the usual way to show a group of rows.
struct ListSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        PageSection(title) {
            ListCard { content }
        }
    }
}

/// Small print under a section (notes, disclaimers).
struct Footnote: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Pinned actions

extension View {
    /// Pins buttons to the bottom of the screen, above the home indicator,
    /// with standard margins. Scrolling content blurs softly beneath them.
    func bottomActions<Actions: View>(@ViewBuilder _ actions: () -> Actions) -> some View {
        safeAreaBar(edge: .bottom) {
            VStack(spacing: Spacing.xs) {
                actions()
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.s)
        }
    }
}

// MARK: - Sheets

/// The top of a compact sheet: a centered title clear of the grabber, then
/// a hairline.
struct SheetHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.sheetTitle)
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .padding(.bottom, 18)
                .accessibilityAddTraits(.isHeader)
            Divider()
        }
    }
}

/// A compact sheet that fits its content: header, then content with
/// standard padding, on a white surface with a grabber.
struct CompactSheet<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content
    @State private var height: CGFloat = 300

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title)
            VStack(spacing: Spacing.l) {
                content
            }
            .padding(Spacing.xxl)
        }
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(height)])
        .presentationBackground(Color.surface)
        .presentationDragIndicator(.visible)
    }
}
