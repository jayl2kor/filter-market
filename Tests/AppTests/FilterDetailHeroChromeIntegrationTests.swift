import Foundation
import XCTest

final class FilterDetailHeroChromeIntegrationTests: XCTestCase {
    func testHeroExtendsUnderFloatingTopChrome() throws {
        let root = try repositoryRoot()
        let detail = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/FilterDetailScreen.swift"))

        XCTAssertTrue(detail.contains("ZStack(alignment: .top)"))
        XCTAssertTrue(detail.contains("scrollContent\n                .ignoresSafeArea(edges: .top)"))
        XCTAssertTrue(detail.contains("topChromeOverlay"))
        XCTAssertTrue(detail.contains(".toolbar(.hidden, for: .navigationBar)"))
        XCTAssertTrue(detail.contains(".safeAreaPadding(.top)"))
        XCTAssertTrue(detail.contains("geo.safeAreaInsets.top + 60"))
        XCTAssertTrue(detail.contains(".scaleEffect(1.12)"))
        XCTAssertTrue(detail.contains(".offset(y: min(44, max(26, geo.size.height * 0.055)))"))
        XCTAssertTrue(detail.contains(".accessibilitySortPriority(3)"))
        XCTAssertTrue(detail.contains(".accessibilitySortPriority(2)"))
    }

    func testFilterDetailNoLongerUsesNavigationToolbarButtons() throws {
        let root = try repositoryRoot()
        let detail = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/FilterDetailScreen.swift"))
        let filterDetailScreenScope = detail.components(separatedBy: "    // MARK: - CTA").first ?? detail

        XCTAssertFalse(filterDetailScreenScope.contains("ToolbarItem(placement: .topBarLeading)"))
        XCTAssertFalse(filterDetailScreenScope.contains("ToolbarItem(placement: .topBarTrailing)"))
        XCTAssertFalse(filterDetailScreenScope.contains(".toolbarBackground(.hidden, for: .navigationBar)"))
    }

    func testLoaderDoesNotReintroduceNavigationChromeForLoadedDetail() throws {
        let root = try repositoryRoot()
        let loader = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/FilterDetailLoaderScreen.swift"))

        XCTAssertFalse(loader.contains("}\n        .navigationTitle(\"필터 상세\")"))
        XCTAssertTrue(loader.contains("FilterDetailScreen(mock: detail.toMock(), onRefresh: { await load() })\n                    .toolbar(.hidden, for: .navigationBar)"))
        XCTAssertTrue(loader.contains("FilterDetailScreen(filter: filter)\n                    .toolbar(.hidden, for: .navigationBar)"))
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
        throw NSError(domain: "FilterDetailHeroChromeIntegrationTests", code: 1)
    }
}
