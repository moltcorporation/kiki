import SwiftUI

/// Human-readable description of the runner's goal, shared by the goal check
/// and summary screens.
struct GoalSummary {
    let answers: OnboardingModel.Answers
    let raceDate: Day

    var kind: GoalKind { answers.goalKind ?? .race }

    var distanceLabel: String {
        guard let distance = answers.raceDistance else { return "run" }
        return distance == .other ? Format.distance(answers.customDistanceKm * 1000, answers.units, decimals: 1) : distance.label
    }

    var weeks: Int {
        switch kind {
        case .race: max(1, Day.today.mondayOfWeek.days(until: raceDate.mondayOfWeek) / 7 + 1)
        case .faster: answers.weeks
        case .start, .fit: 8
        }
    }

    var goalLine: String {
        switch kind {
        case .start: return "Run 30 minutes non-stop"
        case .race:
            let name = answers.raceName.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? distanceLabel
            if answers.goalType == .time, let time = answers.goalTimeS { return "\(name) in \(Format.duration(time))" }
            return "Finish the \(name)"
        case .faster: return "\(distanceLabel) in \(Format.duration(answers.goalTimeS ?? 0))"
        case .fit: return "Run consistently and enjoy it"
        }
    }

    var endLabel: String {
        switch kind {
        case .start: "30 min non-stop"
        case .race: "Race day"
        case .faster: "Time trial"
        case .fit: "A running habit"
        }
    }

    var timelineLine: String {
        switch kind {
        case .race: "\(weeks) weeks · \(raceDate.date.formatted(.dateTime.month(.abbreviated).day()))"
        default: "\(weeks) weeks"
        }
    }

    var checkTitle: String {
        switch kind {
        case .start: "8 weeks to running 30 minutes"
        case .race: "\(weeks) weeks to race day"
        case .faster: "\(weeks) weeks to a faster \(distanceLabel)"
        case .fit: "Let's make running a habit"
        }
    }

    var checkMessage: String {
        switch kind {
        case .start:
            return "Most new runners get there in about 8 weeks with run/walk. Kiki starts gently and builds from there."
        case .race:
            let comfortable: Int = switch answers.raceDistance ?? .fiveK {
            case .fiveK: 4
            case .tenK: 6
            case .half: 8
            case .marathon: 12
            case .other: 8
            }
            return weeks < comfortable
                ? "That's a tight timeline, so Kiki will focus on getting you to the start line healthy and confident."
                : "That's plenty of time to get ready. Kiki will build you up step by step."
        case .faster:
            return "A focused block of training is the best way to get faster. Kiki keeps it challenging and safe."
        case .fit:
            return "Consistency beats intensity. Kiki keeps your running enjoyable and on track."
        }
    }
}

struct GoalCheckStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        let summary = GoalSummary(answers: model.answers, raceDate: model.answers.raceDate ?? model.suggestedRaceDate)
        // From the Profile tab this screen is the confirmation before a rebuild.
        let isRebuild = model.mode != .full
        OnboardingScaffold(
            title: LocalizedStringKey(summary.checkTitle),
            subtitle: LocalizedStringKey(summary.checkMessage),
            continueTitle: isRebuild ? "Build my new plan" : "Continue"
        ) {
            Card(padding: Spacing.l) {
                VStack(spacing: Spacing.l) {
                    PathChart(weeks: summary.weeks, kind: summary.kind, endLabel: summary.endLabel)
                    Rectangle().fill(Color.hairline).frame(height: 1)
                    HStack(spacing: Spacing.m) {
                        PathStat(value: "\(summary.weeks)", label: "weeks")
                        Rectangle().fill(Color.hairline).frame(width: 1, height: 32)
                        PathStat(value: "\(model.answers.runDays.count)", label: model.answers.runDays.count == 1 ? "run a week" : "runs a week")
                        Rectangle().fill(Color.hairline).frame(width: 1, height: 32)
                        PathStat(value: (model.answers.experience ?? .new).title, label: "your level", isText: true)
                    }
                }
            }
            if isRebuild {
                Footnote("This replaces your current plan. Runs you've logged are kept.")
            }
        }
    }
}

