import SafariServices
import SwiftUI
import UIKit

/// Opens web pages (Terms, Privacy, kikirunning.com) in an in-app Safari
/// sheet instead of switching to Safari. Installed app-wide as the
/// `openURL` action in `KikiApp`, so `Link`, `openURL(_:)` and links in
/// text all use it. Other schemes (mailto:, Settings) go to the system.
enum InAppBrowser {
    static let openURLAction = OpenURLAction { url in
        guard open(url) else { return .systemAction }
        return .handled
    }

    /// Presents `url` over whatever is on screen (sheets included).
    /// Returns false for URLs it doesn't handle.
    @discardableResult
    static func open(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased()), let presenter = topViewController() else { return false }
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = UIColor(named: "Ink")
        safari.dismissButtonStyle = .done
        presenter.present(safari, animated: true)
        return true
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
