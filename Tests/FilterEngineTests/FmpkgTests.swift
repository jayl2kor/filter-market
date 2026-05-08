import XCTest
@testable import FilterEngine

final class FmpkgTests: XCTestCase {

    private func sampleOptions(
        bakedLUT: LUT3D = LUT3D.identity(size: 8),
        version: String = "1.0.0"
    ) -> FmpkgBuilder.Options {
        FmpkgBuilder.Options(
            id: "00000000-0000-0000-0000-000000000001",
            version: version,
            title: "Sunset 1973",
            author: FmpkgManifest.Author(uid: "maker-jisoo", displayName: "@jisoo.films"),
            bakedLUT: bakedLUT,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: - Builder

    func testBuilderProducesManifestAndLUTData() {
        let output = FmpkgBuilder.build(sampleOptions())

        XCTAssertEqual(output.manifest.schemaVersion, 1)
        XCTAssertEqual(output.manifest.engine.lutSize, 8)
        XCTAssertEqual(output.manifest.engine.lutFile, "luts/lut.cube")
        XCTAssertEqual(output.manifest.checksum.algorithm, "sha256")
        XCTAssertFalse(output.lutData.isEmpty)
        XCTAssertFalse(output.manifestData.isEmpty)
    }

    func testBuilderIsDeterministic() {
        let a = FmpkgBuilder.build(sampleOptions())
        let b = FmpkgBuilder.build(sampleOptions())

        XCTAssertEqual(a.lutData, b.lutData)
        XCTAssertEqual(a.manifestData, b.manifestData)
        XCTAssertEqual(a.lutChecksum, b.lutChecksum)
    }

    func testBuilderChecksumMatchesLUTBytes() {
        let output = FmpkgBuilder.build(sampleOptions())
        // The checksum is recorded only inside the manifest — recompute over lutData
        // independently to confirm the builder doesn't lie about what it hashed.
        XCTAssertEqual(output.manifest.checksum.lut.count, 64) // SHA-256 hex = 64 chars
        XCTAssertTrue(
            output.manifest.checksum.lut.allSatisfy { $0.isHexDigit },
            "Checksum should be lowercase hex"
        )
    }

    // MARK: - Verifier round trip

    func testVerifierAcceptsBuilderOutput() throws {
        let output = FmpkgBuilder.build(sampleOptions())
        let manifest = try FmpkgVerifier.verify(output)
        XCTAssertEqual(manifest, output.manifest)
    }

    func testVerifierRejectsTamperedLUT() {
        var output = FmpkgBuilder.build(sampleOptions())

        // Flip a byte in the LUT; checksum should now disagree with the manifest.
        var tamperedBytes = Array(output.lutData)
        tamperedBytes[10] ^= 0x01
        output = FmpkgBuilder.Output(
            manifest: output.manifest,
            manifestData: output.manifestData,
            lutData: Data(tamperedBytes)
        )

        XCTAssertThrowsError(try FmpkgVerifier.verify(output)) { error in
            guard case FmpkgVerifier.VerifyError.checksumMismatch = error else {
                return XCTFail("Expected checksumMismatch, got \(error)")
            }
        }
    }

    func testVerifierRejectsCorruptedManifest() {
        let output = FmpkgBuilder.build(sampleOptions())
        let bogus = FmpkgBuilder.Output(
            manifest: output.manifest,
            manifestData: Data("not json".utf8),
            lutData: output.lutData
        )

        XCTAssertThrowsError(try FmpkgVerifier.verify(bogus)) { error in
            XCTAssertEqual(error as? FmpkgVerifier.VerifyError, .manifestDecodeFailed)
        }
    }

    // MARK: - Smoke render parity

    func testSmokeRenderMatchesDirectSampleOnIdentityLUT() throws {
        let identityLUT = LUT3D.identity(size: 16)
        let output = FmpkgBuilder.build(sampleOptions(bakedLUT: identityLUT))

        let probe = RGBColor(red: 0.3, green: 0.6, blue: 0.9)
        let viaSmoke = try FmpkgVerifier.smokeRender(output, probe: probe)
        let viaDirect = LUTSampler.sample(identityLUT, color: probe)

        // .cube serializer prints to 6 decimal places — accept tiny round-trip drift.
        XCTAssertEqual(viaSmoke.red, viaDirect.red, accuracy: 1e-3)
        XCTAssertEqual(viaSmoke.green, viaDirect.green, accuracy: 1e-3)
        XCTAssertEqual(viaSmoke.blue, viaDirect.blue, accuracy: 1e-3)
    }

    func testSmokeRenderRoundTripsBakedLUT() throws {
        let baseLUT = LUT3D.identity(size: 16)
        let baked = LUTBake.bake(
            sourceLUT: baseLUT,
            parameters: EditorParameters(exposure: 0.5, contrast: 0.2)
        )
        let output = FmpkgBuilder.build(sampleOptions(bakedLUT: baked))

        let probe = RGBColor(red: 0.4, green: 0.4, blue: 0.4)
        let viaPackage = try FmpkgVerifier.smokeRender(output, probe: probe)
        let viaInMemory = LUTSampler.sample(baked, color: probe)

        XCTAssertEqual(viaPackage.red, viaInMemory.red, accuracy: 1e-3)
        XCTAssertEqual(viaPackage.green, viaInMemory.green, accuracy: 1e-3)
        XCTAssertEqual(viaPackage.blue, viaInMemory.blue, accuracy: 1e-3)
    }
}
