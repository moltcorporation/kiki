import SwiftUI

/// Cards you can swipe between sideways (Home's Today / Tomorrow, This
/// week / Next week). Pages snap one at a time and keep the screen margins;
/// the height eases between pages as you swipe, so a short card next to a
/// tall one never leaves a gap. `index` follows the page in view and moves
/// it when set.
struct SwipePager<Page: View>: View {
    let count: Int
    @Binding var index: Int
    @ViewBuilder let page: (Int) -> Page

    @State private var heights: [Int: CGFloat] = [:]
    @State private var position: CGFloat = 0
    @State private var scrollID: Int?

    /// Room for card shadows inside the clipped scroll area.
    private let shadowRoom: CGFloat = Spacing.l

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    page(i)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[i] = $0 }
                        .padding(.horizontal, Metrics.screenMargin)
                        .padding(.vertical, shadowRoom)
                        .containerRelativeFrame(.horizontal)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollID)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x / max(geometry.containerSize.width, 1)
        } action: { _, new in
            position = min(max(new, 0), CGFloat(count - 1))
        }
        .frame(height: height + shadowRoom * 2)
        .padding(.horizontal, -Metrics.screenMargin)
        .padding(.vertical, -shadowRoom)
        .onAppear { scrollID = index }
        .onChange(of: scrollID) { _, new in
            if let new, new != index {
                Haptics.select()
                index = new
            }
        }
        .onChange(of: index) { _, new in
            if scrollID != new { withAnimation(.smooth) { scrollID = new } }
        }
    }

    /// The pages' heights, blended by how far the swipe has gone.
    private var height: CGFloat {
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, count - 1)
        let fraction = position - CGFloat(lower)
        let a = heights[lower] ?? heights.values.max() ?? 0
        let b = heights[upper] ?? a
        return a + (b - a) * fraction
    }
}

/// Small dots for a section header: which of a few pages is showing.
struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.ink : Color.track)
                    .frame(width: i == index ? 14 : 6, height: 6)
            }
        }
        .animation(.smooth, value: index)
        .accessibilityElement()
        .accessibilityLabel("Page \(index + 1) of \(count)")
    }
}
