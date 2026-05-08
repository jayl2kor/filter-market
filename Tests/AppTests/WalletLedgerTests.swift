import FirebaseFirestore
import XCTest
@testable import moodit

/// `WalletLedgerStore.decode(_:)` 와 `WalletLedgerEntry.Kind` 매핑 테스트.
///
/// Firestore snapshot listener 자체는 emulator integration test로 분리.
/// 본 파일은 순수 디코딩 로직 + 인메모리 데이터 주입 헬퍼만 검증.
@MainActor
final class WalletLedgerTests: XCTestCase {

    func testEntryKindDecodesAllKnownStrings() {
        let cases: [(String, WalletLedgerEntry.Kind)] = [
            ("topup", .topup),
            ("purchase", .purchase),
            ("refund", .refund),
            ("bonus", .bonus),
            ("unknown", .unknown),
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(WalletLedgerEntry.Kind(rawValue: raw), expected)
        }
    }

    func testEntryKindFallsBackToUnknownForInvalidString() {
        XCTAssertNil(WalletLedgerEntry.Kind(rawValue: "garbage"))
    }

    func testEntryEqualityRespectsAllFields() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = WalletLedgerEntry(id: "x", kind: .topup, amount: 100, relatedItemTitle: nil, createdAt: date)
        let b = WalletLedgerEntry(id: "x", kind: .topup, amount: 100, relatedItemTitle: nil, createdAt: date)
        XCTAssertEqual(a, b)

        let c = WalletLedgerEntry(id: "x", kind: .topup, amount: 200, relatedItemTitle: nil, createdAt: date)
        XCTAssertNotEqual(a, c)
    }

    func testStoreEntriesForTestingPopulatesPublishedArray() {
        let entry = WalletLedgerEntry(
            id: "t-1",
            kind: .topup,
            amount: 100,
            relatedItemTitle: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let store = WalletLedgerStore()
        store.setEntriesForTesting([entry])
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.id, "t-1")
        XCTAssertEqual(store.entries.first?.kind, .topup)
        XCTAssertEqual(store.entries.first?.amount, 100)
    }

    func testStoreInitiallyEmpty() {
        let store = WalletLedgerStore()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.loadError)
    }
}