/// One fact under the path: a bold value over a small label.
private struct PathStat: View {
    let value: String
    let label: String
    var isText = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value)
                .font(isText ? .headline : .metric(.title3))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The plan's shape, week by week: running builds, eases off every few
/// weeks, then (for a race or time trial) lightens before the big day,
/// which stands tallest with a flag. Illustrative, from the answers.
private struct PathChart: View {
    let weeks: Int
    let kind: GoalKind
    let endLabel: String
    @State private var grown = false

    private var heights: [CGFloat] {
        let n = min(max(weeks, 3), 24)
        let hasFinale = kind == .race || kind == .faster || kind == .start
        let build = hasFinale ? n - 1 : n
        var bars: [CGFloat] = (0..<build).map { i in
            let t = CGFloat(i) / CGFloat(max(build - 1, 1))
            var h: CGFloat = kind == .fit ? 0.35 + 0.35 * min(t * 1.5, 1) : 0.22 + 0.58 * t
            if (i + 1) % 4 == 0 && i < build - 1 { h *= 0.8 }          // easier week
            if hasFinale && kind != .start && i == build - 1 && build > 3 { h *= 0.6 }  // lighter final week
            return h
        }
        if hasFinale { bars.append(1) }
        return bars
    }

    var body: some View {
        let bars = heights
        VStack(spacing: Spacing.s) {
            GeometryReader { proxy in
                let spacing: CGFloat = bars.count > 14 ? 3 : 5
                let width = (proxy.size.width - spacing * CGFloat(bars.count - 1)) / CGFloat(bars.count)
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { index, height in
                        let isFinale = index == bars.count - 1 && kind != .fit
                        RoundedRectangle(cornerRadius: min(width / 2, 5))
                            .fill(isFinale ? Color.ink : Color.ink.opacity(0.14 + 0.4 * height))
                            .frame(width: width, height: grown ? proxy.size.height * height : 4)
                            .overlay(alignment: .top) {
                                if isFinale {
                                    Image(systemName: "flag.checkered")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.ink)
                                        .offset(y: -20)
                                        .opacity(grown ? 1 : 0)
                                }
                            }
                            .animation(.smooth(duration: 0.6).delay(Double(index) * 0.035), value: grown)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 120)
            .padding(.top, Spacing.l)

            HStack {
                Text("Today")
                Spacer()
                Text(endLabel)
            }
            .font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your plan builds week by week from today to \(endLabel)")
        .onAppear { grown = true }
    }
}

struct FlexibilityStep: View {
    @State private var picked: Int?

    /// Each Adjust option and what Kiki does with it (same as in the app).
    private let options: [(icon: String, title: String, changes: [(day: String, before: String, after: String)])] = [
        ("battery.25percent", "I'm tired", [("Thu", "Tempo Run · 4 mi", "Rest"), ("Sat", "Long Run · 9 mi", "Long Run · 7 mi")]),
        ("arrow.down", "It's too hard", [("Thu", "Tempo Run · 4 mi", "Easy Run · 3 mi"), ("Sat", "Long Run · 9 mi", "Long Run · 8 mi")]),
        ("arrow.right", "Can't make it", [("Thu", "Tempo Run · 4 mi", "Rest"), ("Fri", "Rest", "Tempo Run · 4 mi")]),
        ("bandage", "Something hurts", [("Thu", "Tempo Run · 4 mi", "Rest"), ("Sat", "Long Run · 9 mi", "Easy Run · 4 mi")]),
    ]

