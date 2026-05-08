import Foundation
import Models

/// In-memory review repository with the App Store-style policy applied:
/// - 1 review per `(authorId, filterId)`
/// - 1 maker reply per review (only the filter's maker may post)
/// - `isVerifiedDownload` flag is derived from the user's download history
///
/// This is the canonical fixture the UI binds to until the Firestore-backed
/// implementation lands in `US-013`.
public actor ReviewStore {

    public enum AddError: Error, Equatable, Sendable {
        case duplicateReview
        case starsOutOfRange(Int)
        case bodyEmpty
        case bodyTooLong(Int)
        case intensityOutOfRange(Int)
    }

    public enum ReplyError: Error, Equatable, Sendable {
        case reviewNotFound
        case duplicateReply
        case bodyEmpty
        case bodyTooLong(Int)
        case unauthorizedMaker
    }

    /// Caller-supplied filter → maker uid map. Maker reply is only accepted from the maker.
    private var makerByFilterId: [String: String]

    /// `(authorId, filterId)` set of completed downloads — used to set `isVerifiedDownload`.
    private var downloads: Set<DownloadKey>

    private var reviewsById: [UUID: Review] = [:]
    private var reviewsByFilter: [String: [UUID]] = [:]
    private var existingByAuthorFilter: [DownloadKey: UUID] = [:]

    public init(
        makerByFilterId: [String: String] = [:],
        downloads: Set<DownloadKey> = []
    ) {
        self.makerByFilterId = makerByFilterId
        self.downloads = downloads
    }

    public func registerMaker(filterId: String, makerId: String) {
        makerByFilterId[filterId] = makerId
    }

    public func recordDownload(authorId: String, filterId: String) {
        downloads.insert(DownloadKey(authorId: authorId, filterId: filterId))
    }

    /// Append a new review. Throws on policy violation; success returns the persisted record.
    @discardableResult
    public func add(_ draft: ReviewDraft, now: Date = Date()) throws -> Review {
        try validate(draft: draft)
        let key = DownloadKey(authorId: draft.authorId, filterId: draft.filterId)
        if existingByAuthorFilter[key] != nil {
            throw AddError.duplicateReview
        }

        let review = Review(
            filterId: draft.filterId,
            authorId: draft.authorId,
            authorHandle: draft.authorHandle,
            stars: draft.stars,
            body: draft.body.trimmingCharacters(in: .whitespacesAndNewlines),
            photoUrl: draft.photoUrl,
            intensity: draft.intensity,
            lightingTag: draft.lightingTag,
            isVerifiedDownload: downloads.contains(key),
            createdAt: now
        )

        reviewsById[review.id] = review
        reviewsByFilter[review.filterId, default: []].append(review.id)
        existingByAuthorFilter[key] = review.id
        return review
    }

    /// Attach a maker reply to a review. Maker authorization and one-shot policy enforced.
    @discardableResult
    public func attachMakerReply(
        reviewId: UUID,
        makerId: String,
        body: String,
        now: Date = Date()
    ) throws -> Review {
        guard var review = reviewsById[reviewId] else {
            throw ReplyError.reviewNotFound
        }
        guard makerByFilterId[review.filterId] == makerId else {
            throw ReplyError.unauthorizedMaker
        }
        if review.makerReply != nil {
            throw ReplyError.duplicateReply
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ReplyError.bodyEmpty }
        guard trimmed.count <= ReviewLimits.makerReplyMaxLength else {
            throw ReplyError.bodyTooLong(trimmed.count)
        }

        review.makerReply = MakerReply(body: trimmed, createdAt: now)
        reviewsById[reviewId] = review
        return review
    }

    public func reviews(for filterId: String) -> [Review] {
        let ids = reviewsByFilter[filterId] ?? []
        return ids.compactMap { reviewsById[$0] }
    }

    public func review(by id: UUID) -> Review? {
        reviewsById[id]
    }

    // MARK: - Internals

    public struct DownloadKey: Hashable, Sendable {
        public let authorId: String
        public let filterId: String

        public init(authorId: String, filterId: String) {
            self.authorId = authorId
            self.filterId = filterId
        }
    }

    private func validate(draft: ReviewDraft) throws {
        guard ReviewLimits.starsRange.contains(draft.stars) else {
            throw AddError.starsOutOfRange(draft.stars)
        }
        let trimmed = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AddError.bodyEmpty }
        guard trimmed.count <= ReviewLimits.bodyMaxLength else {
            throw AddError.bodyTooLong(trimmed.count)
        }
        if let intensity = draft.intensity {
            guard ReviewLimits.intensityRange.contains(intensity) else {
                throw AddError.intensityOutOfRange(intensity)
            }
        }
    }
}
