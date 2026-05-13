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

    // MARK: - Cache behavior

    func testBakeCachesIdenticalInputs() {
        LUTBake._resetCacheForTesting()
        let lut = LUT3D.identity(size: 17)
        let parameters = EditorParameters(exposure: 0.4, contrast: 0.2)

        _ = LUTBake.bake(sourceLUT: lut, parameters: parameters)
        let afterFirst = LUTBake._cacheStatsForTesting()
        XCTAssertEqual(afterFirst.hits, 0)
        XCTAssertEqual(afterFirst.misses, 1)
        XCTAssertEqual(afterFirst.entries, 1)

        _ = LUTBake.bake(sourceLUT: lut, parameters: parameters)
        let afterSecond = LUTBake._cacheStatsForTesting()
        XCTAssertEqual(afterSecond.hits, 1, "Second call with identical inputs should hit the cache")
        XCTAssertEqual(afterSecond.misses, 1, "Miss count should not grow on a cache hit")
        XCTAssertEqual(afterSecond.entries, 1)
    }

    func testBakeCacheDistinguishesQuantizedParameters() {
        LUTBake._resetCacheForTesting()
        let lut = LUT3D.identity(size: 17)

        // The cache key quantizes parameters to 3 decimal places (×1000). Values that round
        // to the same integer must hit the same cache entry; values that round differently
        // must not collide.
        _ = LUTBake.bake(sourceLUT: lut, parameters: EditorParameters(exposure: 0.2001))
        _ = LUTBake.bake(sourceLUT: lut, parameters: EditorParameters(exposure: 0.2003))
        _ = LUTBake.bake(sourceLUT: lut, parameters: EditorParameters(exposure: 0.2010))

        let stats = LUTBake._cacheStatsForTesting()
        // 0.2001 → quantized 200, 0.2003 → 200, 0.2010 → 201. Expect 2 entries, 1 hit.
        XCTAssertEqual(stats.misses, 2)
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.entries, 2)
    }

    func testBakeCacheHitIsMeasurablyFaster() {
        LUTBake._resetCacheForTesting()
        // A reasonably realistic size — production uses 33.
        let lut = LUT3D.identity(size: 33)
        let parameters = EditorParameters(exposure: 0.3, contrast: 0.15, saturation: -0.2)

        let coldStart = DispatchTime.now()
        _ = LUTBake.bake(sourceLUT: lut, parameters: parameters)
        let coldElapsed = DispatchTime.now().uptimeNanoseconds - coldStart.uptimeNanoseconds

        let hotStart = DispatchTime.now()
        _ = LUTBake.bake(sourceLUT: lut, parameters: parameters)
        let hotElapsed = DispatchTime.now().uptimeNanoseconds - hotStart.uptimeNanoseconds

        // Cache hit should be at least 10× faster than a cold bake. Real ratio is much higher
        // (microseconds vs milliseconds), the 10× threshold absorbs CI/host variance.
        XCTAssertLessThan(hotElapsed * 10, coldElapsed,
                          "Expected cache hit (\(hotElapsed)ns) to be >10× faster than cold bake (\(coldElapsed)ns)")
    }

    func testLUT3DFingerprintIsStableAndDistinct() {
        let a = LUT3D.identity(size: 9)
        let b = LUT3D.identity(size: 9)
        XCTAssertEqual(a.fingerprint, b.fingerprint,
                       "Two identity LUTs of the same size must fingerprint identically")

        let c = LUT3D.identity(size: 17)
        XCTAssertNotEqual(a.fingerprint, c.fingerprint,
                          "Different-size identity LUTs must fingerprint differently")
    }
}
