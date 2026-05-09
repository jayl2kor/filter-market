import Foundation
import Testing
@testable import moodit

@Suite("Filter detail response parsing")
struct FilterDetailResponseParsingTests {
    @Test("userHasLiked and backend counters survive mock adapter")
    func userLikeStateAndCountersMapToFilterDetailMock() throws {
        let response = try FilterDetailResponse(json: [
            "filter": [
                "id": "filter-1",
                "title": "Backend Film",
                "description": "Remote description",
                "category": "vintage",
                "status": "approved",
                "useCount": 5,
                "downloadCount": 12,
                "priceCoins": 0,
                "ratingAvg": 4.7,
                "reviewCount": 3,
                "likeCount": 9,
                "sampleCount": 1,
                "tags": ["warm", "#film"],
                "author": [
                    "uid": "maker-1",
                    "displayName": "Maker"
                ],
            ],
            "samples": [
                [
                    "id": "sample-1",
                    "kind": "user",
                    "categoryHint": "portrait",
                    "coverURL": "https://cdn.example.com/sample.jpg",
                    "thumbnailURL": "https://cdn.example.com/sample-thumb.jpg",
                ]
            ],
            "reviews": [
                [
                    "authorDisplayName": "Reviewer",
                    "stars": 5,
                    "body": "Great",
                    "isVerifiedDownload": true,
                ]
            ],
            "userHasLiked": true,
            "signedDownloadURL": "https://signed.example.com/filter.fmpkg",
            "expiresAt": 1_800_000_000.0,
        ])

        let mock = response.toMock()

        #expect(response.userHasLiked)
        #expect(mock.userHasLiked)
        #expect(mock.likeCount == 9)
        #expect(mock.reviewCount == 3)
        #expect(mock.samples.count == 1)
        #expect(mock.reviews.count == 1)
        #expect(mock.tags == ["#warm", "#film"])
    }
}
