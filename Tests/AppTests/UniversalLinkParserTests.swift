import XCTest
@testable import moodit

final class UniversalLinkParserTests: XCTestCase {

    // MARK: - Custom scheme (moodit://)

    func testParsesFilterDetailFromCustomScheme() {
        let url = URL(string: "moodit://filter/sunset-1973")!
        let route = UniversalLinkParser.route(for: url)
        guard case .filterDetail(let id) = route else {
            return XCTFail("Expected filterDetail, got \(String(describing: route))")
        }
        XCTAssertEqual(id, "sunset-1973")
    }

    func testParsesReviewsFromCustomScheme() {
        let url = URL(string: "moodit://reviews/sunset-1973")!
        guard case .reviews(let filterId) = UniversalLinkParser.route(for: url) else {
            return XCTFail("Expected reviews route")
        }
        XCTAssertEqual(filterId, "sunset-1973")
    }

    func testParsesMakerFromCustomScheme() {
        let url = URL(string: "moodit://maker/jisoo.films")!
        guard case .otherProfileHandle(let handle) = UniversalLinkParser.route(for: url) else {
            return XCTFail("Expected otherProfileHandle route")
        }
        XCTAssertEqual(handle, "jisoo.films")
    }

    func testParsesSearchFromCustomScheme() {
        let url = URL(string: "moodit://search?q=warm&category=cinematic")!
        guard case .search(let query, let category) = UniversalLinkParser.route(for: url) else {
            return XCTFail("Expected search route")
        }
        XCTAssertEqual(query, "warm")
        XCTAssertEqual(category, "cinematic")
    }

    func testParsesNotificationsFromCustomScheme() {
        let url = URL(string: "moodit://notifications")!
        guard case .notifications = UniversalLinkParser.route(for: url) else {
            return XCTFail("Expected notifications route")
        }
    }

    // MARK: - Universal links (https://moodit.app/*)

    func testParsesFilterDetailFromUniversalLink() {
        let url = URL(string: "https://moodit.app/f/sunset-1973")!
        guard case .filterDetail(let id) = UniversalLinkParser.route(for: url) else {
            return XCTFail("Expected filterDetail route")
        }
        XCTAssertEqual(id, "sunset-1973")
    }

    func testParsesReviewsFromUniversalLink() {
        let url = URL(string: "https://moodit.app/r/sunset-1973")!
        guard case .reviews(let filterId) = UniversalLinkParser.route(for: url) else {
            return XCTFail("Expected reviews route")
        }
        XCTAssertEqual(filterId, "sunset-1973")
    }

    func testParsesMakerFromUniversalLink() {
        let url = URL(string: "https://moodit.app/u/jisoo.films")!
        guard case .otherProfileHandle(let handle) = UniversalLinkParser.route(for: url) else {
            return XCTFail("Expected otherProfileHandle route")
        }
        XCTAssertEqual(handle, "jisoo.films")
    }

    func testAcceptsWWWVariantOfMooditHost() {
        let url = URL(string: "https://www.moodit.app/f/sunset-1973")!
        XCTAssertNotNil(UniversalLinkParser.route(for: url))
    }

    // MARK: - Negatives

    func testRejectsUnknownHostOnUniversalLink() {
        let url = URL(string: "https://example.com/f/whatever")!
        XCTAssertNil(UniversalLinkParser.route(for: url))
    }

    func testRejectsUnknownCustomSchemeHost() {
        let url = URL(string: "moodit://unknown/foo")!
        XCTAssertNil(UniversalLinkParser.route(for: url))
    }

    func testRejectsEmptySlugInFilterRoute() {
        let url = URL(string: "moodit://filter/")!
        XCTAssertNil(UniversalLinkParser.route(for: url))
    }

    func testRejectsUnknownScheme() {
        let url = URL(string: "ftp://example.com/whatever")!
        XCTAssertNil(UniversalLinkParser.route(for: url))
    }

    // MARK: - Push payload

    func testRoutesReviewPushToReviewsPage() {
        let userInfo: [AnyHashable: Any] = [
            "data": [
                "kind": "review",
                "filterId": "sunset-1973",
                "actorUid": "u-minji",
            ]
        ]
        guard case .reviews(let filterId) = UniversalLinkParser.route(forPushUserInfo: userInfo) else {
            return XCTFail("Expected reviews route")
        }
        XCTAssertEqual(filterId, "sunset-1973")
    }

    func testRoutesLikePushToFilterDetail() {
        let userInfo: [AnyHashable: Any] = [
            "data": [
                "kind": "like",
                "filterId": "honey-glow",
            ]
        ]
        guard case .filterDetail(let id) = UniversalLinkParser.route(forPushUserInfo: userInfo) else {
            return XCTFail("Expected filterDetail route")
        }
        XCTAssertEqual(id, "honey-glow")
    }

    func testRoutesFollowRequestPushToProfile() {
        let userInfo: [AnyHashable: Any] = [
            "data": [
                "kind": "followRequest",
                "actorUid": "u-emma",
            ]
        ]
        guard case .otherProfile(let uid) = UniversalLinkParser.route(forPushUserInfo: userInfo) else {
            return XCTFail("Expected otherProfile route")
        }
        XCTAssertEqual(uid, "u-emma")
    }

    func testRoutesSystemPushToNotificationsTab() {
        let userInfo: [AnyHashable: Any] = ["data": ["kind": "system"]]
        guard case .notifications = UniversalLinkParser.route(forPushUserInfo: userInfo) else {
            return XCTFail("Expected notifications route")
        }
    }

    func testReturnsNilWhenPushPayloadHasNoKnownKind() {
        XCTAssertNil(UniversalLinkParser.route(forPushUserInfo: ["data": ["kind": "weather"]]))
    }

    func testReturnsNilWhenReviewPushHasNoFilterId() {
        let userInfo: [AnyHashable: Any] = ["data": ["kind": "review"]]
        XCTAssertNil(UniversalLinkParser.route(forPushUserInfo: userInfo))
    }

    func testFlatPushPayloadAlsoWorks() {
        // Some senders flatten data fields into root userInfo (FCM does this in
        // certain configs). We accept that shape too.
        let userInfo: [AnyHashable: Any] = [
            "kind": "review",
            "filterId": "sunset-1973",
        ]
        guard case .reviews(let filterId) = UniversalLinkParser.route(forPushUserInfo: userInfo) else {
            return XCTFail("Expected reviews route")
        }
        XCTAssertEqual(filterId, "sunset-1973")
    }
}
