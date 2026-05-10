import FirebaseFunctions
import Marketplace
import Models
import XCTest
@testable import moodit

final class FilterDownloadProgressStateTests: XCTestCase {
    func testCinestillNightUsesBundledSeedResource() {
        let filter = Filter(
            id: UUID(uuidString: "01900B14-7B1C-7C20-A4F4-000000000005")!,
            title: "Cinestill Night",
            version: "1.0.0",
            author: FilterAuthor(uid: "J14Dg6JaH0M25xpcOkCEMJH3qFy1", displayName: "mooditor"),
            category: .mood,
            engine: FilterEngineDescriptor(
                type: .lutParams,
                minAppVersion: "1.0.0",
                minIOSVersion: "17.0",
                lutSize: 33,
                lutFile: "SeedFilters/luts/cinestill-night.png"
            )
        )

        XCTAssertTrue(FilterDownloadProgressScreen.hasBundledPackageResource(for: filter))
    }

    func testMissingSignedURLOnPaidOrPaywalledDetailRoutesToEntitlement() throws {
        let response = try FilterDetailResponse(json: [
            "filter": [
                "id": "paid-filter",
                "title": "Paid Film",
                "category": "cinematic",
                "status": "approved",
                "priceCoins": 120,
                "author": [
                    "uid": "maker-1",
                    "displayName": "Maker"
                ],
            ],
            "paywall": true,
        ])

        XCTAssertEqual(DownloadFailureReason.missingSignedURL(detail: response), .entitlementRequired)
        XCTAssertEqual(DownloadPhase.failed(.entitlementRequired).title, "구매 필요")
    }

    func testFunctionErrorsMapToUserVisibleDownloadReasons() {
        let notFound = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.notFound.rawValue
        )
        let permissionDenied = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.permissionDenied.rawValue
        )
        let internalError = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.internal.rawValue
        )

        XCTAssertEqual(DownloadFailureReason(error: notFound, stage: .detailFetch), .filterUnavailable)
        XCTAssertEqual(DownloadFailureReason(error: permissionDenied, stage: .detailFetch), .entitlementRequired)
        XCTAssertEqual(DownloadFailureReason(error: internalError, stage: .detailFetch), .packageNotReady)
    }

    func testPackageErrorsDoNotKeepFailureAtOneHundredPercent() {
        XCTAssertEqual(
            DownloadFailureReason(error: SignedFilterPackageDownloader.DownloadError.invalidLUTPayload, stage: .packageDownload),
            .packageValidationFailed
        )
        XCTAssertLessThan(DownloadFailureReason.packageValidationFailed.maximumFailureProgress, 1)
        XCTAssertEqual(DownloadPhase.syncFailed.title, "동기화 필요")
        XCTAssertTrue(DownloadPhase.syncFailed.description.contains("다운로드는 완료됐지만"))
    }
}
