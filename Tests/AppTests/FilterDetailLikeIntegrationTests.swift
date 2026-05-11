import Foundation
import XCTest

final class FilterDetailLikeIntegrationTests: XCTestCase {
    func testFilterDetailLikeUsesLikeStoreInsteadOfFavorites() throws {
        let root = try repositoryRoot()
        let detail = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/FilterDetailScreen.swift"))

        XCTAssertTrue(detail.contains("filterLibraryStore.isLiked(filter)"))
        XCTAssertTrue(detail.contains("let filterID = filter?.id.uuidString ?? mock.sourceID"))
        XCTAssertTrue(detail.contains("try await filterLibraryStore.setLikeAndPersist(filterID: filterID, liked: targetState)"))
        XCTAssertFalse(detail.contains("filterLibraryStore.toggleFavoriteAndPersist(filter)"))
        XCTAssertFalse(detail.contains("return filterLibraryStore.isFavorite(filter)"))
    }

    func testAlreadyDownloadedFilterDisablesDownloadCTA() throws {
        let root = try repositoryRoot()
        let detail = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/FilterDetailScreen.swift"))

        XCTAssertTrue(detail.contains("private var isAlreadyDownloaded: Bool"))
        XCTAssertTrue(detail.contains("filterLibraryStore.isDownloaded(filter)"))
        XCTAssertTrue(detail.contains("filterLibraryStore.downloadedFilterIDs.contains(uuid)"))
        XCTAssertTrue(detail.contains("if !isOwnedByCurrentUser, isAlreadyDownloaded"))
        XCTAssertTrue(detail.contains("return \"다운로드됨\""))
        XCTAssertTrue(detail.contains("return \"checkmark.circle.fill\""))
        XCTAssertTrue(detail.contains(".accessibilityIdentifier(\"filter.detail.downloaded\")"))
        XCTAssertTrue(detail.contains(".disabled(true)"))
    }

    func testFilterDetailMakerFollowPersistsFollowEdge() throws {
        let root = try repositoryRoot()
        let detail = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/FilterDetailScreen.swift"))

        XCTAssertTrue(detail.contains("private func attachMakerFollowState()"))
        XCTAssertTrue(detail.contains("private func toggleMakerFollow() async"))
        XCTAssertTrue(detail.contains("Task { await toggleMakerFollow() }"))
        XCTAssertTrue(detail.contains(".collection(\"follows\").document(\"\\(actorUid)_\\(targetUid)\")"))
        XCTAssertTrue(detail.contains("\"actorUid\": actorUid"))
        XCTAssertTrue(detail.contains("\"targetUid\": targetUid"))
        XCTAssertFalse(detail.contains("isFollowing.toggle()\n            FMHaptic.light.play()\n            Telemetry.trackAction(isFollowing ? \"maker_followed\""))
    }

    func testMockDetailLikeUsesSharedLikeStore() throws {
        let root = try repositoryRoot()
        let detail = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/FilterDetailScreen.swift"))
        let store = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/FilterLibraryStore.swift"))

        XCTAssertTrue(detail.contains("filterLibraryStore.isLiked(filterID: sourceID) || didLikeMockFilter"))
        XCTAssertTrue(detail.contains("let filterID = filter?.id.uuidString ?? mock.sourceID"))
        XCTAssertTrue(detail.contains("try await filterLibraryStore.setLikeAndPersist(filterID: filterID, liked: targetState)"))
        XCTAssertFalse(detail.contains("FirebaseSideEffects.callFunction(\"toggleFilterLike\", data: ["))
        XCTAssertFalse(detail.contains("guard FirebaseSideEffects.hasCurrentUser,"))
        XCTAssertTrue(store.contains("FirebaseSideEffects.callAuthenticatedFunction(\n            \"toggleFilterLike\""))
    }

    func testToggleLikeUsesSharedAuthenticatedCallable() throws {
        let root = try repositoryRoot()
        let sideEffects = try String(contentsOf: root.appendingPathComponent("Sources/App/Firebase/FirebaseSideEffects.swift"))
        let store = try String(contentsOf: root.appendingPathComponent("Sources/App/Marketplace/FilterLibraryStore.swift"))

        XCTAssertTrue(sideEffects.contains("static func callAuthenticatedFunction("))
        XCTAssertTrue(sideEffects.contains("getIDTokenResult(forcingRefresh: false)"))
        XCTAssertTrue(sideEffects.contains("isFunctionUnauthenticated(error)"))
        XCTAssertTrue(sideEffects.contains("getIDTokenResult(forcingRefresh: true)"))
        XCTAssertTrue(sideEffects.contains("FirebaseAuthRequestError.unauthenticated"))
        XCTAssertTrue(store.contains("FirebaseSideEffects.callAuthenticatedFunction(\n            \"toggleFilterLike\""))
    }

    func testPhysicalDebugBuildUsesAttestProviderByDefault() throws {
        let root = try repositoryRoot()
        let app = try String(contentsOf: root.appendingPathComponent("Sources/App/MooditApp.swift"))

        XCTAssertTrue(app.contains("MOODIT_USE_APP_CHECK_DEBUG_PROVIDER"))
        XCTAssertTrue(app.contains("#if targetEnvironment(simulator)"))
        XCTAssertTrue(app.contains("AppCheck.setAppCheckProviderFactory(MooditAppCheckProviderFactory())"))
        XCTAssertTrue(app.contains("AppCheck.setAppCheckProviderFactory(MooditDebugAppCheckProviderFactory())"))
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
        throw NSError(domain: "FilterDetailLikeIntegrationTests", code: 1)
    }
}
