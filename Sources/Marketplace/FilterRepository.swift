import Foundation
import Models

public protocol FilterRepository: Sendable {
    func listFilters() async throws -> [Filter]
    func filter(id: Filter.ID) async throws -> Filter
}

public struct MockFilterRepository: FilterRepository {
    private let filters: [Filter]

    public init(filters: [Filter] = [.preview]) {
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
}
