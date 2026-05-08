import XCTest
@testable import Marketplace
import Models

final class ReviewStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Happy paths

    func testAcceptsFirstReviewAndDerivesVerifiedDownload() async throws {
        let store = ReviewStore(
            makerByFilterId: ["sunset": "maker-jisoo"],
            downloads: [.init(authorId: "u1", filterId: "sunset")]
        )

        let saved = try await store.add(
            draft(authorId: "u1", filterId: "sunset", stars: 5, body: "정말 좋아요"),
            now: now
        )

        XCTAssertEqual(saved.stars, 5)
        XCTAssertEqual(saved.body, "정말 좋아요")
        XCTAssertTrue(saved.isVerifiedDownload)
        XCTAssertNil(saved.makerReply)
    }

    func testNotVerifiedWhenUserHasNotDownloaded() async throws {
        let store = ReviewStore(makerByFilterId: ["sunset": "maker"])

        let review = try await store.add(
            draft(authorId: "u-anon", filterId: "sunset", stars: 4, body: "써보고 싶었어요"),
            now: now
        )

        XCTAssertFalse(review.isVerifiedDownload)
    }

    func testAddRecordedDownloadAfterCreatesVerifiedReview() async throws {
        let store = ReviewStore()
        await store.recordDownload(authorId: "u1", filterId: "f1")

        let review = try await store.add(
            draft(authorId: "u1", filterId: "f1", stars: 3, body: "괜찮아요"),
            now: now
        )

        XCTAssertTrue(review.isVerifiedDownload)
    }

    // MARK: - 1-review-per-(user, filter) enforcement

    func testRejectsSecondReviewForSamePair() async throws {
        let store = ReviewStore(makerByFilterId: ["sunset": "m"])
        _ = try await store.add(draft(authorId: "u1", filterId: "sunset", stars: 5, body: "처음"), now: now)

        do {
            _ = try await store.add(
                draft(authorId: "u1", filterId: "sunset", stars: 4, body: "두 번째"),
                now: now
            )
            XCTFail("Second review should throw duplicateReview")
        } catch let error as ReviewStore.AddError {
            XCTAssertEqual(error, .duplicateReview)
        }
    }

    func testAllowsSecondReviewForDifferentFilter() async throws {
        let store = ReviewStore()
        _ = try await store.add(draft(authorId: "u1", filterId: "f1", stars: 5, body: "first"), now: now)
        _ = try await store.add(draft(authorId: "u1", filterId: "f2", stars: 4, body: "second"), now: now)

        let f1 = await store.reviews(for: "f1")
        let f2 = await store.reviews(for: "f2")
        XCTAssertEqual(f1.count, 1)
        XCTAssertEqual(f2.count, 1)
    }

    // MARK: - Validation

    func testRejectsStarsOutOfRange() async {
        let store = ReviewStore()
        for value in [-1, 0, 6, 10] {
            do {
                _ = try await store.add(draft(stars: value, body: "x"), now: now)
                XCTFail("Should reject stars=\(value)")
            } catch let error as ReviewStore.AddError {
                XCTAssertEqual(error, .starsOutOfRange(value))
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRejectsEmptyBody() async {
        let store = ReviewStore()
        do {
            _ = try await store.add(draft(stars: 4, body: "   "), now: now)
            XCTFail("Should reject empty body")
        } catch let error as ReviewStore.AddError {
            XCTAssertEqual(error, .bodyEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRejectsBodyOverLimit() async {
        let store = ReviewStore()
        let body = String(repeating: "가", count: ReviewLimits.bodyMaxLength + 1)
        do {
            _ = try await store.add(draft(stars: 5, body: body), now: now)
            XCTFail("Should reject too-long body")
        } catch let error as ReviewStore.AddError {
            XCTAssertEqual(error, .bodyTooLong(ReviewLimits.bodyMaxLength + 1))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Maker reply

    func testMakerCanReplyOnceOnly() async throws {
        let store = ReviewStore(makerByFilterId: ["f1": "maker-a"])
        let review = try await store.add(
            draft(authorId: "u1", filterId: "f1", stars: 5, body: "thanks"),
            now: now
        )

        let after = try await store.attachMakerReply(
            reviewId: review.id, makerId: "maker-a", body: "감사합니다", now: now
        )
        XCTAssertEqual(after.makerReply?.body, "감사합니다")

        do {
            _ = try await store.attachMakerReply(
                reviewId: review.id, makerId: "maker-a", body: "한 번 더", now: now
            )
            XCTFail("Second reply should throw")
        } catch let error as ReviewStore.ReplyError {
            XCTAssertEqual(error, .duplicateReply)
        }
    }

    func testNonMakerCannotReply() async throws {
        let store = ReviewStore(makerByFilterId: ["f1": "maker-a"])
        let review = try await store.add(
            draft(authorId: "u1", filterId: "f1", stars: 5, body: "thanks"),
            now: now
        )

        do {
            _ = try await store.attachMakerReply(
                reviewId: review.id, makerId: "stranger", body: "I'm not the maker", now: now
            )
            XCTFail("Non-maker reply should throw")
        } catch let error as ReviewStore.ReplyError {
            XCTAssertEqual(error, .unauthorizedMaker)
        }
    }

    func testReplyToMissingReviewThrows() async {
        let store = ReviewStore(makerByFilterId: ["f1": "m"])
        do {
            _ = try await store.attachMakerReply(
                reviewId: UUID(), makerId: "m", body: "ok", now: now
            )
            XCTFail("Should throw")
        } catch let error as ReviewStore.ReplyError {
            XCTAssertEqual(error, .reviewNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReplyBodyValidations() async throws {
        let store = ReviewStore(makerByFilterId: ["f1": "m"])
        let review = try await store.add(
            draft(authorId: "u1", filterId: "f1", stars: 5, body: "hi"),
            now: now
        )

        do {
            _ = try await store.attachMakerReply(reviewId: review.id, makerId: "m", body: "  ", now: now)
            XCTFail("Empty reply should throw")
        } catch let error as ReviewStore.ReplyError {
            XCTAssertEqual(error, .bodyEmpty)
        }

        let long = String(repeating: "ㅁ", count: ReviewLimits.makerReplyMaxLength + 1)
        do {
            _ = try await store.attachMakerReply(reviewId: review.id, makerId: "m", body: long, now: now)
            XCTFail("Long reply should throw")
        } catch let error as ReviewStore.ReplyError {
            XCTAssertEqual(error, .bodyTooLong(ReviewLimits.makerReplyMaxLength + 1))
        }
    }

    // MARK: - Helpers

    private func draft(
        authorId: String = "u-default",
        filterId: String = "f-default",
        stars: Int = 5,
        body: String = "okay",
        intensity: Int? = nil
    ) -> ReviewDraft {
        ReviewDraft(
            filterId: filterId,
            authorId: authorId,
            authorHandle: "@" + authorId,
            stars: stars,
            body: body,
            intensity: intensity
        )
    }
}
