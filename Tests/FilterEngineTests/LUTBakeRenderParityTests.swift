import XCTest
@testable import FilterEngine

/// Editor preview ↔ apply-path parity (US-009).
///
/// Both code paths flow through the same `LUTSampler` against a baked LUT, so a baked
/// LUT must produce byte-identical sampled output across two evaluations and the bake
/// transform must agree with hand-calculated reference values within a small tolerance.
final class LUTBakeRenderParityTests: XCTestCase {

    /// Same input through bake → sample twice produces byte-equal output.
    /// This is the core parity guarantee: editor preview render and apply-path render
    /// share the same kernel and must never diverge for identical inputs.
    func testBakedSampleIsDeterministicAcrossRuns() {
        let baseLUT = LUT3D.identity(size: 16)
        let parameters = EditorParameters(exposure: 0.7, contrast: 0.3, saturation: 0.2, tint: 0.05)
        let baked = LUTBake.bake(sourceLUT: baseLUT, parameters: parameters)

        let probe = RGBColor(red: 0.42, green: 0.21, blue: 0.84)
        let first = LUTSampler.sample(baked, color: probe)
        let second = LUTSampler.sample(baked, color: probe)

        XCTAssertEqual(first.red.bitPattern, second.red.bitPattern)
        XCTAssertEqual(first.green.bitPattern, second.green.bitPattern)
        XCTAssertEqual(first.blue.bitPattern, second.blue.bitPattern)
    }

    /// Neutral parameters: bake then sample equals direct identity sample.
    func testNeutralParametersPreserveSourceLUT() {
        let baseLUT = LUT3D.identity(size: 8)
        let baked = LUTBake.bake(sourceLUT: baseLUT, parameters: .neutral)

        let probe = RGBColor(red: 0.3, green: 0.6, blue: 0.9)
        let direct = LUTSampler.sample(baseLUT, color: probe)
        let viaBake = LUTSampler.sample(baked, color: probe)

        XCTAssertEqual(direct.red, viaBake.red, accuracy: 1e-3)
        XCTAssertEqual(direct.green, viaBake.green, accuracy: 1e-3)
        XCTAssertEqual(direct.blue, viaBake.blue, accuracy: 1e-3)
    }

    /// Exposure +1 stop on identity LUT: input × 2, then clamped at 1.0.
    /// Sampling at mid-grey should yield a near-doubled output.
    func testExposureBakeMatchesExpectedOutputAtMidGrey() {
        let baseLUT = LUT3D.identity(size: 16)
        let baked = LUTBake.bake(
            sourceLUT: baseLUT,
            parameters: EditorParameters(exposure: 1.0)
        )

        let mid = RGBColor(red: 0.4, green: 0.4, blue: 0.4)
        let sampled = LUTSampler.sample(baked, color: mid)

        // Expected: 0.4 * 2 = 0.8 for each channel.
        XCTAssertEqual(sampled.red, 0.8, accuracy: 0.05)
        XCTAssertEqual(sampled.green, 0.8, accuracy: 0.05)
        XCTAssertEqual(sampled.blue, 0.8, accuracy: 0.05)
    }

    /// Each non-neutral parameter must shift sampled output for at least one carefully
    /// chosen probe — guards against a parameter being silently dropped from the bake.
    /// Note: contrast pivots around 0.5 and saturation has no effect on grey, so
    /// each parameter is probed at a value where its effect is visible.
    func testEachParameterAffectsSampledOutput() {
        let lut = LUT3D.identity(size: 16)

        struct Case {
            let label: String
            let probe: RGBColor
            let parameters: EditorParameters
            let assertChannel: KeyPath<RGBColor, Float>
        }

        let cases: [Case] = [
            // Mid-grey shifts upward under +exposure.
            Case(
                label: "exposure",
                probe: RGBColor(red: 0.5, green: 0.5, blue: 0.5),
                parameters: EditorParameters(exposure: 0.5),
                assertChannel: \.red
            ),
            // Contrast pivots around 0.5 — pick a probe off the pivot.
            Case(
                label: "contrast",
                probe: RGBColor(red: 0.2, green: 0.2, blue: 0.2),
                parameters: EditorParameters(contrast: 0.5),
                assertChannel: \.red
            ),
            // Saturation only affects non-grey colors — pick saturated red.
            Case(
                label: "saturation",
                probe: RGBColor(red: 0.8, green: 0.2, blue: 0.2),
                parameters: EditorParameters(saturation: -0.5),
                assertChannel: \.red
            ),
            // Tint shifts red even on grey.
            Case(
                label: "tint",
                probe: RGBColor(red: 0.5, green: 0.5, blue: 0.5),
                parameters: EditorParameters(tint: 0.5),
                assertChannel: \.red
            )
        ]

        for c in cases {
            let neutralSampled = LUTSampler.sample(
                LUTBake.bake(sourceLUT: lut, parameters: .neutral),
                color: c.probe
            )
            let nonNeutralSampled = LUTSampler.sample(
                LUTBake.bake(sourceLUT: lut, parameters: c.parameters),
                color: c.probe
            )
            XCTAssertNotEqual(
                neutralSampled[keyPath: c.assertChannel],
                nonNeutralSampled[keyPath: c.assertChannel],
                "\(c.label) must change output"
            )
        }
    }
}
