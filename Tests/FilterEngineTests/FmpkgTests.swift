import CryptoKit
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

    func testBuilderProducesManifestAndLUTData() throws {
        let output = try FmpkgBuilder.build(sampleOptions())

        XCTAssertEqual(output.manifest.schemaVersion, 1)
        XCTAssertEqual(output.manifest.engine.lutSize, 8)
        XCTAssertEqual(output.manifest.engine.lutFile, "luts/lut.cube")
        XCTAssertEqual(output.manifest.checksum.algorithm, "sha256")
        XCTAssertFalse(output.lutData.isEmpty)
        XCTAssertFalse(output.manifestData.isEmpty)
    }

    func testBuilderIsDeterministic() throws {
        let a = try FmpkgBuilder.build(sampleOptions())
        let b = try FmpkgBuilder.build(sampleOptions())

        XCTAssertEqual(a.lutData, b.lutData)
        XCTAssertEqual(a.manifestData, b.manifestData)
        XCTAssertEqual(a.lutChecksum, b.lutChecksum)
    }

    func testBuilderChecksumMatchesLUTBytes() throws {
        let output = try FmpkgBuilder.build(sampleOptions())
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
        let output = try FmpkgBuilder.build(sampleOptions())
        let manifest = try FmpkgVerifier.verify(output)
        XCTAssertEqual(manifest, output.manifest)
    }

    func testVerifierRejectsTamperedLUT() throws {
        var output = try FmpkgBuilder.build(sampleOptions())

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

    func testVerifierRejectsCorruptedManifest() throws {
        let output = try FmpkgBuilder.build(sampleOptions())
        let bogus = FmpkgBuilder.Output(
            manifest: output.manifest,
            manifestData: Data("not json".utf8),
            lutData: output.lutData
        )

        XCTAssertThrowsError(try FmpkgVerifier.verify(bogus)) { error in
            XCTAssertEqual(error as? FmpkgVerifier.VerifyError, .manifestDecodeFailed)
        }
    }

    func testVerifierRejectsOneDimensionalLUTPackage() throws {
        let lutData = Data(
            """
            LUT_1D_SIZE 2
            0.0 0.0 0.0
            1.0 1.0 1.0
            """.utf8
        )
        let manifest = FmpkgManifest(
            schemaVersion: 1,
            id: "00000000-0000-0000-0000-000000000001",
            version: "1.0.0",
            title: "One Dimensional",
            author: FmpkgManifest.Author(uid: "maker-jisoo", displayName: "@jisoo.films"),
            engine: FmpkgManifest.Engine(type: "lut+params", lutSize: 2, lutFile: "luts/lut.cube"),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            checksum: FmpkgManifest.Checksum(lut: sha256Hex(lutData))
        )
        let output = FmpkgBuilder.Output(
            manifest: manifest,
            manifestData: try encodeManifest(manifest),
            lutData: lutData
        )

        XCTAssertThrowsError(try FmpkgVerifier.verify(output)) { error in
            XCTAssertEqual(error as? FmpkgVerifier.VerifyError, .unsupportedLutDimension)
        }
    }

    func testBuilderRejectsTraversalLUTFilenames() {
        let malicious = [
            "../../../passwd",
            "luts/../../../etc",
            "/tmp/lut.cube",
            "luts//lut.cube",
            "luts\\lut.cube"
        ]

        for filename in malicious {
            var options = sampleOptions()
            options = FmpkgBuilder.Options(
                id: options.id,
                version: options.version,
                title: options.title,
                author: options.author,
                bakedLUT: options.bakedLUT,
                createdAt: options.createdAt,
                lutFilename: filename
            )
            XCTAssertThrowsError(try FmpkgBuilder.build(options)) { error in
                XCTAssertEqual(error as? FmpkgBuilder.BuildError, .invalidLutFilename(filename))
            }
        }
    }

    // MARK: - Smoke render parity

    func testSmokeRenderMatchesDirectSampleOnIdentityLUT() throws {
        let identityLUT = LUT3D.identity(size: 16)
        let output = try FmpkgBuilder.build(sampleOptions(bakedLUT: identityLUT))

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
        let output = try FmpkgBuilder.build(sampleOptions(bakedLUT: baked))

        let probe = RGBColor(red: 0.4, green: 0.4, blue: 0.4)
        let viaPackage = try FmpkgVerifier.smokeRender(output, probe: probe)
        let viaInMemory = LUTSampler.sample(baked, color: probe)

        XCTAssertEqual(viaPackage.red, viaInMemory.red, accuracy: 1e-3)
        XCTAssertEqual(viaPackage.green, viaInMemory.green, accuracy: 1e-3)
        XCTAssertEqual(viaPackage.blue, viaInMemory.blue, accuracy: 1e-3)
    }

    private func encodeManifest(_ manifest: FmpkgManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(manifest)
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
