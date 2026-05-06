import XCTest
import Models
@testable import Marketplace

final class BundleSeedFilterRepositoryTests: XCTestCase {
    func testLoadSeedFiltersFromBundle() async throws {
        let repository = BundleSeedFilterRepository()

        let filters = try await repository.listFilters()

        XCTAssertGreaterThanOrEqual(filters.count, 5)
        XCTAssertEqual(filters.first?.title, "Sunset Vibes")
        XCTAssertTrue(filters.allSatisfy { $0.engine.type == .lutParams })
        XCTAssertTrue(filters.allSatisfy { $0.engine.lutSize == 33 })
        XCTAssertTrue(filters.allSatisfy { ($0.engine.lutFile ?? "").hasPrefix("SeedFilters/luts/") })
    }

    func testSeedFilterLUTAssetsExistInBundle() async throws {
        let repository = BundleSeedFilterRepository()

        let filters = try await repository.listFilters()

        for filter in filters {
            let lutFile = try XCTUnwrap(filter.engine.lutFile)
            XCTAssertNotNil(resourceURL(for: lutFile), "Missing LUT asset for \(filter.title): \(lutFile)")
        }
    }

    func testLoadSeedFilterByID() async throws {
        let repository = BundleSeedFilterRepository()
        let expectedID = UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3F4E")!

        let filter = try await repository.filter(id: expectedID)

        XCTAssertEqual(filter.title, "Airy Trip")
        XCTAssertEqual(filter.category, .travel)
    }

    func testMissingSeedFilterThrowsNotFound() async throws {
        let repository = BundleSeedFilterRepository()
        let missingID = UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3FFF")!

        do {
            _ = try await repository.filter(id: missingID)
            XCTFail("Expected notFound error")
        } catch BundleSeedFilterRepositoryError.notFound(let id) {
            XCTAssertEqual(id, missingID)
        }
    }

    private func resourceURL(for resourcePath: String) -> URL? {
        let path = resourcePath as NSString
        let subdirectory = path.deletingLastPathComponent
        let fileName = path.deletingPathExtension
        let fileExtension = path.pathExtension

        let bundledURL = MarketplaceResources.bundle.url(
            forResource: fileName,
            withExtension: fileExtension.isEmpty ? nil : fileExtension,
            subdirectory: subdirectory.isEmpty ? nil : subdirectory
        )
        let flattenedURL = MarketplaceResources.bundle.url(
            forResource: fileName,
            withExtension: fileExtension.isEmpty ? nil : fileExtension
        )
        let resourceURL = MarketplaceResources.bundle.resourceURL?.appendingPathComponent(resourcePath)
        let flattenedResourceURL = MarketplaceResources.bundle.resourceURL?.appendingPathComponent(path.lastPathComponent)
        return [bundledURL, resourceURL, flattenedURL, flattenedResourceURL]
            .compactMap { $0 }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
