import XCTest
@testable import Marketplace
import Models

final class SocialRepositoriesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - InMemoryReviewRepository

    func testReviewRepositoryAdaptsReviewStore() async throws {
        let store = ReviewStore(makerByFilterId: ["f": "m"])
        let repo = InMemoryReviewRepository(store: store)

        let review = try await repo.add(
            ReviewDraft(
                filterId: "f",
                authorId: "u1",
                authorHandle: "@u1",
                stars: 5,
                body: "great"
            ),
            now: now
        )
        XCTAssertEqual(review.filterId, "f")

        let listed = try await repo.reviews(for: "f")
        XCTAssertEqual(listed.count, 1)
    }

    func testReviewRepositoryDelegatesMakerReply() async throws {
        let store = ReviewStore(makerByFilterId: ["f": "m"])
        let repo = InMemoryReviewRepository(store: store)
        let review = try await repo.add(
            ReviewDraft(filterId: "f", authorId: "u1", authorHandle: "@u1", stars: 5, body: "hi"),
            now: now
        )

        let after = try await repo.attachMakerReply(
            reviewId: review.id, makerId: "m", body: "thanks", now: now
        )
        XCTAssertEqual(after.makerReply?.body, "thanks")
    }

    // MARK: - InMemoryFollowRepository

    func testFollowAndUnfollow() async throws {
        let repo = InMemoryFollowRepository()

        var following = try await repo.isFollowing(actor: "a", target: "b")
        XCTAssertFalse(following)

        _ = try await repo.follow(actor: "a", target: "b", now: now)
        following = try await repo.isFollowing(actor: "a", target: "b")
        XCTAssertTrue(following)

        try await repo.unfollow(actor: "a", target: "b")
        following = try await repo.isFollowing(actor: "a", target: "b")
        XCTAssertFalse(following)
    }

    func testFollowRejectsSelfTarget() async {
        let repo = InMemoryFollowRepository()
        do {
            _ = try await repo.follow(actor: "a", target: "a", now: now)
            XCTFail("Should reject self-follow")
        } catch let error as InMemoryFollowRepository.FollowError {
            XCTAssertEqual(error, .selfTarget)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBlockingTargetUnfollowsBothDirections() async throws {
        let repo = InMemoryFollowRepository()
        _ = try await repo.follow(actor: "a", target: "b", now: now)
        _ = try await repo.follow(actor: "b", target: "a", now: now)
        var aFollowsB = try await repo.isFollowing(actor: "a", target: "b")
        var bFollowsA = try await repo.isFollowing(actor: "b", target: "a")
        XCTAssertTrue(aFollowsB)
        XCTAssertTrue(bFollowsA)

        _ = try await repo.block(actor: "a", target: "b", now: now)

        aFollowsB = try await repo.isFollowing(actor: "a", target: "b")
        bFollowsA = try await repo.isFollowing(actor: "b", target: "a")
        XCTAssertFalse(aFollowsB)
        XCTAssertFalse(bFollowsA)

        let blocked = try await repo.blockedTargets(of: "a")
        XCTAssertEqual(blocked, ["b"])
    }

    func testBlockedTargetCannotFollowBlocker() async throws {
        let repo = InMemoryFollowRepository()
        _ = try await repo.block(actor: "a", target: "b", now: now)

        do {
            _ = try await repo.follow(actor: "b", target: "a", now: now)
            XCTFail("Blocked user should not be able to follow blocker")
        } catch let error as InMemoryFollowRepository.FollowError {
            XCTAssertEqual(error, .targetBlocked)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Reviewer fix: a blocker must not be allowed to follow the user they blocked.
    /// Block is a hard cut in either direction.
    func testBlockerCannotFollowBlockedTarget() async throws {
        let repo = InMemoryFollowRepository()
        _ = try await repo.block(actor: "a", target: "b", now: now)

        do {
            _ = try await repo.follow(actor: "a", target: "b", now: now)
            XCTFail("Blocker should not be able to follow blocked target")
        } catch let error as InMemoryFollowRepository.FollowError {
            XCTAssertEqual(error, .targetBlocked)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - InMemoryNotificationRepository

    func testNotificationsScopedToRecipient() async throws {
        let repo = InMemoryNotificationRepository()
        try await repo.enqueue(AppNotification(
            id: "n1", recipientUid: "alice", kind: .review,
            filterId: "f", actorUid: "bob", createdAt: now
        ))
        try await repo.enqueue(AppNotification(
            id: "n2", recipientUid: "bob", kind: .like,
            filterId: "f", actorUid: "alice", createdAt: now
        ))

        let alice = try await repo.notifications(for: "alice", limit: 10)
        XCTAssertEqual(alice.count, 1)
        XCTAssertEqual(alice.first?.id, "n1")

        let bob = try await repo.notifications(for: "bob", limit: 10)
        XCTAssertEqual(bob.count, 1)
        XCTAssertEqual(bob.first?.id, "n2")
    }

    func testMarkReadOnlyAffectsListedIDsForRecipient() async throws {
        let repo = InMemoryNotificationRepository()
        try await repo.enqueue(AppNotification(
            id: "n1", recipientUid: "alice", kind: .review, createdAt: now
        ))
        try await repo.enqueue(AppNotification(
            id: "n2", recipientUid: "alice", kind: .like, createdAt: now
        ))

        try await repo.markRead(["n1"], for: "alice")
        let after = try await repo.notifications(for: "alice", limit: 10)

        let n1 = after.first(where: { $0.id == "n1" })
        let n2 = after.first(where: { $0.id == "n2" })
        XCTAssertEqual(n1?.isRead, true)
        XCTAssertEqual(n2?.isRead, false)
    }

    // MARK: - InMemoryFeedRepository

    func testFeedReturnsLatestFirst() async throws {
        let repo = InMemoryFeedRepository()
        await repo.seed([
            FeedItem(id: "a", filterId: "f1", source: .forYou, downloadCount: 100, rating: 4.5, surfacedAt: now.addingTimeInterval(-10)),
            FeedItem(id: "b", filterId: "f2", source: .forYou, downloadCount: 200, rating: 4.7, surfacedAt: now)
        ])

        let items = try await repo.feed(for: .forYou, viewer: nil, limit: 5)
        XCTAssertEqual(items.map(\.id), ["b", "a"])
    }
}
