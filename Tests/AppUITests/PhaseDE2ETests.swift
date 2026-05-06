import XCTest

final class PhaseDE2ETests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCommentsListSignedInComposeAndRatingEntry() {
        launch(route: "comments", isAuthenticated: true)

        XCTAssertTrue(element("social.comments.filter").waitForExistence(timeout: 6))
        XCTAssertTrue(element("social.comment.row").exists)
        XCTAssertTrue(element("social.comment.reply.row").exists)
        assertStaticText(containing: "↓ 6.2K")

        tap("social.comment.like")
        tap("social.comments.compose")

        XCTAssertTrue(element("social.compose.input").waitForExistence(timeout: 4))
        XCTAssertTrue(element("social.compose.mentions").exists)

        launch(route: "rating", isAuthenticated: true)
        tap("social.rating.star.4", timeout: 4)
        XCTAssertTrue(element("social.rating.comment").exists)
        XCTAssertTrue(element("social.rating.submit").exists)
    }

    func testSocialWriteActionsRouteGuestsToLogin() {
        launch(route: "comments", isAuthenticated: false)

        tap("social.comments.compose", timeout: 4)
        XCTAssertTrue(app.buttons["Apple로 계속하기"].waitForExistence(timeout: 4))

        launch(route: "commentCompose", isAuthenticated: false)
        XCTAssertTrue(app.staticTexts["첫 번째 댓글을 남겨보세요"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["로그인하고 댓글 쓰기"].exists)

        launch(route: "rating", isAuthenticated: false)
        XCTAssertTrue(app.buttons["로그인하고 평점 남기기"].waitForExistence(timeout: 4))
    }

    func testFollowListsSearchSegmentAndToggle() {
        launch(route: "followers")

        XCTAssertTrue(element("social.user.row").waitForExistence(timeout: 6))
        tapFirstButton(named: "팔로우")
        app.textFields["social.followers.search"].tap()
        app.textFields["social.followers.search"].typeText("Alex")
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 2))

        launch(route: "following")
        XCTAssertTrue(element("social.user.row").waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["최근 활동 있음"].exists)
        app.textFields["social.following.search"].tap()
        app.textFields["social.following.search"].typeText("Sarah")
        XCTAssertTrue(app.staticTexts["Sarah"].waitForExistence(timeout: 2))
    }

    func testDiscoveryFeedsExposeDownloadCountsAndSocialActions() {
        launch(route: "forYou")

        XCTAssertTrue(app.staticTexts["Amber Café"].waitForExistence(timeout: 6))
        assertStaticText(containing: "↓ 6.2K")
        XCTAssertTrue(app.staticTexts["Honey Hour"].exists)
        assertStaticText(containing: "↓ 3.4K")
        tap("social.foryou.hero.save")
        tap("social.foryou.maker.follow", timeout: 4)

        launch(route: "followingFeed")

        XCTAssertTrue(app.staticTexts["Tokyo Night"].waitForExistence(timeout: 6))
        assertStaticText(containing: "↓ 0")
        assertStaticText(containing: "Tokyo Night · 88% · ↓ 128")
        assertStaticText(containing: "Cotton Candy · 70% · ↓ 2.4K", timeout: 4)
        tap("social.following.post.like")
        tap("social.following.post.save")
        tap("social.following.post.comments")
        XCTAssertTrue(element("social.comment.row").waitForExistence(timeout: 4))
    }

    private func launch(route: String, isAuthenticated: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-hasOnboarded", "YES",
            "-isAuthenticated", isAuthenticated ? "YES" : "NO",
            "-ui-route", route
        ]
        app.launch()
    }

    private func tap(_ identifier: String, timeout: TimeInterval = 2) {
        let target = element(identifier)
        if target.waitForExistence(timeout: timeout) {
            target.tap()
            return
        }

        let attempts = max(1, Int(timeout.rounded(.up)))
        for _ in 0..<attempts {
            app.swipeUp()
            if target.waitForExistence(timeout: 1) {
                target.tap()
                return
            }
        }

        XCTFail("Missing element: \(identifier)")
    }

    private func tapFirstButton(named label: String, timeout: TimeInterval = 2) {
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

        XCTFail("Missing button: \(label)")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func assertStaticText(
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
}
