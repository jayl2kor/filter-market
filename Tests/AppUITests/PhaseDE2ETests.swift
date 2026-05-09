import XCTest

final class PhaseDE2ETests: MooditUITestCase {
    func testReviewsListSignedInComposeAndRatingEntry() {
        launch(route: "reviews", isAuthenticated: true)

        XCTAssertTrue(element("social.reviews.filter").waitForExistence(timeout: 6))
        XCTAssertTrue(element("social.review.row").exists)
        XCTAssertTrue(element("social.review.makerReply.row").exists)
        XCTAssertTrue(element("social.review.stars").exists)
        XCTAssertTrue(element("social.review.verified").exists)
        assertStaticText(containing: "↓ 6.2K")

        tap("social.review.helpful")
        tap("social.reviews.compose")

        XCTAssertTrue(element("social.compose.input").waitForExistence(timeout: 4))
        XCTAssertTrue(element("social.compose.mentions").exists)

        launch(route: "rating", isAuthenticated: true)
        tap("social.rating.star.4", timeout: 4)
        XCTAssertTrue(element("social.rating.body").exists)
        XCTAssertTrue(element("social.rating.submit").exists)
    }

    func testSocialWriteActionsRouteGuestsToLogin() {
        launch(route: "reviews", isAuthenticated: false)

        tap("social.reviews.compose", timeout: 4)
        XCTAssertTrue(app.buttons["Apple로 계속하기"].waitForExistence(timeout: 4))

        launch(route: "reviewCompose", isAuthenticated: false)
        XCTAssertTrue(app.staticTexts["첫 번째 리뷰를 남겨보세요"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["로그인하고 리뷰 쓰기"].exists)

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

        XCTAssertTrue(app.staticTexts["Airy Trip"].waitForExistence(timeout: 6))
        XCTAssertTrue(element("social.foryou.hero.apply").exists)
        XCTAssertTrue(element("social.foryou.hero.save").exists)
        tap("social.foryou.hero.save")
        tap("social.foryou.maker.follow", timeout: 4)

        launch(route: "followingFeed")

        XCTAssertTrue(app.staticTexts["Tokyo Night"].waitForExistence(timeout: 6))
        assertStaticText(containing: "Tokyo Night · 88% · ↓ 128")
        assertStaticText(containing: "Cotton Candy · 70% · ↓ 2.4천", timeout: 4)
        tap("social.following.post.like")
        tap("social.following.post.save")
        tap("social.following.post.reviews")
        XCTAssertTrue(element("social.review.row").waitForExistence(timeout: 4))
        XCTAssertTrue(element("social.review.stars").exists)
    }

}
