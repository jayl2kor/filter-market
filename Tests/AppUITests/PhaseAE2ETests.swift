import XCTest

final class PhaseAE2ETests: MooditUITestCase {
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

    func testMarketplaceNewFilterCardNavigatesToDetail() {
        launch()

        tap("market.tile.0", timeout: 8)

        XCTAssertTrue(
            element("filter.detail.download").waitForExistence(timeout: 4),
            "새로 들어온 필터 카드 탭은 필터 상세로 이동해야 합니다"
        )
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
        tap("cam.aspect.set.4_5")
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
        launch(deepLink: "moodit://filter/Teal%20Story")

        // FilterDetail renders the title as static text once the route slug is decoded.
        XCTAssertTrue(
            app.staticTexts["Teal Story"].waitForExistence(timeout: 8),
            "Deep link should surface the FilterDetail sheet"
        )
    }

    func testDeepLinkURLRoutesToReviewsList() {
        launch(deepLink: "moodit://reviews/Sunset%201973")

        XCTAssertTrue(
            element("social.reviews.filter").waitForExistence(timeout: 8),
            "moodit://reviews/<id> should surface ReviewsListScreen"
        )
    }

    func testDeepLinkURLRoutesToNotifications() {
        launch(isAuthenticated: true, deepLink: "moodit://notifications")

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

}
