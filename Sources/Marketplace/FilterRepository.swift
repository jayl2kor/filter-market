import Foundation
import Models

public protocol FilterRepository: Sendable {
    func listFilters() async throws -> [Filter]
    func filter(id: Filter.ID) async throws -> Filter
}

public extension FilterRepository {
    /// 트렌딩 — `useCount` 내림차순. 기본 구현은 listFilters 결과를 메모리에서 정렬.
    /// FirestoreFilterRepository 같은 실제 구현은 backend 단에서 이미 정렬해 반환할 수 있음.
    func trending(limit: Int = 24) async throws -> [Filter] {
        let all = try await listFilters()
        return Array(
            all
                .filter { $0.status == .approved }
                .sorted { $0.useCount > $1.useCount }
                .prefix(limit)
        )
    }

    /// 최신 — `createdAt` 내림차순. 메타데이터가 없으면 원본 순서 유지.
    func newFilters(limit: Int = 24) async throws -> [Filter] {
        let all = try await listFilters()
        let approved = all.filter { $0.status == .approved }
        let hasDates = approved.contains { $0.createdAt != nil }
        if hasDates {
            return Array(
                approved
                    .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                    .prefix(limit)
            )
        }
        return Array(approved.prefix(limit))
    }

    /// 검색 — title/author 문자열 + 카테고리 필터. 단순 client-side 매칭.
    func search(query: String, category: FilterCategory? = nil, limit: Int = 50) async throws -> [Filter] {
        let all = try await listFilters()
        let q = query.lowercased()
        return Array(
            all
                .filter { f in
                    guard f.status == .approved else { return false }
                    if let category, f.category != category { return false }
                    if q.isEmpty { return true }
                    return f.title.lowercased().contains(q)
                        || f.author.displayName.lowercased().contains(q)
                }
                .prefix(limit)
        )
    }
}

public struct MockFilterRepository: FilterRepository {
    private let filters: [Filter]

    public init(filters: [Filter] = Filter.sampleCatalog) {
        self.filters = filters
    }

    public func listFilters() async throws -> [Filter] {
        filters
    }

    public func filter(id: Filter.ID) async throws -> Filter {
        guard let filter = filters.first(where: { $0.id == id }) else {
            throw MockFilterRepositoryError.notFound
        }
        return filter
    }
}

public enum MockFilterRepositoryError: Error, Sendable {
    case notFound
}

public extension Filter {
    static let preview = Filter(
        id: UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3F4A")!,
        title: "Sunset Vibes",
        version: "1.0.0",
        author: FilterAuthor(uid: "preview-maker", displayName: "Alex"),
        category: .cinematic,
        engine: FilterEngineDescriptor(
            type: .lutParams,
            minAppVersion: "1.0.0",
            minIOSVersion: "17.0",
            lutSize: 33,
            lutFile: "luts/lut.png"
        )
    )

    static let sampleCatalog: [Filter] = [
        .preview,
        Filter(
            id: UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3F4B")!,
            title: "Soft Portra",
            version: "1.0.0",
            author: FilterAuthor(uid: "maker-portra", displayName: "Mina"),
            category: .portrait,
            engine: FilterEngineDescriptor(
                type: .lutParams,
                minAppVersion: "1.0.0",
                minIOSVersion: "17.0",
                lutSize: 33,
                lutFile: "luts/soft-portra.png"
            ),
            useCount: 5_840,
            downloadCount: 5_840
        ),
        Filter(
            id: UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3F4C")!,
            title: "Seoul Night",
            version: "1.0.0",
            author: FilterAuthor(uid: "maker-night", displayName: "Joon"),
            category: .moody,
            engine: FilterEngineDescriptor(
                type: .lutParams,
                minAppVersion: "1.0.0",
                minIOSVersion: "17.0",
                lutSize: 33,
                lutFile: "luts/seoul-night.png"
            ),
            useCount: 3_980,
            downloadCount: 3_980
        ),
        Filter(
            id: UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3F4D")!,
            title: "Cafe Cream",
            version: "1.0.0",
            author: FilterAuthor(uid: "maker-cafe", displayName: "Nora"),
            category: .food,
            engine: FilterEngineDescriptor(
                type: .lutParams,
                minAppVersion: "1.0.0",
                minIOSVersion: "17.0",
                lutSize: 33,
                lutFile: "luts/cafe-cream.png"
            ),
            useCount: 4_320,
            downloadCount: 4_320
        ),
        Filter(
            id: UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3F4E")!,
            title: "Airy Trip",
            version: "1.0.0",
            author: FilterAuthor(uid: "maker-trip", displayName: "Leo"),
            category: .travel,
            engine: FilterEngineDescriptor(
                type: .lutParams,
                minAppVersion: "1.0.0",
                minIOSVersion: "17.0",
                lutSize: 33,
                lutFile: "luts/airy-trip.png"
            ),
            useCount: 6_510,
            downloadCount: 6_510
        ),
    ]
}
