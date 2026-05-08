import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// SwiftUI wrapper around `UIDocumentPickerViewController` for importing files
/// from Files / iCloud Drive.
///
/// Usage:
///
/// ```swift
/// .sheet(isPresented: $showingImporter) {
///     DocumentPicker(allowedTypes: [.cube]) { url in
///         // Handle selected file URL
///     }
/// }
/// ```
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

extension UTType {
    /// `.cube` LUT file type. Adobe registered this UTI; some editors export as
    /// `text/plain` so we declare a custom type that includes both extensions.
    static let cube: UTType = {
        UTType(filenameExtension: "cube", conformingTo: .data) ?? .data
    }()
}
