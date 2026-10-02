import SwiftUI

// Surfaces: one model everywhere. Every page sits on `PageBackground`
// (canvas); content sits on white `surface` cards lifted with a soft
// shadow; controls inside a page (options, fields, tiles) are surface with
// a hairline. Dark hero cards are the same card in the inverted scheme.

/// The app's page background: a near-white canvas with a very faint dark
/// asphalt glow (and a hint of grain) rising from the bottom. Grayscale,
/// one light source everywhere.
struct PageBackground: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.canvas
            GeometryReader { proxy in
                let glow = RadialGradient(
                    colors: [Color.ink.opacity(0.07), Color.ink.opacity(0.02), .clear],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: proxy.size.height * 0.7
                )
                ZStack {
                    glow
                    // Asphalt grain, only where the glow is.
                    Image(decorative: "Grain")
                        .resizable(resizingMode: .tile)
                        .opacity(0.05)
                        .mask(glow.opacity(12))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// The splash's asphalt texture with a soft volt-green glow that drifts
/// slowly across and back, so the card feels alive and energetic. Still under Reduce Motion.
/// Used only behind Home's goal card.
struct AsphaltBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.launchBackground
                Image(.launchTexture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                RadialGradient(
                    colors: [Color.glow.opacity(0.55), Color.glow.opacity(0.14), .clear],
                    center: UnitPoint(x: -0.1 + 1.2 * phase, y: 0.1),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.75
                )
                .blendMode(.screen)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { phase = 0.7; return }
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }
}

extension View {
    /// The standard card: a white surface lifted off the canvas.
    func elevatedCard(cornerRadius: CGFloat = Radius.card, elevation: Elevation = .card) -> some View {
        background(Color.surface, in: .rect(cornerRadius: cornerRadius))
            .elevation(elevation)
    }

    /// The surface for controls on a page (options, fields, tiles): white
    /// with a hairline, and an ink outline when selected.
    func controlSurface(isSelected: Bool = false, cornerRadius: CGFloat = Radius.control) -> some View {
        background(Color.surface, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(isSelected ? Color.ink : Color.hairline, lineWidth: isSelected ? 2 : 1)
            }
    }

    /// Flips light and dark for this view, so `ink` content becomes white on
    /// a dark card (and back in Dark Mode). Use for hero cards instead of
    /// passing `inverted` flags down.
    func invertedColorScheme() -> some View { modifier(InvertedColorScheme()) }
}

private struct InvertedColorScheme: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, colorScheme == .dark ? .light : .dark)
    }
}

/// A content card: padding, full width, leading aligned, elevated.
struct Card<Content: View>: View {
    var padding: CGFloat = Metrics.cardPadding
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .elevatedCard()
    }
}

/// For screens without a top bar: content dissolves as it scrolls under
/// the status bar. Solid page color behind the clock and Dynamic Island,
/// then a soft fade below, so rows never collide with them.
struct StatusBarFade: ViewModifier {
    var color: Color = .canvas
    /// How far below the status bar the fade runs.
    private let fade: CGFloat = Spacing.xxl

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            GeometryReader { proxy in
                let top = proxy.safeAreaInsets.top
                LinearGradient(
                    stops: [
                        .init(color: color, location: 0),
                        .init(color: color, location: top / (top + fade)),
                        .init(color: color.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: top + fade)
                .offset(y: -top)
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func statusBarFade(_ color: Color = .canvas) -> some View { modifier(StatusBarFade(color: color)) }
}
