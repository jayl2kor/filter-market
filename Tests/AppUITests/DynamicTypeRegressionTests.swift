import XCTest

@MainActor
final class DynamicTypeRegressionTests: XCTestCase {
    private var app: XCUIApplication!
    private enum Target {
        case identifier(String)
        case text(String)

        var name: String {
            switch self {
            case .identifier(let identifier):
                return identifier
            case .text(let text):
                return text
            }
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreRoutesAtAccessibility5ExposePrimaryActionsInsideViewport() {
        let cases: [(route: String, targets: [Target])] = [
            ("search", [.text("추천 키워드"), .text("인기 메이커")]),
            ("filterDetail", [.identifier("filter.detail.download")]),
            ("profile", [.identifier("profile.settings"), .identifier("profile.edit.open")]),
            ("settings", [.identifier("settings.nav.프로필 편집"), .identifier("settings.nav.알림 설정")]),
            ("wallet", [.identifier("wallet.balance"), .identifier("wallet.action.코인 충전")]),
            ("notifications", [.identifier("notif.cat.all"), .identifier("notif.settings")]),
            ("uploadCover", [.identifier("upload.cover.add"), .identifier("upload.next")]),
            ("camera", [.identifier("camera.shutter"), .identifier("camera.openLibrary")])
        ]

        for testCase in cases {
            launch(route: testCase.route, dynamicType: "accessibility5")
            for target in testCase.targets {
                assertVisibleInViewport(target, route: testCase.route)
            }
        }
    }

    private func launch(route: String, dynamicType: String) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-hasOnboarded", "YES",
            "-isAuthenticated", "YES",
            "-ui-route", route,
            "-ui-dynamic-type", dynamicType
        ]
        app.launch()
    }

    private func assertVisibleInViewport(
        _ target: Target,
        route: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var element = element(target)
        _ = element.waitForExistence(timeout: timeout)
        for _ in 0..<6 where !isVisibleInViewport(element) {
            scrollDown()
            element = self.element(target)
            _ = element.waitForExistence(timeout: 1)
        }

        let targetName = target.name
        XCTAssertTrue(element.exists, "Missing element: \(targetName) on route: \(route)", file: file, line: line)
        XCTAssertFalse(element.frame.isEmpty, "Empty frame: \(targetName) on route: \(route)", file: file, line: line)
        XCTAssertTrue(
            isVisibleInViewport(element),
            "Element outside viewport: \(targetName) on route: \(route), frame: \(element.frame)",
            file: file,
            line: line
        )
    }

    private func element(_ target: Target) -> XCUIElement {
        switch target {
        case .identifier(let identifier):
            return app.descendants(matching: .any)[identifier].firstMatch
        case .text(let text):
            return app.staticTexts[text].firstMatch
        }
    }

    private func scrollDown() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        start.press(forDuration: 0.01, thenDragTo: end)
    }

    private func isVisibleInViewport(_ element: XCUIElement) -> Bool {
        element.exists
            && !element.frame.isEmpty
            && app.frame.insetBy(dx: -1, dy: -1).intersects(element.frame)
    }
}
