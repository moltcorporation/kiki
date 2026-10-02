import SwiftUI

/// The Learn tab: category chips, then short articles grouped by topic. Articles you've read get a Volt check.
struct LearnView: View {
    @State private var path: [Article] = []
    @State private var filter: Article.Category?
    @State private var read = ReadArticles.ids

    var body: some View {
        NavigationStack(path: $path) {
            TabPage("Learn") {
                CategoryChips(selection: $filter)

                ForEach(filter.map { [$0] } ?? Article.Category.allCases) { category in
                    let articles = Article.library.filter { $0.category == category }
                    // "All" shows a few per topic; a chip shows them all.
                    let shown = filter == nil ? Array(articles.prefix(3)) : articles
                    PageSection(
                        LocalizedStringKey(category.title),
                        actionTitle: filter == nil && articles.count > shown.count ? "See all" : nil,
                        action: { withAnimation(.snappy) { filter = category } }
                    ) {
                        ListCard {
                            ForEach(shown) { article in
                                Button { path.append(article) } label: {
                                    ArticleRow(article: article, isRead: read.contains(article.id))
                                }
                                .buttonStyle(.haptic)
                            }
                        }
                    }
                }
            }
            .hidesTabBar(!path.isEmpty)
            .navigationDestination(for: Article.self) { article in
                ArticleView(article: article)
                    .onAppear {
                        ReadArticles.markRead(article.id)
                        read = ReadArticles.ids
                    }
            }
        }
        .onAppear { Analytics.screen("Learn") }
    }
}

/// All, then one chip per topic, scrolling sideways.
private struct CategoryChips: View {
    @Binding var selection: Article.Category?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                chip("All", isSelected: selection == nil) { selection = nil }
                ForEach(Article.Category.allCases) { category in
                    chip(category.chip, isSelected: selection == category) { selection = category }
                }
            }
        }
        .contentMargins(.horizontal, Metrics.screenMargin, for: .scrollContent)
        .padding(.horizontal, -Metrics.screenMargin)
        .scrollClipDisabled()
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.paper : Color.ink)
                .padding(.horizontal, Spacing.l)
                .frame(minHeight: 36)
                .background(isSelected ? Color.ink : Color.surface, in: .capsule)
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// An article in a list: icon, title, read time, and a Volt check once read
/// (a chevron before).
private struct ArticleRow: View {
    let article: Article
    let isRead: Bool

    var body: some View {
        ListRow(icon: article.icon, title: Text(article.title), subtitles: ["\(article.minutes) min read"], emphasis: .medium) {
            if isRead {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Color.onHighlight)
                    .frame(width: 20, height: 20)
                    .background(Color.highlight, in: .circle)
                    .accessibilityLabel("Read")
            } else {
                RowChevron()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One article: topic, title, read time, the text, and key takeaways.
struct ArticleView: View {
    let article: Article

    var body: some View {
        DetailPage {
            PageHeader(
                eyebrow: LocalizedStringKey("\(article.category.chip) · \(article.minutes) min read"),
                title: LocalizedStringKey(article.title)
            )

            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(Array(article.body.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .paragraph(let text):
                        Text(text)
                            .font(.body)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    case .heading(let text):
                        Text(text)
                            .font(.sectionTitle)
                            .padding(.top, Spacing.s)
                            .accessibilityAddTraits(.isHeader)
                    case .bullets(let items):
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            ForEach(items, id: \.self) { item in
                                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                                    Text("•").foregroundStyle(.muted)
                                    Text(item).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .font(.body)
                    }
                }
            }

            PageSection("Key takeaways") {
                Card {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        ForEach(article.takeaways, id: \.self) { takeaway in
                            HStack(alignment: .top, spacing: Spacing.m) {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(Color.onHighlight)
                                    .frame(width: 20, height: 20)
                                    .background(Color.highlight, in: .circle)
                                    .accessibilityHidden(true)
                                Text(takeaway)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Analytics.screen("Article", ["id": article.id]) }
    }
}
