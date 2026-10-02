import AppIntents
import Foundation

/// Pause and resume buttons on the run's Live Activity (Lock Screen and
/// Dynamic Island). Live Activity intents run in the app's process, which
/// hooks up `RunControl`; the widget only shows the buttons.
struct PauseRunIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause run"

    func perform() async throws -> some IntentResult {
        await RunControl.pause()
        return .result()
    }
}

struct ResumeRunIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume run"

    func perform() async throws -> some IntentResult {
        await RunControl.resume()
        return .result()
    }
}

/// Set by the app's run tracker so the intents can reach it.
@MainActor
enum RunControl {
    static var onPause: (() -> Void)?
    static var onResume: (() -> Void)?

    static func pause() { onPause?() }
    static func resume() { onResume?() }
}
