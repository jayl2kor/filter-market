import XCTest
@testable import moodit

/// `IAPProductIDs` 의 SKU 상수 + 헬퍼 (코인 매핑, Pro 판정) 테스트.
/// StoreKitManager 자체는 StoreKit Test framework (.storekit config) 가 필요하므로
/// 별도 통합 테스트로 분리 — 이 테스트는 ID 일관성과 매핑 헬퍼만 검증.
final class IAPProductIDsTests: XCTestCase {

    func testCoinIDsContainsAllFourPackages() {
        XCTAssertEqual(
            Set(IAPProductIDs.coinIDs),
            Set([
                IAPProductIDs.coins100,
                IAPProductIDs.coins550,
                IAPProductIDs.coins1200,
                IAPProductIDs.coins3000
            ])
        )
    }

    func testProIDsContainsMonthlyAndYearly() {
        XCTAssertEqual(
            Set(IAPProductIDs.proIDs),
            Set([
                IAPProductIDs.proMonthly,
                IAPProductIDs.proYearly
            ])
        )
    }

    func testAllIDsIsCoinsPlusProInOrder() {
        XCTAssertEqual(
            IAPProductIDs.allIDs,
            IAPProductIDs.coinIDs + IAPProductIDs.proIDs
        )
    }

    func testCoinAmountMatchesEachSku() {
        XCTAssertEqual(IAPProductIDs.coinAmount(for: IAPProductIDs.coins100), 100)
        XCTAssertEqual(IAPProductIDs.coinAmount(for: IAPProductIDs.coins550), 550)
        XCTAssertEqual(IAPProductIDs.coinAmount(for: IAPProductIDs.coins1200), 1200)
        XCTAssertEqual(IAPProductIDs.coinAmount(for: IAPProductIDs.coins3000), 3000)
    }

    func testCoinAmountReturnsNilForProSkus() {
        XCTAssertNil(IAPProductIDs.coinAmount(for: IAPProductIDs.proMonthly))
        XCTAssertNil(IAPProductIDs.coinAmount(for: IAPProductIDs.proYearly))
    }

    func testCoinAmountReturnsNilForUnknownSku() {
        XCTAssertNil(IAPProductIDs.coinAmount(for: "not.a.real.sku"))
    }

    func testIsProSubscriptionReturnsTrueForProSkus() {
        XCTAssertTrue(IAPProductIDs.isProSubscription(IAPProductIDs.proMonthly))
        XCTAssertTrue(IAPProductIDs.isProSubscription(IAPProductIDs.proYearly))
    }

    func testIsProSubscriptionReturnsFalseForCoinSkus() {
        for id in IAPProductIDs.coinIDs {
            XCTAssertFalse(IAPProductIDs.isProSubscription(id))
        }
    }

    func testProductIDsAreNonEmptyAndUnique() {
        for id in IAPProductIDs.allIDs {
            XCTAssertFalse(id.isEmpty)
        }
        XCTAssertEqual(Set(IAPProductIDs.allIDs).count, IAPProductIDs.allIDs.count)
    }
}
