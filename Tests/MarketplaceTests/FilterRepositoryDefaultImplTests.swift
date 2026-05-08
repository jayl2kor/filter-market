import Foundation
import XCTest
@testable import Marketplace
@testable import Models

/// `FilterRepository` protocol default impl 테스트.
///
/// `trending(limit:)`, `newFilters(limit:)`, `search(query:category:limit:)` 가
/// `MockFilterRepository` 같은 단순 listFilters() 구현 위에서 올바르게 동작하는지 검증.
/// FirestoreFilterRepository는 backend 단 정렬을 사용하므로 여기서는 테스트하지 않음 (별도 emulator integration test 영역).
final class FilterRepositoryDefaultImplTests: XCTestCase {
    private func makeFilter(
        title: String,
        category: FilterCategory = .cinematic,
        useCount: Int = 0,
        status: FilterStatus = .approved,
        createdAt: Date? = nil,
        author: String = "tester"
    ) -> Filter {
        Filter(
            id: UUID(),
            title: title,
            version: "1.0.0",
            author: FilterAuthor(uid: author, displayName: author),
            category: category,
            engine: FilterEngineDescriptor(
                type: .lutParams,
                minAppVersion: "1.0.0",
                minIOSVersion: "17.0",
                lutSize: 33,
                lutFile: "x.png"
            ),
            useCount: useCount,
            createdAt: createdAt,
            status: status,
            priceCoins: 0,
            coverURL: nil,
            ratingAvg: nil,
            downloadCount: 0
        )
    }

    // MARK: - trending

    func testTrendingSortsByUseCountDescending() async throws {
        let filters = [
            makeFilter(title: "Low", useCount: 10),
            makeFilter(title: "High", useCount: 1000),
            makeFilter(title: "Mid", useCount: 100)
        ]
        let repo = MockFilterRepository(filters: filters)
        let result = try await repo.trending(limit: 24)
        XCTAssertEqual(result.map(\.title), ["High", "Mid", "Low"])
    }

    func testTrendingExcludesNonApproved() async throws {
        let filters = [
            makeFilter(title: "Approved", useCount: 1, status: .approved),
            makeFilter(title: "Pending", useCount: 100, status: .pendingReview),
            makeFilter(title: "Rejected", useCount: 200, status: .rejected)
        ]
        let repo = MockFilterRepository(filters: filters)
        let result = try await repo.trending()
        XCTAssertEqual(result.map(\.title), ["Approved"])
    }

    func testTrendingHonorsLimit() async throws {
        let filters = (0..<10).map { makeFilter(title: "F\($0)", useCount: $0) }
        let repo = MockFilterRepository(filters: filters)
        let result = try await repo.trending(limit: 3)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.first?.title, "F9")
    }

    // MARK: - newFilters

    func testNewFiltersSortsByCreatedAtDescendingWhenDatesPresent() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let filters = [
            makeFilter(title: "Old", createdAt: now),
            makeFilter(title: "New", createdAt: now.addingTimeInterval(86_400)),
            makeFilter(title: "Newest", createdAt: now.addingTimeInterval(172_800))
        ]
        let repo = MockFilterRepository(filters: filters)
        let result = try await repo.newFilters()
        XCTAssertEqual(result.map(\.title), ["Newest", "New", "Old"])
    }

    func testNewFiltersPreservesOriginalOrderWhenNoDates() async throws {
        let filters = [
            makeFilter(title: "A"),
            makeFilter(title: "B"),
            makeFilter(title: "C")
        ]
        let repo = MockFilterRepository(filters: filters)
        let result = try await repo.newFilters()
        XCTAssertEqual(result.map(\.title), ["A", "B", "C"])
    }

    // MARK: - search

    func testSearchByQueryMatchesTitleCaseInsensitive() async throws {
        let filters = [
            makeFilter(title: "Sunset Vibes"),
            makeFilter(title: "Midnight Walk"),
            makeFilter(title: "Velvet Dusk")
        ]
        let repo = MockFilterRepository(filters: filters)
        let result = try await repo.search(query: "sunset")
        XCTAssertEqual(result.map(\.title), ["Sunset Vibes"])
    }

    func testSearchByQueryMatchesAuthor() async throws {
        let filters = [
            makeFilter(title: "A", author: "alex"),
            makeFilter(title: "B", author: "mina")
        ]
        let repo = MockFilterRepository(filters: filters)
        let result = try await repo.search(query: "alex")
        XCTAssertEqual(result.map(\.title), ["A"])
    }

    func testSearchFilteredByCategory() async throws {
        let filters = [
            makeFilter(title: "Cine1", category: .cinematic),
            makeFilter(title: "Vint1", category: .vintage),
            makeFilter(title: "Cine2", category: .cinematic)
        ]
        let repo = MockFilterRepository(filters: filters)
        let result = try await repo.search(query: "", category: .cinematic)
        XCTAssertEqual(Set(result.map(\.title)), Set(["Cine1", "Cine2"]))
    }

    func testSearchEmptyQueryReturnsAllApproved() async throws {
        let filters = [
            makeFilter(title: "A", status: .approved),
            makeFilter(title: "B", status: .pendingReview)
        ]
        let repo = MockFilterRepository(filters: filters)
        let result = try await repo.search(query: "")
        XCTAssertEqual(result.map(\.title), ["A"])
    }
}
