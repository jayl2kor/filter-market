import SwiftUI
import UIKit

/// SwiftUI wrapper around `UIActivityViewController` for share sheets.
///
/// Use as `.sheet` content. Pass any combination of strings, URLs, and images.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?

    init(
        activityItems: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil
    ) {
        self.activityItems = activityItems
        self.excludedActivityTypes = excludedActivityTypes
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper for share payloads so `.sheet(item:)` can drive presentation.
struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
