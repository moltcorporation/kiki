import SwiftUI

// Inputs: controls for answering questions, shared by onboarding and the
// Profile tab. Choices are `OptionCard`s (a list, with a radio or checkbox)
// or `SelectableTile`s (a grid, filled when selected). Text fields use
// `.inputField()`. All sit on `controlSurface`.

/// A single-choice list of radio cards. Selecting doesn't advance; the
/// surrounding screen decides what happens next.
struct ChoiceList<Value: Hashable>: View {
    struct Option {
        let value: Value
        let title: String
        var subtitle: String?
        var icon: String?
        var level: Int?
    }

    let options: [Option]
    let selection: Value?
    let onSelect: (Value) -> Void

    var body: some View {
        VStack(spacing: Metrics.stackSpacing) {
            ForEach(options, id: \.value) { option in
                OptionCard(
                    title: option.title,
                    subtitle: option.subtitle,
                    icon: option.icon,
                    level: option.level,
                    isSelected: selection == option.value
                ) {
                    onSelect(option.value)
                }
            }
        }
    }
}

/// A big value above a horizontal ruler you scroll to pick a number.
/// Snaps to whole values, ticks haptically, and supports VoiceOver adjust.
struct RulerPicker: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    /// Every nth value gets a tall tick.
    var majorEvery = 10
    let label: (Int) -> String

    @State private var position: Int?
    private let tickSpacing: CGFloat = 12

    var body: some View {
        VStack(spacing: 28) {
            Text(label(value))
                .heroMetricFont()
                .contentTransition(.numericText(value: Double(value)))
                .animation(.snappy, value: value)
                .frame(maxWidth: .infinity)

            GeometryReader { proxy in
                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(Array(range), id: \.self) { tick in
                                let major = tick % majorEvery == 0
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(major ? Color.ink : Color.track)
                                        .frame(width: major ? 2.5 : 1.5, height: major ? 40 : 22)
                                    Spacer(minLength: 0)
                                }
                                .frame(width: tickSpacing, height: 56)
                                .id(tick)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $position, anchor: .center)
                    .safeAreaPadding(.horizontal, proxy.size.width / 2 - tickSpacing / 2)

                    Capsule()
                        .fill(Color.ink)
                        .frame(width: 4, height: 56)
                        .allowsHitTesting(false)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.2),
                            .init(color: .black, location: 0.8),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            .frame(height: 56)
            .accessibilityHidden(true)
        }
        .onAppear { position = value }
        .onChange(of: position) { _, new in
            guard let new, new != value, range.contains(new) else { return }
            value = new
            Haptics.select()
        }
        .onChange(of: value) { _, new in
            if position != new { position = new }
        }
        .accessibilityElement()
        .accessibilityValue(label(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }
}

