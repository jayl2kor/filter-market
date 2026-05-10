import Foundation
import XCTest

final class SystemImageAccessibilityAuditTests: XCTestCase {
    func testSystemImageAuditMatchesSourceCount() throws {
        let root = try repositoryRoot()
        let sources = [
            root.appendingPathComponent("Sources/App"),
            root.appendingPathComponent("Sources/DesignSystem"),
        ]
        let count = try sources.reduce(0) { total, directory in
            try total + swiftFiles(in: directory).reduce(0) { fileTotal, file in
                let text = try String(contentsOf: file)
                return fileTotal + text.components(separatedBy: "Image(systemName:").count - 1
            }
        }

        let auditURL = root.appendingPathComponent("docs/SYSTEM_IMAGE_A11Y_AUDIT.md")
        let audit = try String(contentsOf: auditURL)

        XCTAssertEqual(count, 207, "Update SYSTEM_IMAGE_A11Y_AUDIT.md and this guard when adding/removing system icons.")
        XCTAssertTrue(audit.contains("Current count: \(count) `Image(systemName:)` calls."))
        XCTAssertTrue(audit.contains("Total: \(count)"))
    }

    func testSystemImageAuditDocumentsRequiredCategories() throws {
        let audit = try String(contentsOf: try repositoryRoot().appendingPathComponent("docs/SYSTEM_IMAGE_A11Y_AUDIT.md"))
        for category in [
            "Decorative icon",
            "Button/NavigationLink icon with visible text",
            "Standalone icon button",
            "Status/rating icon",
            "DesignSystem primitive",
        ] {
            XCTAssertTrue(audit.contains(category), "Missing audit category: \(category)")
        }
    }

    private func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            let marker = url.appendingPathComponent("moodit.xcodeproj")
            if FileManager.default.fileExists(atPath: marker.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        throw NSError(domain: "SystemImageAccessibilityAuditTests", code: 1)
    }

    private func swiftFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }
}