    var body: some View {
        OnboardingScaffold(
            title: "Life happens. Kiki adapts.",
            subtitle: "Tired, busy or sore? Tap one to see how your plan changes."
        ) {
            VStack(spacing: Spacing.m) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible(), spacing: Spacing.s)], spacing: Spacing.s) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        let isOn = picked == index
                        Button {
                            Haptics.select()
                            picked = index
                        } label: {
                            HStack(spacing: Spacing.s) {
                                Image(systemName: option.icon)
                                    .font(.footnote.weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(isOn ? Color.paper.opacity(0.15) : Color.wash, in: .circle)
                                Text(option.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(isOn ? Color.paper : Color.ink)
                            .padding(.horizontal, Spacing.m)
                            .frame(minHeight: 52)
                            .background(isOn ? Color.ink : Color.surface, in: .rect(cornerRadius: Radius.control))
                            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(isOn ? Color.clear : Color.hairline))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }

                Image(systemName: "arrow.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.muted)

                // What changed, for the option picked.
                Card(padding: Spacing.l) {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        HStack(spacing: Spacing.s) {
                            KikiLogo(size: 22)
                            Text("Plan updated").font(.subheadline.weight(.semibold))
                        }
                        let changes = options[picked ?? 0].changes
                        ForEach(Array(changes.enumerated()), id: \.offset) { index, change in
                            if index > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                            ChangeRow(day: change.day, before: change.before, after: change.after)
                        }
                    }
                    .id(picked)
                    .transition(.opacity)
                }
                .opacity(picked == nil ? 0.35 : 1)
            }
            .animation(.smooth(duration: 0.35), value: picked)
            .task {
                // Show one example; then it's theirs to try.
                try? await Task.sleep(for: .seconds(0.8))
                if picked == nil { picked = 0 }
            }
        }
    }
}

/// One adjusted day: the old workout struck through, then the new one.
private struct ChangeRow: View {
    let day: String
    let before: String
    let after: String

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text(day)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.muted)
                .frame(width: 30, alignment: .leading)
            Text(before)
                .font(.subheadline)
                .strikethrough()
                .foregroundStyle(.muted)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.muted)
            Text(after)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

struct SummaryStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        let answers = model.answers
        let summary = GoalSummary(answers: answers, raceDate: answers.raceDate ?? model.suggestedRaceDate)
        OnboardingScaffold(
            title: model.firstName.map { "\($0), does this look right?" } ?? "Does this look right?",
            subtitle: "Tap anything to change it.",
            continueTitle: "Looks good"
        ) {
            // Each row is tappable: it reopens that question and comes back.
            let timelineStep: OnboardingModel.Step? = switch summary.kind {
            case .race: .raceDate
            case .faster: .timeframe
            case .start, .fit: nil   // fixed length
            }
            ListCard {
                SummaryRow(symbol: "target", label: "Goal", value: summary.goalLine) { model.edit(.goal) }
                SummaryRow(symbol: "calendar", label: "Timeline", value: summary.timelineLine,
                           action: timelineStep.map { step in { model.edit(step) } })
                SummaryRow(symbol: "figure.run", label: "Experience", value: (answers.experience ?? .new).title) { model.edit(.experience) }
                SummaryRow(symbol: "calendar.badge.checkmark", label: "Run days", value: RunDaysSelector.summary(answers.runDays)) { model.edit(.runDays) }
                SummaryRow(symbol: (answers.coachingStyle ?? .balanced).icon, label: "Coaching",
                           value: (answers.coachingStyle ?? .balanced).title) { model.edit(.coachingStyle) }
            }
        }
    }

    /// A settings-style row; rows without an action (fixed answers) show
    /// no chevron.
    private struct SummaryRow: View {
        let symbol: String
        let label: LocalizedStringKey
        let value: String
        var action: (() -> Void)?

        var body: some View {
            Button {
                action?()
            } label: {
                ListRow(icon: symbol, title: Text(label), value: value, emphasis: .setting, showsChevron: action != nil)
            }
            .buttonStyle(.haptic)
            .disabled(action == nil)
            .accessibilityElement(children: .combine)
            .accessibilityHint(action == nil ? "" : "Double-tap to change")
        }
    }
}
