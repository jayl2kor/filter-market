import Metal
import XCTest
@testable import FilterEngine

final class RenderFilterTests: XCTestCase {
    func testRenderFilterClampsMinimumLUTSize() {
        let filter = RenderFilter(
            id: UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3F4A")!,
            title: "Tiny",
            lutFile: "SeedFilters/luts/tiny.png",
            lutSize: 1,
            fallbackPreset: .warm
        )

        XCTAssertEqual(filter.lutSize, 2)
    }

    func testConfigurationClampsIntensity() {
        let filter = RenderFilter(
            id: UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3F4A")!,
            title: "Sunset Vibes",
            lutFile: "SeedFilters/luts/sunset-vibes.png",
            fallbackPreset: .warm
        )

        let low = FilterRenderConfiguration(filter: filter, intensityValue: -1)
        let high = FilterRenderConfiguration(filter: filter, intensityValue: 2)

        XCTAssertEqual(low.intensity.value, 0)
        XCTAssertEqual(high.intensity.value, 1)
    }

    func testPreviewFilterBridgesToRenderFilter() {
        let previewFilter = PreviewFilter(
            id: UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3F4A")!,
            title: "Sunset Vibes",
            category: .cinematic,
            preset: .warm,
            lutFile: "SeedFilters/luts/sunset-vibes.png",
            lutSize: 33
        )

        XCTAssertEqual(
            previewFilter.renderFilter,
            RenderFilter(
                id: previewFilter.id,
                title: "Sunset Vibes",
                lutFile: "SeedFilters/luts/sunset-vibes.png",
                lutSize: 33,
                fallbackPreset: .warm
            )
        )
    }

    func testLUTTextureFactoryRejectsInvalidSize() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable")
        }

        XCTAssertNil(LUTTextureFactory.makeIdentityLUT(device: device, size: 1))
    }
}
