import CryptoKit
import Foundation

/// `.fmpkg` filter package — minimum-viable builder/verifier.
///
/// Conforms to `docs/FMPKG_SCHEMA.md` §3 for the fields produced (schemaVersion, id,
/// version, title, author, engine, createdAt, checksum). The full ZIP container,
/// preview/JPEGs, and Ed25519 signing block are explicitly **out of scope** for this
/// iteration — they are tracked in TODO.md §6 and deferred until the upload API lands.
///
/// What this module *does* deliver:
/// - Canonical JSON manifest (UTF-8, sorted keys for hash stability).
/// - `.cube` text serialization of a baked LUT.
/// - SHA-256 integrity hash over the LUT bytes recorded in the manifest.
/// - A round-trippable `Output` value that the verifier can validate without I/O.
public struct FmpkgManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let version: String
    public let title: String
    public let author: Author
    public let engine: Engine
    public let createdAt: Date
    public let checksum: Checksum

    public struct Author: Codable, Equatable, Sendable {
        public let uid: String
        public let displayName: String
    }

    public struct Engine: Codable, Equatable, Sendable {
        public let type: String
        public let lutSize: Int
        public let lutFile: String

        public init(type: String, lutSize: Int, lutFile: String) {
            self.type = type
            self.lutSize = lutSize
            self.lutFile = lutFile
        }
    }

    public struct Checksum: Codable, Equatable, Sendable {
        public let algorithm: String
        public let lut: String

        public init(algorithm: String = "sha256", lut: String) {
            self.algorithm = algorithm
            self.lut = lut
        }
    }
}

public enum FmpkgBuilder {
    public enum BuildError: Error, Equatable, Sendable {
        case invalidLutFilename(String)
        case manifestEncodeFailed
    }

    public struct Options: Sendable {
        public let id: String
        public let version: String
        public let title: String
        public let author: FmpkgManifest.Author
        public let bakedLUT: LUT3D
        public let createdAt: Date
        public let lutFilename: String
        public let engineType: String

        public init(
            id: String,
            version: String,
            title: String,
            author: FmpkgManifest.Author,
            bakedLUT: LUT3D,
            createdAt: Date,
            lutFilename: String = "luts/lut.cube",
            engineType: String = "lut+params"
        ) {
            self.id = id
            self.version = version
            self.title = title
            self.author = author
            self.bakedLUT = bakedLUT
            self.createdAt = createdAt
            self.lutFilename = lutFilename
            self.engineType = engineType
        }
    }

    public struct Output: Sendable, Equatable {
        public let manifest: FmpkgManifest
        public let manifestData: Data
        public let lutData: Data

        public var lutChecksum: String { manifest.checksum.lut }
    }

    public static func build(_ options: Options) throws -> Output {
        try validateLutFilename(options.lutFilename)
        let lutText = CubeLUTWriter.text(for: options.bakedLUT, title: options.title)
        let lutData = Data(lutText.utf8)
        let lutHash = sha256Hex(lutData)

        let manifest = FmpkgManifest(
            schemaVersion: 1,
            id: options.id,
            version: options.version,
            title: options.title,
            author: options.author,
            engine: FmpkgManifest.Engine(
                type: options.engineType,
                lutSize: options.bakedLUT.size,
                lutFile: options.lutFilename
            ),
            createdAt: options.createdAt,
            checksum: FmpkgManifest.Checksum(lut: lutHash)
        )

        let manifestData = try encode(manifest)
        return Output(manifest: manifest, manifestData: manifestData, lutData: lutData)
    }

    private static func validateLutFilename(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !trimmed.contains("\\") else {
            throw BuildError.invalidLutFilename(value)
        }
        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ component in
            !component.isEmpty && component != "." && component != ".." && !component.contains("..")
        }) else {
            throw BuildError.invalidLutFilename(value)
        }
    }
}

public enum FmpkgVerifier {
    public enum VerifyError: Error, Equatable, Sendable {
        case manifestDecodeFailed
        case unsupportedSchemaVersion(Int)
        case checksumMismatch(expected: String, actual: String)
        case lutSizeMismatch(declared: Int, parsed: Int)
        case lutParseFailed
    }

    /// Verify a built package by recomputing the LUT checksum and ensuring the LUT
    /// re-parses to the declared size. Returns the manifest on success.
    public static func verify(_ output: FmpkgBuilder.Output) throws -> FmpkgManifest {
        let decoded = try decode(output.manifestData)
        guard decoded.schemaVersion == 1 else {
            throw VerifyError.unsupportedSchemaVersion(decoded.schemaVersion)
        }

        let recomputed = sha256Hex(output.lutData)
        guard recomputed == decoded.checksum.lut else {
            throw VerifyError.checksumMismatch(expected: decoded.checksum.lut, actual: recomputed)
        }

        guard let parsed = try? CubeLUTParser.parse(String(decoding: output.lutData, as: UTF8.self)) else {
            throw VerifyError.lutParseFailed
        }

        switch parsed {
        case .threeDimensional(let lut):
            guard lut.size == decoded.engine.lutSize else {
                throw VerifyError.lutSizeMismatch(declared: decoded.engine.lutSize, parsed: lut.size)
            }
        case .oneDimensional(let samples):
            guard samples.count == decoded.engine.lutSize else {
                throw VerifyError.lutSizeMismatch(declared: decoded.engine.lutSize, parsed: samples.count)
            }
        }

        return decoded
    }

    /// Smoke render: parse the LUT from the package and sample it at a probe color,
    /// returning the result. Caller compares against `LUTSampler.sample(originalLUT, …)`
    /// to assert builder→verifier round-trip preserves rendering output.
    public static func smokeRender(
        _ output: FmpkgBuilder.Output,
        probe: RGBColor
    ) throws -> RGBColor {
        let parsed = try CubeLUTParser.parse(String(decoding: output.lutData, as: UTF8.self))
        guard case .threeDimensional(let lut) = parsed else {
            throw VerifyError.lutParseFailed
        }
        return LUTSampler.sample(lut, color: probe)
    }
}

// MARK: - Internals

private func encode(_ manifest: FmpkgManifest) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    do {
        return try encoder.encode(manifest)
    } catch {
        throw FmpkgBuilder.BuildError.manifestEncodeFailed
    }
}

private func decode(_ data: Data) throws -> FmpkgManifest {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
        return try decoder.decode(FmpkgManifest.self, from: data)
    } catch {
        throw FmpkgVerifier.VerifyError.manifestDecodeFailed
    }
}

private func sha256Hex(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}
