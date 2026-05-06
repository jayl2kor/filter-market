import XCTest
import Models
@testable import FilterEngine

final class LUTPresetTests: XCTestCase {
    func testIdentityPresetReturnsInputColor() {
        let input = RGBColor(red: 0.25, green: 0.5, blue: 0.75)

        let output = LUTPreset.identity.transform(red: input.red, green: input.green, blue: input.blue)

        XCTAssertEqual(output, input)
    }

    func testPresetsProduceDistinctLooks() {
        let input = RGBColor(red: 0.42, green: 0.38, blue: 0.64)

        let warm = LUTPreset.warm.transform(red: input.red, green: input.green, blue: input.blue)
        let cool = LUTPreset.cool.transform(red: input.red, green: input.green, blue: input.blue)
        let mono = LUTPreset.mono.transform(red: input.red, green: input.green, blue: input.blue)
        let vivid = LUTPreset.vivid.transform(red: input.red, green: input.green, blue: input.blue)

        XCTAssertNotEqual(warm, cool)
        XCTAssertNotEqual(warm, mono)
        XCTAssertNotEqual(cool, vivid)
    }

    func testCategoryMappingUsesMultiplePresets() {
        let mappedPresets = Set(FilterCategory.allCases.map(LUTPreset.preset(for:)))

        XCTAssertTrue(mappedPresets.contains(.warm))
        XCTAssertTrue(mappedPresets.contains(.cool))
        XCTAssertTrue(mappedPresets.contains(.soft))
        XCTAssertTrue(mappedPresets.contains(.vivid))
        XCTAssertTrue(mappedPresets.contains(.mono))
    }
}
