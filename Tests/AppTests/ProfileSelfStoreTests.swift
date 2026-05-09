import XCTest
@testable import moodit

@MainActor
final class ProfileSelfStoreTests: XCTestCase {
    func testDisplayHandleNormalizesWhitespaceAndAtPrefix() {
        XCTAssertEqual(ProfileSelfStore.displayHandle(from: " @maker "), "@maker")
        XCTAssertEqual(ProfileSelfStore.displayHandle(from: "@@studio"), "@studio")
        XCTAssertEqual(ProfileSelfStore.displayHandle(from: "  "), "@user")
    }

    func testBuildBaselinePrefersFirestoreProfileDocument() {
        let profile = ProfileSelfStore.buildBaseline(
            authDisplayName: "Auth Name",
            authEmail: "auth@example.com",
            uid: "auth-uid",
            doc: [
                "displayName": "Doc Name",
                "handle": "doc.handle",
                "bio": "Doc bio",
                "avatarURL": "https://example.com/avatar.png",
                "followerCount": 12,
                "followingCount": 7,
            ],
            filterCount: 3
        )

        XCTAssertEqual(profile.displayName, "Doc Name")
        XCTAssertEqual(profile.handle, "@doc.handle")
        XCTAssertEqual(profile.bio, "Doc bio")
        XCTAssertEqual(profile.avatarInitials, "DO")
        XCTAssertEqual(profile.avatarURL, URL(string: "https://example.com/avatar.png"))
        XCTAssertEqual(profile.filterCount, 3)
        XCTAssertEqual(profile.followerCount, 12)
        XCTAssertEqual(profile.followingCount, 7)
        XCTAssertTrue(profile.isOwnProfile)
    }

    func testBuildBaselineFallsBackToAuthEmailAndUID() {
        let emailProfile = ProfileSelfStore.buildBaseline(
            authDisplayName: nil,
            authEmail: "alex@example.com",
            uid: "abcdef123456",
            doc: nil,
            filterCount: 0
        )

        XCTAssertEqual(emailProfile.displayName, "alex")
        XCTAssertEqual(emailProfile.handle, "@alex")
        XCTAssertEqual(emailProfile.avatarInitials, "AL")

        let uidProfile = ProfileSelfStore.buildBaseline(
            authDisplayName: nil,
            authEmail: nil,
            uid: "abcdef123456",
            doc: nil,
            filterCount: 0
        )

        XCTAssertEqual(uidProfile.displayName, "사용자")
        XCTAssertEqual(uidProfile.handle, "@abcdef12")
    }

    func testStartAndRefreshStayLocalInUnitTests() async {
        let store = ProfileSelfStore()

        store.start()

        XCTAssertTrue(store.myFilters.isEmpty)
        XCTAssertTrue(store.savedFilterIDs.isEmpty)
        XCTAssertTrue(store.captureIDs.isEmpty)
        XCTAssertNil(store.currentUserProfile)

        await store.refresh()

        XCTAssertTrue(store.myFilters.isEmpty)
        XCTAssertTrue(store.savedFilterIDs.isEmpty)
        XCTAssertTrue(store.captureIDs.isEmpty)
        XCTAssertNil(store.currentUserProfile)
    }
}
