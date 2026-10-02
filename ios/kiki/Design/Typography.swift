import SwiftUI

// The type scale. Every style is built on an Apple text style, so it follows
// Dynamic Type. Use these names instead of per-screen fonts; one screen
// should need no more than three or four of them.
//
//   display       black italic, the Kiki voice (wordmark, big moments)
//   screenTitle   34pt bold: page and question titles
//   heroTitle     28pt bold: the title on Home's goal card
//   cardTitle     20pt bold: titles inside cards, sheet titles
//   sectionTitle  20pt semibold: headings above cards
//   rowTitle      17pt semibold: content rows (workouts, goals)
//   body          17pt regular: settings labels, copy
//   detail        15pt regular: subtitles and values (in `muted`)
//   eyebrow       13pt semibold: small labels above a title (in `muted`)
//   metric        heavy italic numbers (distances, paces, times)

extension Font {
    /// Black italic display type that echoes the Kiki logo.
    static func display(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, weight: .black).italic()
    }

    /// The Kiki wordmark atop Home (28pt, centered like a logo).
    static let wordmark = Font.display(.title)

    /// Big numbers (distances, paces, times).
    static func metric(_ style: Font.TextStyle = .title) -> Font {
        .system(style, weight: .heavy).italic().monospacedDigit()
    }

    /// Page titles: tabs, pushed screens, onboarding questions.
    static let screenTitle = Font.system(.largeTitle, weight: .bold)
    /// The title on Home's goal card.
    static let heroTitle = Font.system(.title, weight: .bold)
    /// Titles inside cards and at the top of sheets.
    static let cardTitle = Font.system(.title3, weight: .bold)
    /// Sheet titles (same as card titles).
    static let sheetTitle = cardTitle
    /// Headings above cards. Semibold, a clear level below the page title.
    static let sectionTitle = Font.system(.title3, weight: .semibold)
    /// Titles of content rows (workouts, goals, runs).
    static let rowTitle = Font.system(.body, weight: .semibold)
    /// Subtitles, values and supporting copy. Pair with `muted`.
    static let detail = Font.subheadline
    /// Small labels above a title ("Your goal", "Easy run"). Pair with `muted`.
    static let eyebrow = Font.system(.footnote, weight: .semibold)
    /// Button labels.
    static let button = Font.headline
}

/// The 64pt number above a ruler and on the run tracker. Scales with
/// Dynamic Type and shrinks rather than wraps.
private struct HeroMetricFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 64

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .heavy).italic().monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

extension View {
    func heroMetricFont() -> some View { modifier(HeroMetricFont()) }
}
