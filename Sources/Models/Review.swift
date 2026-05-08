import Foundation

/// A user review for a filter — App Store style: stars + body, plus optional metadata.
///
/// See `docs/REVIEWS_MIGRATION.md` for the policy:
/// - 1 review per `(authorId, filterId)`.
/// - Reviewer may include `intensity`, `lightingTag`, `photoUrl`.
/// - `isVerifiedDownload` is `true` when the reviewer has previously downloaded this filter.
/// - `makerReply` is optional, single-shot — only the filter's maker may post one.
public struct Review: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let filterId: String
    public let authorId: String
    public let authorHandle: String
    public let stars: Int
    public let body: String
    public let photoUrl: URL?
    public let intensity: Int?
    public let lightingTag: LightingTag?
    public let isVerifiedDownload: Bool
    public var helpfulCount: Int
    public var makerReply: MakerReply?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        filterId: String,
        authorId: String,
        authorHandle: String,
        stars: Int,
        body: String,
        photoUrl: URL? = nil,
        intensity: Int? = nil,
        lightingTag: LightingTag? = nil,
        isVerifiedDownload: Bool,
        helpfulCount: Int = 0,
        makerReply: MakerReply? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.filterId = filterId
        self.authorId = authorId
        self.authorHandle = authorHandle
        self.stars = stars
        self.body = body
        self.photoUrl = photoUrl
        self.intensity = intensity
        self.lightingTag = lightingTag
        self.isVerifiedDownload = isVerifiedDownload
        self.helpfulCount = helpfulCount
        self.makerReply = makerReply
        self.createdAt = createdAt
    }
}

/// Single maker reply attached to a review. App Store rule: one reply per review.
public struct MakerReply: Codable, Equatable, Sendable {
    public let body: String
    public let createdAt: Date

    public init(body: String, createdAt: Date) {
        self.body = body
        self.createdAt = createdAt
    }
}

/// Lighting condition tag attached to a review's photo. Mirrors localization keys
/// `reviews.lighting.*` in `Localizable.xcstrings`.
public enum LightingTag: String, Codable, CaseIterable, Sendable {
    case cafe
    case food
    case indoor
    case night
    case outdoor
    case portrait
    case selfie
}

/// Mutable input for creating a review. Server validates before constructing the `Review`.
public struct ReviewDraft: Sendable {
    public let filterId: String
    public let authorId: String
    public let authorHandle: String
    public let stars: Int
    public let body: String
    public let photoUrl: URL?
    public let intensity: Int?
    public let lightingTag: LightingTag?

    public init(
        filterId: String,
        authorId: String,
        authorHandle: String,
        stars: Int,
        body: String,
        photoUrl: URL? = nil,
        intensity: Int? = nil,
        lightingTag: LightingTag? = nil
    ) {
        self.filterId = filterId
        self.authorId = authorId
        self.authorHandle = authorHandle
        self.stars = stars
        self.body = body
        self.photoUrl = photoUrl
        self.intensity = intensity
        self.lightingTag = lightingTag
    }
}

/// Field limits enforced by `ReviewStore` and exposed for UI clamping.
public enum ReviewLimits {
    public static let starsRange: ClosedRange<Int> = 1 ... 5
    public static let bodyMaxLength: Int = 280
    public static let makerReplyMaxLength: Int = 200
    public static let intensityRange: ClosedRange<Int> = 0 ... 100
}
