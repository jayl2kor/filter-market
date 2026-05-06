import XCTest
@testable import FilterEngine

final class LUTSamplerTests: XCTestCase {
    func testIdentityLUTReturnsInputColor() {
        let lut = LUT3D.identity(size: 3)
        let input = RGBColor(red: 0.25, green: 0.5, blue: 0.75)

        let output = LUTSampler.sample(lut, color: input)

        XCTAssertEqual(output.red, input.red, accuracy: 0.0001)
        XCTAssertEqual(output.green, input.green, accuracy: 0.0001)
        XCTAssertEqual(output.blue, input.blue, accuracy: 0.0001)
    }

    func testIntensityZeroReturnsOriginalColor() {
        let lut = LUT3D(
            size: 2,
            values: Array(
                repeating: RGBColor(red: 1, green: 0, blue: 0),
                count: 8
            )
        )
        let input = RGBColor(red: 0.2, green: 0.3, blue: 0.4)

        let output = LUTSampler.sample(lut, color: input, intensity: .zero)

        XCTAssertEqual(output, input)
    }

    func testIntensityFullReturnsSampledColor() {
        let lut = LUT3D(
            size: 2,
            values: Array(
                repeating: RGBColor(red: 1, green: 0, blue: 0),
                count: 8
            )
        )

        let output = LUTSampler.sample(lut, color: RGBColor(red: 0.2, green: 0.3, blue: 0.4), intensity: .full)

        XCTAssertEqual(output, RGBColor(red: 1, green: 0, blue: 0))
    }
}