/// The seven days as checkbox cards (like the other questions), with a
/// live hint on how the count fits the runner's level. Never a hard gate
/// beyond one day.
struct RunDaysSelector: View {
    @Binding var days: Set<Int>
    /// The long-run day, optional: nil lets Kiki pick (Saturday, else
    /// Sunday, else the last run day).
    @Binding var longRunDay: Int?
    /// Sets the recommended range for the hint.
    var experience: Experience?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // One compact row: every day visible without scrolling.
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(spacing: Spacing.xs) {
                    ForEach(1...7, id: \.self) { day in
                        dayTile(day)
                    }
                }
                hint
            }

            if !days.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Long run day").font(.sectionTitle)
                        Text(longRunCaption)
                            .font(.detail)
                            .foregroundStyle(.muted)
                            .contentTransition(.opacity)
                    }
                    HStack(spacing: Spacing.s) {
                        ForEach(days.sorted(), id: \.self) { day in
                            longRunChip(day)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.2), value: days)
        .animation(.snappy(duration: 0.2), value: longRunDay)
        .onChange(of: days) {
            // The chosen long-run day stopped being a run day: back to auto.
            if let longRunDay, !days.contains(longRunDay) { self.longRunDay = nil }
        }
    }

    private func dayTile(_ day: Int) -> some View {
        let selected = days.contains(day)
        return Button {
            Haptics.select()
            if selected { days.remove(day) } else { days.insert(day) }
        } label: {
            Text(Calendar.current.shortWeekdaySymbols[day % 7])
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.paper : Color.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(selected ? Color.ink : Color.surface, in: .rect(cornerRadius: Radius.inner))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.inner)
                        .strokeBorder(selected ? Color.clear : Color.hairline)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.fullName(day))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func longRunChip(_ day: Int) -> some View {
        let selected = longRunDay == day
        return Button {
            Haptics.select()
            longRunDay = selected ? nil : day
        } label: {
            Text(Calendar.current.shortWeekdaySymbols[day % 7])
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? Color.paper : Color.ink)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: 36)
                .background(selected ? Color.ink : Color.surface, in: .capsule)
                .overlay(Capsule().strokeBorder(selected ? Color.clear : Color.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Long run on \(Self.fullName(day))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var longRunCaption: String {
        if let longRunDay { return "Your long run will be on \(Self.fullName(longRunDay))s." }
        return "Optional. Kiki will use \(Self.fullName(Questions.longRunDay(for: days))) if you don't pick."
    }

    /// Days a week coaches recommend at each level.
    static func recommended(for experience: Experience?) -> ClosedRange<Int> {
        switch experience ?? .new {
        case .new: 3...3
        case .beginner: 3...4
        case .intermediate: 4...5
        case .advanced: 5...6
        }
    }

    private var hint: some View {
        let count = days.count
        let range = Self.recommended(for: experience)
        let (icon, message, emphasized): (String, String, Bool) = switch count {
        case 0:
            ("hand.tap", "Pick at least one day to run.", false)
        case ..<range.lowerBound:
            ("info.circle", "\(count == 1 ? "1 day works" : "\(count) days work"), but \(range.lowerBound) a week is recommended for steady progress.", false)
        case range:
            ("checkmark.circle", "Great balance of running and rest for your level.", false)
        case 7:
            ("exclamationmark.triangle.fill", "Running every day leaves no time to recover. Try at least one rest day.", true)
        default:
            ("exclamationmark.circle", "That's a lot for your level. Rest days are when you get stronger.", false)
        }
        return InputHint(icon: icon, message: message, emphasized: emphasized)
    }

    static func fullName(_ isoDay: Int) -> String {
        Calendar.current.weekdaySymbols[isoDay % 7]
    }

    static func shortName(_ isoDay: Int) -> String {
        String(Calendar.current.shortWeekdaySymbols[isoDay % 7].prefix(2))
    }

    /// Day list like "Tue, Thu, Sat".
    static func summary(_ days: some Collection<Int>) -> String {
        days.sorted().map { Calendar.current.shortWeekdaySymbols[$0 % 7] }.joined(separator: ", ")
    }
}

/// Hours / minutes / seconds wheels.
struct DurationWheel: View {
    @Binding var seconds: Int
    var showsHours = true

    var body: some View {
        HStack(spacing: 0) {
            if showsHours {
                wheel(value: seconds / 3600, range: 0...9, label: "h") { seconds = $0 * 3600 + seconds % 3600 }
            }
            wheel(value: (seconds % 3600) / 60, range: 0...59, label: "min") { seconds = (seconds / 3600) * 3600 + $0 * 60 + seconds % 60 }
            wheel(value: seconds % 60, range: 0...59, label: "sec") { seconds = seconds - seconds % 60 + $0 }
        }
        .frame(height: 200)
        .onChange(of: seconds) { Haptics.select() }
    }

    private func wheel(value: Int, range: ClosedRange<Int>, label: String, set: @escaping (Int) -> Void) -> some View {
        Picker(label, selection: Binding(get: { value }, set: set)) {
            ForEach(range, id: \.self) { n in
                Text("\(n) \(label)").tag(n)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

/// A short note under an input that reacts to the answer (e.g. how
/// realistic a goal time is). Informs, never blocks. `emphasized` adds an
/// outline and a warning haptic for answers worth a second look.
struct InputHint: View {
    let icon: String
    let message: String
    var emphasized = false

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: icon)
        }
        .font(.subheadline.weight(emphasized ? .semibold : .medium))
        .foregroundStyle(emphasized ? Color.ink : Color.muted)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity)
        .controlSurface(isSelected: emphasized)
        .animation(.snappy, value: message)
        .onChange(of: emphasized) { _, isEmphasized in
            if isEmphasized { Haptics.warning() }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Choices

/// A selectable card for single or multiple choice: optional icon or
/// ability ring, a title with optional subtitle (and badge), an optional
/// trailing detail, and a radio or checkbox. Selected cards get an ink
/// outline.
struct OptionCard: View {
    enum Indicator { case radio, checkbox }

    let title: String
    var subtitle: String?
    var icon: String?
    /// 1–4: draws an ability ring that fills with the level.
    var level: Int?
    /// A small pill beside the title ("Save 50%").
    var badge: String?
    /// Bold text before the indicator ("$4.99/month").
    var detail: String?
    var indicator: Indicator = .radio
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: Spacing.l) {
                if let level {
                    LevelRing(level: level)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.s) {
                        Text(title).font(.rowTitle)
                        if let badge { Pill(badge) }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.detail)
                            .foregroundStyle(.muted)
                    }
                }
                Spacer(minLength: Spacing.s)
                if let detail {
                    Text(detail).font(.subheadline.weight(.semibold))
                }
                SelectionIndicator(style: indicator, isSelected: isSelected)
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(.ink)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, subtitle == nil ? Spacing.xl : Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .controlSurface(isSelected: isSelected)
            .contentShape(.rect(cornerRadius: Radius.control))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SelectionIndicator: View {
    let style: OptionCard.Indicator
    let isSelected: Bool

    var body: some View {
        Group {
            switch style {
            case .radio:
                ZStack {
                    Circle().strokeBorder(isSelected ? Color.ink : Color.track, lineWidth: isSelected ? 2 : 1.5)
                    if isSelected { Circle().fill(Color.ink).padding(6) }
                }
            case .checkbox:
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.ink : .clear)
                    .strokeBorder(isSelected ? Color.ink : Color.track, lineWidth: 1.5)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.paper)
                        }
                    }
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}

/// Ring that fills a quarter per level (1–4).
private struct LevelRing: View {
    let level: Int

    var body: some View {
        ZStack {
            Circle().stroke(Color.track, lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(level, 1), 4)) / 4)
                .stroke(Color.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }
}

/// A square-ish choice in a grid (how a run felt, why to adjust): content
/// on a control surface, filled ink when selected.
struct SelectableTile<Label: View>: View {
    let isSelected: Bool
    var minHeight: CGFloat = 72
    var alignment: Alignment = .center
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            label
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
                .foregroundStyle(isSelected ? Color.paper : Color.ink)
                .background(isSelected ? Color.ink : Color.clear, in: .rect(cornerRadius: Radius.control))
                .controlSurface()
                .contentShape(.rect(cornerRadius: Radius.control))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Text fields

extension View {
    /// The standard text field box. Set the font on the field (`.screenTitle`
    /// for a single big answer like a name, `.title3.weight(.semibold)` for a
    /// short label, `.body` for longer text).
    func inputField() -> some View {
        padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .controlSurface()
    }
}

/// A labeled text field ("Race name (optional)").
struct LabeledField<Field: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.muted)
            field.inputField()
        }
    }
}
