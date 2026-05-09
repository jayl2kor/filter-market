import XCTest

@MainActor
class MooditUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func launch(
        route: String? = nil,
        isAuthenticated: Bool = false,
        deepLink: String? = nil,
        dynamicType: String? = nil
    ) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-hasOnboarded", "YES",
            "-isAuthenticated", isAuthenticated ? "YES" : "NO"
        ]
        if let route {
            app.launchArguments += ["-ui-route", route]
        }
        if let deepLink {
            app.launchArguments += ["-deepLink", deepLink]
        }
        if let dynamicType {
            app.launchArguments += ["-ui-dynamic-type", dynamicType]
        }
        app.launch()
        installSystemPermissionMonitor()
    }

    func tap(
        _ identifier: String,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons[identifier].firstMatch
        if button.waitForExistence(timeout: min(1, timeout)) {
            button.tap()
            return
        }

        let target = element(identifier)
        if target.waitForExistence(timeout: min(0.1, timeout)) {
            target.tap()
            return
        }

        let attempts = max(1, Int(timeout.rounded(.up)))
        for _ in 0..<attempts {
            app.swipeUp()
            if target.waitForExistence(timeout: 1) {
                if button.exists {
                    button.tap()
                } else {
                    target.tap()
                }
                return
            }
        }

        XCTFail("Missing element: \(identifier)", file: file, line: line)
    }

    func tapFirstButton(
        named label: String,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return
        }

        let attempts = max(1, Int(timeout.rounded(.up)))
        for _ in 0..<attempts {
            app.swipeUp()
            if button.waitForExistence(timeout: 1) {
                button.tap()
                return
            }
        }

        XCTFail("Missing button: \(label)", file: file, line: line)
    }

    func assertExists(
        _ identifier: String,
        route: String? = nil,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(identifier)
        if target.waitForExistence(timeout: timeout) {
            return
        }

        for _ in 0..<6 {
            app.swipeUp()
            if target.waitForExistence(timeout: 1) {
                return
            }
        }

        for _ in 0..<6 {
            app.swipeDown()
            if target.waitForExistence(timeout: 1) {
                return
            }
        }

        let routeSuffix = route.map { " on route: \($0)" } ?? ""
        XCTAssertTrue(
            target.exists,
            "Missing element: \(identifier)\(routeSuffix)",
            file: file,
            line: line
        )
    }

    func assertStaticText(
        containing text: String,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
        if target.waitForExistence(timeout: timeout) {
            return
        }

        let attempts = max(1, Int(timeout.rounded(.up)))
        for _ in 0..<attempts {
            app.swipeUp()
            if target.waitForExistence(timeout: 1) {
                return
            }
        }

        XCTFail("Missing static text containing: \(text)", file: file, line: line)
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func firstElement(withIdentifierPrefix prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

    func acknowledgeSystemPermissionIfNeeded() {
        app.tap()
    }

    private func installSystemPermissionMonitor() {
        addUIInterruptionMonitor(withDescription: "System permissions") { alert in
            let allowLabels = ["Allow", "허용", "OK", "확인"]
            for label in allowLabels where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }
}
