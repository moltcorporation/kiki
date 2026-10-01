import SwiftUI
import UIKit

// Kiki's design tokens: every spacing, size, radius, shadow and color role
// the app uses. Views use these names, never raw numbers or hex values, so
// changing a value here restyles the whole app. Colors themselves live in
// Assets.xcassets (Ink, Paper, Canvas, Surface, Wash, Muted), each with a
// light and dark value.

// MARK: - Spacing

/// The 4pt spacing scale, for gaps inside components.
enum Spacing {
    /// 2pt: between a title and its subtitle.
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

/// Layout metrics shared by every screen.
enum Metrics {
    /// Side margin for every screen (Apple's standard 20pt).
    static let screenMargin: CGFloat = 20
    /// The first element sits this far below the safe area.
    static let topInset: CGFloat = 8
    /// Where a tab's large title starts below the safe area, matching
    /// Apple's large titles (e.g. Settings): an empty 44pt bar row, then
    /// the title. Home's wordmark sits at `topInset` instead.
    static let largeTitleTopInset: CGFloat = 58
    /// Space between a pushed screen's navigation bar and its first
    /// element, matching Apple's (e.g. Settings > General).
    static let detailTopInset: CGFloat = 18
    /// Space after the last element of a scrolling page.
    static let bottomInset: CGFloat = 32
    /// Space between a page title and its first section.
    static let titleSpacing: CGFloat = 16
    /// Space between sections on a page.
    static let sectionSpacing: CGFloat = 28
    /// Space between a section title and its card.
    static let sectionHeaderSpacing: CGFloat = 12
    /// Space between sibling cards or options in a stack.
    static let stackSpacing: CGFloat = 12
    /// Padding inside content cards.
    static let cardPadding: CGFloat = 20
    /// Height of full-width buttons.
    static let buttonHeight: CGFloat = 56
    /// Height of buttons inside cards (`.controlSize(.small)`).
    static let compactButtonHeight: CGFloat = 48
    /// Minimum tap target (Apple HIG).
    static let minTapTarget: CGFloat = 44
}

/// Corner radii by component type. Nested shapes step down a level.
enum Radius {
    /// Cards and list cards.
    static let card: CGFloat = 24
    /// Controls inside a page: options, text fields, tiles, hints.
    static let control: CGFloat = 16
    /// Chat bubbles.
    static let bubble: CGFloat = 20
    /// Small shapes inside a card (summary chips).
    static let inner: CGFloat = 12
}

// MARK: - Elevation

/// A soft shadow level. Grayscale only.
struct Elevation {
    let opacity: Double
    let radius: CGFloat
    let y: CGFloat

    /// Cards resting on the page.
    static let card = Elevation(opacity: 0.06, radius: 18, y: 8)
    /// Hero cards that lead a page (today's workout, the goal).
    static let raised = Elevation(opacity: 0.18, radius: 22, y: 10)
}

extension View {
    func elevation(_ elevation: Elevation) -> some View {
        shadow(color: .black.opacity(elevation.opacity), radius: elevation.radius, y: elevation.y)
    }
}

// MARK: - Color roles

// Asset colors (generated): `ink` text and controls, `paper` text on ink,
// `canvas` page background, `surface` cards, `wash` small fills on cards
// (icon circles, tracks), `muted` secondary text (WCAG AA on white).
extension Color {
    /// Hairline borders on controls and cards.
    static var hairline: Color { .ink.opacity(0.12) }
    /// Unfilled tracks, unselected indicators and progress backgrounds.
    static var track: Color { .ink.opacity(0.12) }
    /// Destructive actions (Delete account).
    static var destructive: Color { .red }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
