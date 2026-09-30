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
        OnboardingScaffold(
            title: LocalizedStringKey(summary.checkTitle),
            subtitle: LocalizedStringKey(summary.checkMessage)
        ) {
            Card(padding: 24) {
                GoalJourney(weeks: summary.weeks, endLabel: summary.endLabel)
            }
            VStack(alignment: .leading, spacing: 16) {
                InfoRow(symbol: "target", text: LocalizedStringKey(summary.goalLine))
                InfoRow(symbol: "calendar", text: "\(model.answers.runDays.count) runs a week on \(RunDaysSelector.summary(model.answers.runDays))")
                InfoRow(symbol: "figure.run", text: "Starting from where you are today")
            }
            .padding(.top, 24)
        }
    }
}

/// A simple rising path from today to the goal. Illustrative, no numbers.
private struct GoalJourney: View {
    let weeks: Int
    let endLabel: String
    @State private var drawn: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: 8, y: h - 8))
                        p.addCurve(
                            to: CGPoint(x: w - 8, y: 8),
                            control1: CGPoint(x: w * 0.45, y: h - 8),
                            control2: CGPoint(x: w * 0.55, y: 8)
                        )
                    }
                    .trim(from: 0, to: drawn)
                    .stroke(Color.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))

                    Circle().stroke(Color.ink, lineWidth: 3).background(Circle().fill(Color.paper))
                        .frame(width: 16, height: 16)
                        .position(x: 8, y: h - 8)
                    Image(systemName: "flag.checkered")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.paper)
                        .frame(width: 30, height: 30)
                        .background(Color.ink, in: .circle)
                        .position(x: w - 8, y: 8)
                        .opacity(drawn == 1 ? 1 : 0)
                }
            }
            .frame(height: 130)

            HStack {
                Text("Today")
                Spacer()
                Text("\(weeks) weeks").foregroundStyle(.secondary)
                Spacer()
                Text(endLabel)
            }
            .font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("From today to \(endLabel) in \(weeks) weeks")
        .onAppear {
            withAnimation(.easeInOut(duration: 1).delay(0.2)) { drawn = 1 }
        }
    }
}

struct FlexibilityStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: model.firstName.map { "\($0), life happens. Kiki adapts." } ?? "Life happens. Kiki adapts.",
            subtitle: "Tired, busy, sore or ahead of schedule? Tell Kiki anytime and your plan updates in seconds."
        ) {
            VStack(spacing: 12) {
                Text("I'm wiped out this week. Work has been brutal.")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.wash, in: .rect(cornerRadius: 22))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, 48)
                HStack(alignment: .bottom, spacing: 10) {
                    KikiLogo(size: 32)
                    Text("No problem. I swapped Thursday's run for rest and eased up Saturday. We'll pick it back up next week.")
                        .foregroundStyle(.paper)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Color.ink, in: .rect(cornerRadius: 22))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 24)
            }
            .accessibilityElement(children: .combine)

            FlowChips(items: ["Missed a run", "Feeling tired", "Something hurts", "Busy week", "Too easy"])
                .padding(.top, 24)
        }
    }
}

private struct FlowChips: View {
    let items: [String]

    var body: some View {
        let rows = stride(from: 0, to: items.count, by: 3).map { Array(items[$0..<min($0 + 3, items.count)]) }
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.primary.opacity(0.15)))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct SummaryStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        let answers = model.answers
        let summary = GoalSummary(answers: answers, raceDate: answers.raceDate ?? model.suggestedRaceDate)
        OnboardingScaffold(
            title: model.firstName.map { "\($0), does this look right?" } ?? "Does this look right?",
            subtitle: "You can change any of this later in the You tab.",
            continueTitle: "Looks good"
        ) {
            VStack(spacing: 0) {
                SummaryRow(symbol: "target", label: "Goal", value: summary.goalLine)
                SummaryRow(symbol: "calendar", label: "Timeline", value: summary.timelineLine)
                SummaryRow(symbol: "figure.run", label: "Experience", value: (answers.experience ?? .new).title)
                SummaryRow(symbol: "clock", label: "Run days", value: RunDaysSelector.summary(answers.runDays))
                SummaryRow(symbol: (answers.coachingStyle ?? .balanced).icon, label: "Coaching", value: (answers.coachingStyle ?? .balanced).title, isLast: true)
            }
            .background(Color.wash, in: .rect(cornerRadius: 24))
        }
    }

    private struct SummaryRow: View {
        let symbol: String
        let label: String
        let value: String
        var isLast = false

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.body.weight(.semibold))
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    Text(label).foregroundStyle(.secondary)
                    Spacer()
                    Text(value).font(.body.weight(.semibold)).multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                if !isLast { Divider().padding(.leading, 60) }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct InfoRow: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(Color.wash, in: .circle)
                .accessibilityHidden(true)
            Text(text).font(.body)
        }
    }
}
