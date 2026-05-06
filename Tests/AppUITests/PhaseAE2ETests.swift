import XCTest

final class PhaseAE2ETests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testMarketplaceDownloadApplyCameraLoop() {
        launch()

        tap("market.trending.1", timeout: 8)
        tap("filter.detail.download", timeout: 4)
        tap("filter.download.completed.next", timeout: 6)
        tap("filter.favorite.toggle", timeout: 4)
        tap("filter.apply", timeout: 4)
        acknowledgeSystemPermissionIfNeeded()

        XCTAssertTrue(element("camera.shutter").waitForExistence(timeout: 6))
        XCTAssertTrue(element("camera.timer").exists)
        XCTAssertTrue(element("camera.grid.toggle").exists)
        XCTAssertTrue(element("camera.flash").exists)
        XCTAssertTrue(element("camera.aspectRatio").exists)
    }

    func testCameraHudAndPhotoImportEntry() {
        launch(route: "camera")
        acknowledgeSystemPermissionIfNeeded()

        XCTAssertTrue(element("camera.shutter").waitForExistence(timeout: 6))
        XCTAssertTrue(element("camera.timer").exists)
        XCTAssertTrue(element("camera.flash").exists)
        XCTAssertTrue(element("camera.aspectRatio").exists)

        tap("camera.grid.toggle")
        tap("camera.zoom.0.5")
        tap("camera.zoom.3.0")
        tap("camera.openLibrary")

        XCTAssertTrue(element("photo.import.cell.tap").waitForExistence(timeout: 4))
    }

    func testAspectAndTimerConfigurationScreens() {
        launch(route: "cameraAspect")
        tap("cam.aspect.set.1_1", timeout: 4)
        tap("cam.aspect.set.16_9")
        tap("cam.aspect.set.4_3")

        launch(route: "cameraTimer")
        tap("cam.timer.set.3", timeout: 4)
        tap("cam.timer.set.10")
        tap("cam.timer.set.0")
    }

    func testBuiltinFilterLibraryAppliesToCamera() {
        launch(route: "builtinFilters")

        let applyButton = firstElement(withIdentifierPrefix: "builtin.filter.apply.")
        XCTAssertTrue(applyButton.waitForExistence(timeout: 8))
        applyButton.tap()
        acknowledgeSystemPermissionIfNeeded()

        XCTAssertTrue(element("camera.shutter").waitForExistence(timeout: 6))
    }

    func testPhotoEditFilterIntensityAndActions() {
        launch(route: "photoEdit")

        XCTAssertTrue(element("photo.edit.intensity").waitForExistence(timeout: 6))
        XCTAssertTrue(element("photo.edit.done").exists)
        XCTAssertTrue(element("photo.edit.save_share").exists)

        let filterButton = firstElement(withIdentifierPrefix: "photo.edit.filter.")
        XCTAssertTrue(filterButton.waitForExistence(timeout: 6))
        filterButton.tap()
    }

    private func launch(route: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-hasOnboarded", "YES"]
        if let route {
            app.launchArguments += ["-ui-route", route]
        }
        app.launch()
        addUIInterruptionMonitor(withDescription: "System permissions") { alert in
            let allowLabels = ["Allow", "허용", "OK", "확인"]
            for label in allowLabels where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    private func tap(_ identifier: String, timeout: TimeInterval = 2) {
        let button = app.buttons[identifier]
        if button.waitForExistence(timeout: min(1, timeout)) {
            button.tap()
            return
        }

        let target = element(identifier)
        if target.waitForExistence(timeout: 0.1) {
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

        XCTFail("Missing element: \(identifier)")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func firstElement(withIdentifierPrefix prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

    private func acknowledgeSystemPermissionIfNeeded() {
        app.tap()
    }
}
