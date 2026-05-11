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

    func testSearchScreenUsesSharedSearchHeader() throws {
        let root = try repositoryRoot()
        let search = try String(contentsOf: root.appendingPathComponent("Sources/App/Search/SearchScreen.swift"))

        XCTAssertTrue(search.contains("FMSearchHeader("))
        XCTAssertTrue(search.contains("search.searchHeader"))
        XCTAssertFalse(search.contains("FMTextField.search("))
    }

    func testMarketplaceHeaderExposesBrandingBarCreateAction() throws {
        let root = try repositoryRoot()
        let marketplace = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/MarketplaceScreen.swift"))

        XCTAssertTrue(marketplace.contains("brandingBar"))
        XCTAssertTrue(marketplace.contains("market.brandbar.create"))
        XCTAssertTrue(marketplace.contains("NavigationLink(value: AppRoute.editor)"))
        XCTAssertTrue(marketplace.contains("create_filter_from_market"))
        XCTAssertTrue(marketplace.contains("Image(\"MooditWordmark\")"))
        XCTAssertTrue(marketplace.contains("market.brandbar.logo"))
        XCTAssertFalse(marketplace.contains("Text(\"moodit\")"))
        XCTAssertTrue(marketplace.contains("NavigationLink(value: AppRoute.wallet)"))
        XCTAssertTrue(marketplace.contains("wallet_opened"))
        XCTAssertTrue(marketplace.contains("market.header.coinBalance"))
        XCTAssertTrue(marketplace.contains("NavigationLink(value: AppRoute.notifications)"))
        XCTAssertTrue(marketplace.contains("notifications_opened"))
        XCTAssertTrue(marketplace.contains("market.header.notifications"))
        XCTAssertFalse(marketplace.contains("FMSearchHeader(placeholder:"))
        XCTAssertFalse(marketplace.contains("market.searchHeader"))
    }

    func testMarketplaceLogoUsesVectorWordmarkAsset() throws {
        let root = try repositoryRoot()
        let assetURL = root.appendingPathComponent("Sources/App/Resources/Assets.xcassets/MooditWordmark.imageset/MooditWordmark.svg")
        let contentsURL = root.appendingPathComponent("Sources/App/Resources/Assets.xcassets/MooditWordmark.imageset/Contents.json")
        let svg = try String(contentsOf: assetURL)
        let contents = try String(contentsOf: contentsURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: assetURL.path))
        XCTAssertTrue(contents.contains("MooditWordmark.svg"))
        XCTAssertTrue(contents.contains("preserves-vector-representation"))
        XCTAssertTrue(svg.contains("<path"))
        XCTAssertTrue(svg.contains("<circle"))
        XCTAssertFalse(svg.contains("<text"))
    }

    func testSearchScreenHeaderDoesNotExposeWalletOrNotificationsActions() throws {
        let root = try repositoryRoot()
        let search = try String(contentsOf: root.appendingPathComponent("Sources/App/Search/SearchScreen.swift"))

        XCTAssertFalse(search.contains("search.header.coinBalance"))
        XCTAssertFalse(search.contains("value: .wallet"))
        XCTAssertFalse(search.contains("value: .notifications"))
        XCTAssertFalse(search.contains("wallet_opened"))
        XCTAssertFalse(search.contains("notifications_opened"))
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
