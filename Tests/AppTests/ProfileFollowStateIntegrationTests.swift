import Foundation
import XCTest

final class ProfileFollowStateIntegrationTests: XCTestCase {
    func testFollowListRoutesRowsByUIDInsteadOfHandle() throws {
        let social = try source("Sources/App/Social/SocialDiscoveryScreens.swift")

        XCTAssertTrue(social.contains("NavigationLink(value: profileRoute(for: user))"))
        XCTAssertTrue(social.contains("return .otherProfile(uid: uid)"))
        XCTAssertTrue(social.contains("return .otherProfileHandle(handle: user.handle)"))
        XCTAssertFalse(social.contains("AppRoute.otherProfile(uid: user.handle)"))
    }

    func testFollowListBuildsRelationshipFromFollowEdge() throws {
        let social = try source("Sources/App/Social/SocialDiscoveryScreens.swift")

        XCTAssertTrue(social.contains("let relationship = await relationship(for: uid, currentActorUid: FirebaseSideEffects.currentUID, db: db)"))
        XCTAssertTrue(social.contains("document(\"\\(actorUid)_\\(uid)\").getDocument()"))
        XCTAssertTrue(social.contains("return mode == .followers ? .mutual : .following"))
    }

    func testProfileFollowingCountDoesNotDependOnlyOnUserDocCounter() throws {
        let store = try source("Sources/App/Profile/ProfileSelfStore.swift")
        let screen = try source("Sources/App/Profile/ProfileScreen.swift")

        XCTAssertTrue(store.contains("followingEdgesListener = db.collection(\"follows\")"))
        XCTAssertTrue(store.contains("whereField(\"actorUid\", isEqualTo: uid)"))
        XCTAssertTrue(store.contains("derivedFollowingCount = count"))
        XCTAssertTrue(screen.contains("profileStore.applyOptimisticFollowingCountDelta"))
        XCTAssertTrue(screen.contains("profileStore.rollbackOptimisticFollowingCount"))
    }

    func testOwnProfileFollowListUsesStableUIDAndAvoidsHashTitleFallback() throws {
        let screen = try source("Sources/App/Profile/ProfileScreen.swift")
        let social = try source("Sources/App/Social/SocialDiscoveryScreens.swift")

        XCTAssertTrue(screen.contains("sessionStore.currentUserID"))
        XCTAssertTrue(screen.contains("return \"me\""))
        XCTAssertFalse(screen.contains("return user.handle.replacingOccurrences(of: \"@\", with: \"\")"))
        XCTAssertTrue(social.contains("return mode == .followers ? \"팔로워\" : \"팔로잉\""))
        XCTAssertFalse(social.contains("@\\(normalizedUserID.prefix(8))"))
        XCTAssertFalse(social.contains("@\\(targetUserID.prefix(8))"))
    }

    func testFollowScreensReattachWhenAuthUIDBecomesAvailable() throws {
        let session = try source("Sources/App/Session/SessionStore.swift")
        let social = try source("Sources/App/Social/SocialDiscoveryScreens.swift")

        XCTAssertTrue(session.contains("@Published private(set) var currentUserID"))
        XCTAssertTrue(social.contains("@EnvironmentObject private var sessionStore: SessionStore"))
        XCTAssertTrue(social.contains(".task(id: followListTaskID)"))
        XCTAssertTrue(social.contains(".task(id: followingFeedTaskID)"))
        XCTAssertTrue(social.contains("sessionStore.currentUserID ?? FirebaseSideEffects.currentUID"))
        XCTAssertFalse(social.contains("?? \"me\""))
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(path))
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
        throw NSError(domain: "ProfileFollowStateIntegrationTests", code: 1)
    }
}
