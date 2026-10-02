import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Metric(value: context.attributes.distanceText(context.state.distanceM), label: context.attributes.distanceUnit)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Metric(value: context.attributes.paceText(context.state.paceSPerKm), label: "/\(context.attributes.distanceUnit)")
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    ElapsedText(state: context.state)
                        .font(.system(.title, weight: .heavy).italic().monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.isPaused ? "Paused" : context.attributes.workoutTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        PauseResumeButton(isPaused: context.state.isPaused)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.run")
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "figure.run")
            }
        }
    }
}

private struct LockScreenView: View {
    let attributes: RunActivityAttributes
    let state: RunActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("K")
                    .font(.system(size: 14, weight: .black).italic())
                    .frame(width: 24, height: 24)
                    .background(.white, in: .rect(cornerRadius: 7))
                    .foregroundStyle(.black)
                Text(state.isPaused ? "Paused" : attributes.workoutTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                PauseResumeButton(isPaused: state.isPaused)
            }
            HStack(alignment: .firstTextBaseline) {
                ElapsedText(state: state)
                    .font(.system(size: 40, weight: .heavy).italic().monospacedDigit())
                Spacer()
                Metric(value: attributes.distanceText(state.distanceM), label: attributes.distanceUnit)
                Metric(value: attributes.paceText(state.paceSPerKm), label: "/\(attributes.distanceUnit)")
                    .padding(.leading, 12)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

private struct ElapsedText: View {
    let state: RunActivityAttributes.ContentState

    var body: some View {
        if let paused = state.pausedElapsed {
            Text(RunActivityAttributes.elapsedText(paused))
        } else {
            Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
                .multilineTextAlignment(.center)
        }
    }
}

private struct Metric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value).font(.system(.title3, weight: .heavy).italic().monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// Pauses or resumes the run from the Lock Screen or Dynamic Island.
private struct PauseResumeButton: View {
    let isPaused: Bool

    var body: some View {
        Group {
            if isPaused {
                Button(intent: ResumeRunIntent()) {
                    Label("Resume", systemImage: "play.fill")
                }
            } else {
                Button(intent: PauseRunIntent()) {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
        }
        .font(.caption.weight(.bold))
        .labelStyle(.titleAndIcon)
        .buttonStyle(.plain)
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.white, in: .capsule)
    }
}
