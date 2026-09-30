import SwiftUI

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
        VStack(spacing: 12) {
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
                .font(.system(size: 64, weight: .heavy).italic().monospacedDigit())
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
                                        .fill(major ? Color.ink : Color.muted.opacity(0.35))
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
    /// Sets the recommended range for the hint.
    var experience: Experience?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                ForEach(1...7, id: \.self) { day in
                    let selected = days.contains(day)
                    OptionCard(title: Self.fullName(day), indicator: .checkbox, isSelected: selected) {
                        if selected { days.remove(day) } else { days.insert(day) }
                    }
                }
            }
            hint
        }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.wash, in: .rect(cornerRadius: 16))
        .overlay {
            if emphasized { RoundedRectangle(cornerRadius: 16).stroke(Color.ink, lineWidth: 1.5) }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: message)
        .onChange(of: emphasized) { _, isEmphasized in
            if isEmphasized { Haptics.warning() }
        }
        .accessibilityElement(children: .combine)
    }
}
