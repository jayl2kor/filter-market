import Foundation
import XCTest

final class SearchHeaderIntegrationTests: XCTestCase {
    func testFMSearchHeaderIsIncludedInDesignSystemTarget() throws {
        let root = try repositoryRoot()
        let componentURL = root.appendingPathComponent("Sources/DesignSystem/Components/FMSearchHeader.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: componentURL.path))

        let project = try String(contentsOf: root.appendingPathComponent("moodit.xcodeproj/project.pbxproj"))
        XCTAssertTrue(project.contains("FMSearchHeader.swift in Sources"))
        XCTAssertTrue(project.contains("path = FMSearchHeader.swift"))
    }

    func testMarketplaceAndSearchScreensUseSharedSearchHeader() throws {
        let root = try repositoryRoot()
        let marketplace = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/MarketplaceScreen.swift"))
        let search = try String(contentsOf: root.appendingPathComponent("Sources/App/Search/SearchScreen.swift"))

        XCTAssertTrue(marketplace.contains("FMSearchHeader(placeholder:"))
        XCTAssertTrue(marketplace.contains("market.searchHeader"))
        XCTAssertTrue(search.contains("FMSearchHeader("))
        XCTAssertTrue(search.contains("search.searchHeader"))
        XCTAssertFalse(search.contains("FMTextField.search("))
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
        throw NSError(domain: "SearchHeaderIntegrationTests", code: 1)
    }
}
