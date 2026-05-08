import Foundation
import Models

/// Domain models for the social/review layer (Phase 3 §5.1).
///
/// These mirror the Firestore documents under `/follows`, `/blocks`,
/// `/users/{uid}/notifications`, and the in-memory feed projections used by
/// the For You / Following surfaces.

public struct FollowEdge: Hashable, Codable, Sendable {
    public let actorUid: String
    public let targetUid: String
    public let createdAt: Date

    public init(actorUid: String, targetUid: String, createdAt: Date) {
        self.actorUid = actorUid
        self.targetUid = targetUid
        self.createdAt = createdAt
    }
}

public struct BlockEdge: Hashable, Codable, Sendable {
    public let actorUid: String
    public let targetUid: String
    public let createdAt: Date

    public init(actorUid: String, targetUid: String, createdAt: Date) {
        self.actorUid = actorUid
        self.targetUid = targetUid
        self.createdAt = createdAt
    }
}

public struct AppNotification: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case like
        case review
        case download
        case followRequest
        case system
    }

    public let id: String
    public let recipientUid: String
    public let kind: Kind
    public let filterId: String?
    public let actorUid: String?
    public let createdAt: Date
    public var isRead: Bool

    public init(
        id: String,
        recipientUid: String,
        kind: Kind,
        filterId: String? = nil,
        actorUid: String? = nil,
        createdAt: Date,
        isRead: Bool = false
    ) {
        self.id = id
        self.recipientUid = recipientUid
        self.kind = kind
        self.filterId = filterId
        self.actorUid = actorUid
        self.createdAt = createdAt
        self.isRead = isRead
    }
}

public struct FeedItem: Identifiable, Hashable, Codable, Sendable {
    public enum Source: String, Codable, Sendable {
        case forYou
        case following
        case trending
    }

    public let id: String
    public let filterId: String
    public let source: Source
    public let downloadCount: Int
    public let rating: Double
    public let surfacedAt: Date

    public init(
        id: String,
        filterId: String,
        source: Source,
        downloadCount: Int,
        rating: Double,
        surfacedAt: Date
    ) {
        self.id = id
        self.filterId = filterId
        self.source = source
        self.downloadCount = downloadCount
        self.rating = rating
        self.surfacedAt = surfacedAt
    }
}

// MARK: - Repository protocols

public protocol ReviewRepository: Sendable {
    func reviews(for filterId: String) async throws -> [Review]
    func add(_ draft: ReviewDraft, now: Date) async throws -> Review
    func attachMakerReply(reviewId: UUID, makerId: String, body: String, now: Date) async throws -> Review
}

public protocol FollowRepository: Sendable {
    func isFollowing(actor: String, target: String) async throws -> Bool
    func follow(actor: String, target: String, now: Date) async throws -> FollowEdge
    func unfollow(actor: String, target: String) async throws
    func block(actor: String, target: String, now: Date) async throws -> BlockEdge
    func unblock(actor: String, target: String) async throws
    func blockedTargets(of actor: String) async throws -> Set<String>
}

public protocol NotificationRepository: Sendable {
    func notifications(for recipient: String, limit: Int) async throws -> [AppNotification]
    func enqueue(_ notification: AppNotification) async throws
    func markRead(_ ids: [String], for recipient: String) async throws
}

public protocol FeedRepository: Sendable {
    func feed(for source: FeedItem.Source, viewer: String?, limit: Int) async throws -> [FeedItem]
}

// MARK: - InMemory repositories (replace mock UI bindings without behavior change)

/// Adapter that exposes the existing `ReviewStore` actor through `ReviewRepository`.
public struct InMemoryReviewRepository: ReviewRepository {
    private let store: ReviewStore

    public init(store: ReviewStore) {
        self.store = store
    }

    public func reviews(for filterId: String) async throws -> [Review] {
        await store.reviews(for: filterId)
    }

    public func add(_ draft: ReviewDraft, now: Date) async throws -> Review {
        try await store.add(draft, now: now)
    }

    public func attachMakerReply(
        reviewId: UUID,
        makerId: String,
        body: String,
        now: Date
    ) async throws -> Review {
        try await store.attachMakerReply(reviewId: reviewId, makerId: makerId, body: body, now: now)
    }
}

public actor InMemoryFollowRepository: FollowRepository {
    public enum FollowError: Error, Equatable, Sendable {
        case selfTarget
        case targetBlocked
    }

    private var follows: [String: FollowEdge] = [:]      // key = actor + ":" + target
    private var blocks: [String: BlockEdge] = [:]

    public init() {}

    public func isFollowing(actor: String, target: String) async throws -> Bool {
        follows[edgeKey(actor, target)] != nil
    }

    public func follow(actor: String, target: String, now: Date) async throws -> FollowEdge {
        guard actor != target else { throw FollowError.selfTarget }
        // Block is a hard cut in either direction — the blocker cannot follow the
        // blocked user, and the blocked user cannot follow the blocker.
        if blocks[edgeKey(target, actor)] != nil || blocks[edgeKey(actor, target)] != nil {
            throw FollowError.targetBlocked
        }
        let edge = FollowEdge(actorUid: actor, targetUid: target, createdAt: now)
        follows[edgeKey(actor, target)] = edge
        return edge
    }

    public func unfollow(actor: String, target: String) async throws {
        follows.removeValue(forKey: edgeKey(actor, target))
    }

    public func block(actor: String, target: String, now: Date) async throws -> BlockEdge {
        guard actor != target else { throw FollowError.selfTarget }
        let edge = BlockEdge(actorUid: actor, targetUid: target, createdAt: now)
        blocks[edgeKey(actor, target)] = edge
        // Block also unfollows in both directions to match docs/REVIEWS_MIGRATION.md §3.
        follows.removeValue(forKey: edgeKey(actor, target))
        follows.removeValue(forKey: edgeKey(target, actor))
        return edge
    }

    public func unblock(actor: String, target: String) async throws {
        blocks.removeValue(forKey: edgeKey(actor, target))
    }

    public func blockedTargets(of actor: String) async throws -> Set<String> {
        let entries = blocks.values.filter { $0.actorUid == actor }
        return Set(entries.map(\.targetUid))
    }

    private func edgeKey(_ actor: String, _ target: String) -> String {
        actor + "::" + target
    }
}

public actor InMemoryNotificationRepository: NotificationRepository {
    private var byRecipient: [String: [AppNotification]] = [:]

    public init() {}

    public func notifications(for recipient: String, limit: Int) async throws -> [AppNotification] {
        let all = byRecipient[recipient] ?? []
        return Array(all.sorted(by: { $0.createdAt > $1.createdAt }).prefix(limit))
    }

    public func enqueue(_ notification: AppNotification) async throws {
        byRecipient[notification.recipientUid, default: []].append(notification)
    }

    public func markRead(_ ids: [String], for recipient: String) async throws {
        let target = Set(ids)
        let updated = (byRecipient[recipient] ?? []).map { item -> AppNotification in
            guard target.contains(item.id) else { return item }
            var copy = item
            copy.isRead = true
            return copy
        }
        byRecipient[recipient] = updated
    }
}

public actor InMemoryFeedRepository: FeedRepository {
    private var items: [FeedItem.Source: [FeedItem]] = [:]

    public init() {}

    public func seed(_ items: [FeedItem]) {
        for item in items {
            self.items[item.source, default: []].append(item)
        }
    }

    public func feed(for source: FeedItem.Source, viewer _: String?, limit: Int) async throws -> [FeedItem] {
        Array((items[source] ?? []).sorted(by: { $0.surfacedAt > $1.surfacedAt }).prefix(limit))
    }
}
