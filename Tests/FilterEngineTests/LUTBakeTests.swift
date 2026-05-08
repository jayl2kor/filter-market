import XCTest
@testable import FilterEngine

final class LUTBakeTests: XCTestCase {

    // MARK: - Determinism

    func testBakeIsDeterministic() {
        let lut = LUT3D.identity(size: 8)
        let parameters = EditorParameters(
            exposure: 0.5,
            contrast: 0.2,
            saturation: -0.3,
            tint: 0.1
        )

        let first = LUTBake.bake(sourceLUT: lut, parameters: parameters)
        let second = LUTBake.bake(sourceLUT: lut, parameters: parameters)

        XCTAssertEqual(first.size, second.size)
        for b in 0 ..< first.size {
            for g in 0 ..< first.size {
                for r in 0 ..< first.size {
                    let a = first.colorAt(red: r, green: g, blue: b)
                    let z = second.colorAt(red: r, green: g, blue: b)
                    XCTAssertEqual(a.red.bitPattern, z.red.bitPattern, "r=\(r),g=\(g),b=\(b)")
                    XCTAssertEqual(a.green.bitPattern, z.green.bitPattern)
                    XCTAssertEqual(a.blue.bitPattern, z.blue.bitPattern)
                }
            }
        }
    }

    // MARK: - Neutral identity

    func testNeutralParametersProduceUnchangedLUT() {
        let lut = LUT3D.identity(size: 5)
        let baked = LUTBake.bake(sourceLUT: lut, parameters: .neutral)

        for b in 0 ..< lut.size {
            for g in 0 ..< lut.size {
                for r in 0 ..< lut.size {
                    let original = lut.colorAt(red: r, green: g, blue: b)
                    let result = baked.colorAt(red: r, green: g, blue: b)
                    XCTAssertEqual(result.red, original.red, accuracy: 1e-6)
                    XCTAssertEqual(result.green, original.green, accuracy: 1e-6)
                    XCTAssertEqual(result.blue, original.blue, accuracy: 1e-6)
                }
            }
        }
    }

    // MARK: - Cache key behavior

    func testCacheKeyEqualForSameInput() {
        let lut = LUT3D.identity(size: 4)
        let p = EditorParameters(exposure: 1.0, contrast: 0.4, saturation: 0.0, tint: 0.0)

        let a = LUTBake.cacheKey(sourceLUT: lut, parameters: p)
        let b = LUTBake.cacheKey(sourceLUT: lut, parameters: p)

        XCTAssertEqual(a, b)
    }

    func testCacheKeyDiffersOnParameterChange() {
        let lut = LUT3D.identity(size: 4)
        let baseline = LUTBake.cacheKey(sourceLUT: lut, parameters: .neutral)

        XCTAssertNotEqual(
            baseline,
            LUTBake.cacheKey(sourceLUT: lut, parameters: EditorParameters(exposure: 0.1))
        )
        XCTAssertNotEqual(
            baseline,
            LUTBake.cacheKey(sourceLUT: lut, parameters: EditorParameters(contrast: 0.1))
        )
        XCTAssertNotEqual(
            baseline,
            LUTBake.cacheKey(sourceLUT: lut, parameters: EditorParameters(saturation: 0.1))
        )
        XCTAssertNotEqual(
            baseline,
            LUTBake.cacheKey(sourceLUT: lut, parameters: EditorParameters(tint: 0.1))
        )
    }

    func testCacheKeyDiffersOnSourceLUTChange() {
        let identity = LUT3D.identity(size: 4)
        let allRed = LUT3D(
            size: 2,
            values: Array(repeating: RGBColor(red: 1, green: 0, blue: 0), count: 8)
        )

        let identityKey = LUTBake.cacheKey(sourceLUT: identity, parameters: .neutral)
        let redKey = LUTBake.cacheKey(sourceLUT: allRed, parameters: .neutral)

        XCTAssertNotEqual(identityKey, redKey)
    }

    func testCacheKeyQuantizesNearbyParameterFloats() {
        // Float jitter within the quantization bucket (0.001) should hit the same key.
        let lut = LUT3D.identity(size: 3)
        let a = LUTBake.cacheKey(sourceLUT: lut, parameters: EditorParameters(exposure: 0.1234))
        let b = LUTBake.cacheKey(sourceLUT: lut, parameters: EditorParameters(exposure: 0.1234001))

        XCTAssertEqual(a, b)
    }

    // MARK: - Effect smoke checks

    func testExposureBrightensImage() {
        let lut = LUT3D.identity(size: 5)
        let baked = LUTBake.bake(
            sourceLUT: lut,
            parameters: EditorParameters(exposure: 1.0)
        )

        // Mid-grey at +1 stop should land at ~1.0 (clamped).
        let mid = baked.colorAt(red: 2, green: 2, blue: 2)
        XCTAssertGreaterThan(mid.red, 0.9)
    }

    func testSaturationMinusOneProducesGray() {
        let lut = LUT3D.identity(size: 5)
        let baked = LUTBake.bake(
            sourceLUT: lut,
            parameters: EditorParameters(saturation: -1)
        )

        // After full desaturation, R, G, B should be approximately equal.
        let sample = baked.colorAt(red: 4, green: 0, blue: 0)
        XCTAssertEqual(sample.red, sample.green, accuracy: 0.01)
        XCTAssertEqual(sample.green, sample.blue, accuracy: 0.01)
    }
}
