import Foundation
import Models

public struct BundleSeedFilterRepository: FilterRepository {
    private let bundle: Bundle
    private let decoder: JSONDecoder

    public init(
        bundle: Bundle? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.bundle = bundle ?? MarketplaceResources.bundle
        self.decoder = decoder
    }

    public func listFilters() async throws -> [Filter] {
        let data = try Data(contentsOf: manifestURL())
        return try decoder.decode([Filter].self, from: data)
    }

    public func filter(id: Filter.ID) async throws -> Filter {
        let filters = try await listFilters()
        guard let filter = filters.first(where: { $0.id == id }) else {
            throw BundleSeedFilterRepositoryError.notFound(id)
        }
        return filter
    }

    private func manifestURL() throws -> URL {
        let candidateURLs = [
            bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "SeedFilters"),
            bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "Resources/SeedFilters"),
            bundle.url(forResource: "manifest", withExtension: "json"),
        ]

        guard let url = candidateURLs.compactMap({ $0 }).first else {
            throw BundleSeedFilterRepositoryError.missingManifest
        }
        return url
    }
}

public enum BundleSeedFilterRepositoryError: Error, Equatable, Sendable {
    case missingManifest
    case notFound(Filter.ID)
}

public enum MarketplaceResources {
    public static var bundle: Bundle {
        Bundle(for: BundleSeedFilterRepositoryBundleToken.self)
    }
}

private final class BundleSeedFilterRepositoryBundleToken {}
