import XCTest
@testable import FilterEngine

final class LUTResourceResolverTests: XCTestCase {
    func testResolveNestedResourcePath() throws {
        let directory = try makeTemporaryDirectory()
        let nestedDirectory = directory
            .appendingPathComponent("SeedFilters")
            .appendingPathComponent("luts")
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        let expectedURL = nestedDirectory.appendingPathComponent("nested.png")
        try Data([1]).write(to: expectedURL)

        let url = try LUTResourceResolver.url(
            resourcePath: "SeedFilters/luts/nested.png",
            resourceURL: directory
        )

        XCTAssertEqual(url, expectedURL)
    }

    func testResolveFlattenedResourcePath() throws {
        let directory = try makeTemporaryDirectory()
        let expectedURL = directory.appendingPathComponent("flattened.png")
        try Data([1]).write(to: expectedURL)

        let url = try LUTResourceResolver.url(
            resourcePath: "SeedFilters/luts/flattened.png",
            resourceURL: directory
        )

        XCTAssertEqual(url, expectedURL)
    }

    func testMissingResourceThrows() throws {
        let directory = try makeTemporaryDirectory()

        XCTAssertThrowsError(
            try LUTResourceResolver.url(
                resourcePath: "SeedFilters/luts/missing.png",
                resourceURL: directory
            )
        ) { error in
            XCTAssertEqual(error as? LUTImageLoaderError, .missingResource("SeedFilters/luts/missing.png"))
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("moodit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
