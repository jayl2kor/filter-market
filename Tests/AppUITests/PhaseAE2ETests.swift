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
        tap("cam.timer.set.off")
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

    /// Universal Link / push deep-link routing — verifies that
    /// `RootShell` reads the `-deepLink` launch argument and routes it through
    /// `UniversalLinkParser` + `MooditStore.pendingDeepLinkRoute` so the
    /// destination sheet surfaces. Mirrors what happens for real users on
    /// `.onOpenURL` or a tapped FCM notification.
    func testDeepLinkURLRoutesToFilterDetail() {
        launch(deepLink: "moodit://filter/Sunset 1973")

        // FilterDetail renders the title as static text; the mock fallback
        // returns the "Sunset 1973" preview detail when the slug doesn't match
        // a seeded tile.
        XCTAssertTrue(
            app.staticTexts["Sunset 1973"].waitForExistence(timeout: 8),
            "Deep link should surface the FilterDetail sheet"
        )
    }

    func testDeepLinkURLRoutesToReviewsList() {
        launch(deepLink: "moodit://reviews/Sunset 1973")

        XCTAssertTrue(
            element("social.reviews.filter").waitForExistence(timeout: 8),
            "moodit://reviews/<id> should surface ReviewsListScreen"
        )
    }

    func testDeepLinkURLRoutesToNotifications() {
        launch(deepLink: "moodit://notifications")

        // NotificationsInbox uses the `notif.cat.all` chip; presence of any
        // category chip confirms the screen mounted.
        XCTAssertTrue(
            firstElement(withIdentifierPrefix: "notif.cat.").waitForExistence(timeout: 8),
            "moodit://notifications should surface NotificationsInboxScreen"
        )
    }

    func testUnknownDeepLinkURLDoesNotPresentSheet() {
        launch(deepLink: "moodit://unknown/whatever")

        // App should land on the marketplace tab without a deep-link sheet.
        // Marketplace search bar is the canonical visible element on cold start.
        XCTAssertTrue(
            app.staticTexts["오늘의 빛,"].waitForExistence(timeout: 8),
            "Unknown deep-link URLs should be ignored, leaving Marketplace visible"
        )
    }

    private func launch(route: String? = nil, deepLink: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-hasOnboarded", "YES"]
        if let route {
            app.launchArguments += ["-ui-route", route]
        }
        if let deepLink {
            app.launchArguments += ["-deepLink", deepLink]
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
