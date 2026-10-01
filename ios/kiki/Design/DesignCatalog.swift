#if DEBUG
import SwiftUI

/// Every design-system component on one page, for checking changes to
/// tokens in Xcode previews (light and dark).
private struct DesignCatalog: View {
    @State private var option = 1
    @State private var tile = 0
    @State private var toggle = true
    @State private var text = ""

    var body: some View {
        NavigationStack {
            TabPage(.text("Design")) {
                PageSection("Type") {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("Kiki").font(.wordmark)
                            Text("Screen title").font(.screenTitle)
                            Text("Hero title").font(.heroTitle)
                            Text("Card title").font(.cardTitle)
                            Text("Section title").font(.sectionTitle)
                            Text("Row title").font(.rowTitle)
                            Text("Body text").font(.body)
                            Text("Detail text").font(.detail).foregroundStyle(.muted)
                            Text("Eyebrow").font(.eyebrow).foregroundStyle(.muted)
                            MetricView(value: "5.0", label: "km")
                        }
                    }
                }

                ListSection("Rows") {
                    ListRow(icon: "figure.run", title: Text("Content row"), subtitles: ["Subtitle"], showsChevron: true)
                    SettingsRow(icon: "ruler", label: "Settings row", value: "Value") {}
                    SettingsToggleRow(icon: "bell", label: "Toggle row", isOn: $toggle)
                    SettingsRow(icon: "trash", label: "Destructive", role: .destructive) {}
                }

                PageSection("Choices") {
                    VStack(spacing: Metrics.stackSpacing) {
                        OptionCard(title: "Option", subtitle: "With a subtitle", icon: "flag.checkered", isSelected: option == 1) { option = 1 }
                        OptionCard(title: "Option", badge: "Save 50%", detail: "$4.99", isSelected: option == 2) { option = 2 }
                        HStack(spacing: Spacing.s) {
                            ForEach(0..<3) { index in
                                SelectableTile(isSelected: tile == index, action: { tile = index }) {
                                    Text("Tile \(index + 1)").font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                        TextField("Text field", text: $text).inputField()
                        InputHint(icon: "checkmark.circle", message: "A hint under an input.")
                    }
                }

                PageSection("Buttons") {
                    VStack(spacing: Metrics.stackSpacing) {
                        PrimaryButton("Primary") {}
                        HStack(spacing: Spacing.m) {
                            SecondaryButton("Secondary") {}
                            CircleButton("Run", systemImage: "figure.run") {}
                        }
                        TextButton("Text button") {}
                    }
                }

                PageSection("Content") {
                    VStack(spacing: Metrics.stackSpacing) {
                        MessageCard(icon: "calendar", title: "Message card", message: "A short gray line.")
                        UserBubble(text: "A message from the runner.")
                        CoachBubble(text: "A reply from Kiki.")
                        HStack { Pill("Today"); Spacer() }
                        InfoRow(symbol: "sparkles", text: "An info row")
                    }
                }
            }
        }
    }
}

#Preview("Light") { DesignCatalog() }
#Preview("Dark") { DesignCatalog().preferredColorScheme(.dark) }
#endif
