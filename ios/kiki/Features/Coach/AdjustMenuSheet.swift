import SwiftUI

/// "Adjust plan" from Home: a bottom sheet with quick options for today
/// (make it easier, move it, skip it, sore or hurt) and "Something else?
/// Tell Kiki". Skipping happens right away; the others go to the coach and
/// the sheet grows to show the result.
struct AdjustMenuSheet: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// A choice that goes to the coach (nil while the menu is showing).
    @State private var request: Request?
    @State private var height: CGFloat = 460
    @State private var detent: PresentationDetent = .height(460)

    private struct Request: Equatable {
        let reason: AdjustReason
        let message: String?
        let sendNow: Bool
    }

    private struct Option: Identifiable {
        let id: String
        let icon: String
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let action: () -> Void
    }

    /// Today's run, if there's one still to do.
    private var todayRun: Workout? {
        store.workouts.first { $0.date == .today && !$0.isRest && $0.status == .planned }
    }

    var body: some View {
        Group {
            if let request {
                AdjustPlanView(initialReason: request.reason, initialMessage: request.message, submitImmediately: request.sendNow)
            } else {
                menu
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { new in
                        height = new
                        detent = .height(new)
                    }
            }
        }
        .presentationDetents([.height(height), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surface)
        .onChange(of: request) { _, new in
            if new != nil { withAnimation(.smooth) { detent = .large } }
        }
        .onAppear { Analytics.screen("Adjust Menu") }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(todayRun == nil ? "Adjust your plan" : "Adjust today")
                    .font(.heroTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.detail)
                    .foregroundStyle(.muted)
            }

            VStack(spacing: 0) {
                let options = self.options
                ForEach(options) { option in
                    Button(action: option.action) {
                        HStack(spacing: RowMetrics.spacing) {
                            Image(systemName: option.icon)
                                .font(.footnote.weight(.bold))
                                .frame(width: 32, height: 32)
                                .background(Color.surface, in: .circle)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(option.title).font(.rowTitle)
                                Text(option.subtitle).font(.detail).foregroundStyle(.muted)
                            }
                            Spacer(minLength: Spacing.s)
                            RowChevron()
                        }
                        .foregroundStyle(.ink)
                        .padding(.horizontal, RowMetrics.horizontalPadding)
                        .padding(.vertical, Spacing.m)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.haptic)
                    .accessibilityElement(children: .combine)
                    if option.id != options.last?.id {
                        Divider().padding(.leading, RowMetrics.horizontalPadding + 32 + RowMetrics.spacing)
                    }
                }
            }
            .background(Color.wash, in: .rect(cornerRadius: Radius.control))

            // Anything else goes to the coach as free text.
            Button {
                request = Request(reason: .other, message: nil, sendNow: false)
            } label: {
                HStack(spacing: Spacing.s) {
                    Text("K")
                        .font(.system(size: 12, weight: .black).italic())
                        .foregroundStyle(.ink)
                        .frame(width: 22, height: 22)
                        .background(Color.paper, in: .circle)
                        .accessibilityHidden(true)
                    Text("Something else? Tell Kiki")
                }
                .font(.button)
                .foregroundStyle(.paper)
                .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                .background(Color.ink, in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.haptic)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, Spacing.xxxl)
        .padding(.bottom, Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var subtitle: String {
        guard let run = todayRun else { return "Tell Kiki what's changed." }
        let amount = run.distanceM.map { Format.distance(Double($0), store.units) }
            ?? run.durationS.map { Format.minutes($0) }
        return [run.title, amount].compactMap { $0 }.joined(separator: " · ")
    }

    private var options: [Option] {
        if let run = todayRun {
            return [
                Option(id: "easier", icon: "arrow.down", title: "Make it easier", subtitle: "Shorter, or more walking") {
                    ask(.tooHard, "Please make today's run easier: shorter, or more walking.")
                },
                Option(id: "move", icon: "arrow.right", title: "Move to another day", subtitle: "Kiki reshuffles the week") {
                    ask(.schedule, "I can't run today. Please move today's workout to another day this week.")
                },
                Option(id: "skip", icon: "minus", title: "Skip today", subtitle: "Rest instead, no guilt") {
                    Haptics.success()
                    store.setStatus(.skipped, for: run)
                    Analytics.track("adjust_quick_option", ["option": "skip"])
                    dismiss()
                },
                Option(id: "sore", icon: "plus", title: "I'm sore or hurt", subtitle: "Kiki adjusts the next few days") {
                    ask(.injured, "I'm sore or hurt.")
                },
            ]
        }
        return [
            Option(id: "easier", icon: "arrow.down", title: "Make it easier", subtitle: "Lighter runs for a few days") {
                ask(.tooHard, "Please make my next few runs easier.")
            },
            Option(id: "schedule", icon: "arrow.right", title: "Change my schedule", subtitle: "Kiki reshuffles the week") {
                ask(.schedule, nil, sendNow: false)
            },
            Option(id: "sore", icon: "plus", title: "I'm sore or hurt", subtitle: "Kiki adjusts the next few days") {
                ask(.injured, "I'm sore or hurt.")
            },
        ]
    }

    private func ask(_ reason: AdjustReason, _ message: String?, sendNow: Bool = true) {
        Analytics.track("adjust_quick_option", ["option": reason.rawValue])
        request = Request(reason: reason, message: message, sendNow: sendNow)
    }
}
