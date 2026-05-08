import SafariServices
import SwiftUI

/// SwiftUI wrapper around `SFSafariViewController`.
///
/// Use as a `.sheet` content view to open external URLs in-app:
///
/// ```swift
/// .sheet(item: $externalURL) { url in
///     SafariView(url: url.value)
/// }
/// ```
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = UIColor(named: "AccentPrimary")
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// Wraps a URL so it can be used with `.sheet(item:)`.
struct ExternalURL: Identifiable, Equatable {
    let id = UUID()
    let value: URL
}

/// moodit 정책/지원 URL — 한 곳에서 관리해 변경 시 영향 범위 명확.
enum MooditPolicyURL {
    static let terms = URL(string: "https://moodit.app/terms")!
    static let privacy = URL(string: "https://moodit.app/privacy")!
    static let support = URL(string: "https://moodit.app/support")!
}
