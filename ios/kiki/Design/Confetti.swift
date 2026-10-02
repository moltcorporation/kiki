import SwiftUI

/// A short confetti burst falling from the top of its frame, in the brand's
/// ink, gray and volt green. Overlay it, set `trigger` to fire again; it
/// clears itself after a few seconds and draws nothing under Reduce Motion.
struct ConfettiBurst: View {
    /// Change this value to fire a burst.
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    @State private var pieces: [Piece] = []

    private static let duration: TimeInterval = 3.2

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { context in
            Canvas { graphics, size in
                guard let start else { return }
                let elapsed = context.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let x = piece.x * size.width + sin(t * piece.sway) * 24
                    let y = -20 + t * piece.speed + 140 * t * t
                    guard y < size.height + 20 else { continue }
                    let fade = max(0, min(1, (Self.duration - elapsed) / 0.6))
                    var piecesGraphics = graphics
                    piecesGraphics.opacity = fade
                    piecesGraphics.translateBy(x: x, y: y)
                    piecesGraphics.rotate(by: .radians(t * piece.spin))
                    let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                                      width: piece.size.width, height: piece.size.height)
                    piecesGraphics.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            pieces = (0..<90).map { _ in Piece.random() }
            let fired = Date.now
            start = fired
            Task {
                try? await Task.sleep(for: .seconds(Self.duration))
                if start == fired { start = nil }
            }
        }
    }

    private struct Piece {
        let x: CGFloat
        let delay: TimeInterval
        let speed: CGFloat
        let sway: Double
        let spin: Double
        let size: CGSize
        let color: Color

        static func random() -> Piece {
            Piece(
                x: .random(in: 0...1),
                delay: .random(in: 0...0.5),
                speed: .random(in: 120...260),
                sway: .random(in: 2...5),
                spin: .random(in: -8...8),
                size: CGSize(width: .random(in: 6...10), height: .random(in: 10...16)),
                color: [Color.ink, Color.ink, Color.muted, Color.highlight, Color.highlight].randomElement()!
            )
        }
    }
}
