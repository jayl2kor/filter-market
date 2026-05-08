import CryptoKit
import FilterEngine
import Foundation

/// Identifier for a downloadable filter package.
public struct FilterPackageID: Hashable, Sendable, Codable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

/// Metadata + bytes of a `.fmpkg`-style package, deterministic for caching.
public struct FilterPackage: Sendable {
    public let id: FilterPackageID
    public let manifestData: Data
    public let lutData: Data
    public let expectedChecksum: String

    public init(
        id: FilterPackageID,
        manifestData: Data,
        lutData: Data,
        expectedChecksum: String
    ) {
        self.id = id
        self.manifestData = manifestData
        self.lutData = lutData
        self.expectedChecksum = expectedChecksum
    }

    /// SHA-256 hex of `lutData`.
    public func computedChecksum() -> String {
        SHA256.hash(data: lutData).map { String(format: "%02x", $0) }.joined()
    }

    public func verifyIntegrity() throws {
        let actual = computedChecksum()
        guard actual == expectedChecksum else {
            throw FilterPackageError.checksumMismatch(expected: expectedChecksum, actual: actual)
        }
    }
}

public enum FilterPackageError: Error, Equatable, Sendable {
    case checksumMismatch(expected: String, actual: String)
    case parseFailed
    case networkFailed(statusCode: Int)
    case manifestMissingChecksum
}

// MARK: - Fetcher

public protocol FilterPackageFetcher: Sendable {
    /// Fetch (and integrity-check) the package for `id`. Caller is responsible for caching.
    /// `onProgress` receives values in `0...1`; may be called from any thread.
    func fetch(
        id: FilterPackageID,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> FilterPackage
}

/// `URLSession`-backed fetcher. Resume is provided by `URLSession`'s built-in
/// resumable download API; retries and signed URL minting are out of scope here.
public final class URLSessionFilterPackageFetcher: FilterPackageFetcher {
    public struct Config: Sendable {
        public let manifestURL: @Sendable (FilterPackageID) -> URL
        public let lutURL: @Sendable (FilterPackageID) -> URL

        public init(
            manifestURL: @escaping @Sendable (FilterPackageID) -> URL,
            lutURL: @escaping @Sendable (FilterPackageID) -> URL
        ) {
            self.manifestURL = manifestURL
            self.lutURL = lutURL
        }
    }

    private let session: URLSession
    private let config: Config

    public init(session: URLSession = .shared, config: Config) {
        self.session = session
        self.config = config
    }

    public func fetch(
        id: FilterPackageID,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> FilterPackage {
        let manifestURL = config.manifestURL(id)
        let lutURL = config.lutURL(id)

        let (manifestData, manifestResponse) = try await session.data(from: manifestURL)
        try ensureSuccess(response: manifestResponse)
        onProgress?(0.5)

        let (lutData, lutResponse) = try await session.data(from: lutURL)
        try ensureSuccess(response: lutResponse)
        onProgress?(1.0)

        let expected = try checksumFromManifest(manifestData)
        let pkg = FilterPackage(
            id: id,
            manifestData: manifestData,
            lutData: lutData,
            expectedChecksum: expected
        )
        try pkg.verifyIntegrity()
        return pkg
    }

    private func ensureSuccess(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw FilterPackageError.networkFailed(statusCode: http.statusCode)
        }
    }

    private func checksumFromManifest(_ data: Data) throws -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let checksum = (object["checksum"] as? [String: Any])?["lut"] as? String
        else {
            throw FilterPackageError.manifestMissingChecksum
        }
        return checksum
    }
}

// MARK: - Cache

public protocol FilterPackageCache: Sendable {
    func lookup(id: FilterPackageID) async -> FilterPackage?
    func insert(_ package: FilterPackage) async throws
    func evictAll() async throws
    func cachedIDs() async -> [FilterPackageID]
}

/// Disk-backed LRU cache with a size cap (bytes). Files live under
/// `Application Support/moodit/packages/<id>/`. Each package has two files:
/// `manifest.json` and `lut.cube`.
public actor DiskFilterPackageCache: FilterPackageCache {
    public struct Config: Sendable {
        public let directory: URL
        public let sizeCapBytes: Int

        public init(directory: URL, sizeCapBytes: Int = 100 * 1024 * 1024) {
            self.directory = directory
            self.sizeCapBytes = sizeCapBytes
        }
    }

    private let config: Config
    private var lru: [FilterPackageID] = []

    public init(config: Config) throws {
        self.config = config
        try FileManager.default.createDirectory(
            at: config.directory, withIntermediateDirectories: true
        )
        // Prefer the persisted LRU sidecar (true insertion order); fall back to
        // mtime if the sidecar is missing. Mtime is only an approximation —
        // see persistLRU for why we always write a sidecar after every mutation.
        self.lru = Self.loadPersistedLRU(from: config.directory)
            ?? Self.restoreLRU(from: config.directory)
    }

    public func lookup(id: FilterPackageID) async -> FilterPackage? {
        let pkgDir = directory(for: id)
        let manifestURL = pkgDir.appendingPathComponent("manifest.json")
        let lutURL = pkgDir.appendingPathComponent("lut.cube")
        guard
            let manifestData = try? Data(contentsOf: manifestURL),
            let lutData = try? Data(contentsOf: lutURL),
            let expected = try? checksum(of: manifestData)
        else { return nil }

        // Move to MRU and persist so the order survives process restarts.
        lru.removeAll(where: { $0 == id })
        lru.append(id)
        persistLRU()

        return FilterPackage(
            id: id,
            manifestData: manifestData,
            lutData: lutData,
            expectedChecksum: expected
        )
    }

    public func insert(_ package: FilterPackage) async throws {
        try package.verifyIntegrity()
        let pkgDir = directory(for: package.id)
        try FileManager.default.createDirectory(
            at: pkgDir, withIntermediateDirectories: true
        )
        try package.manifestData.write(to: pkgDir.appendingPathComponent("manifest.json"))
        try package.lutData.write(to: pkgDir.appendingPathComponent("lut.cube"))

        lru.removeAll(where: { $0 == package.id })
        lru.append(package.id)
        try evictIfOverCap()
        persistLRU()
    }

    public func evictAll() async throws {
        for id in lru {
            try? FileManager.default.removeItem(at: directory(for: id))
        }
        lru.removeAll()
        persistLRU()
    }

    public func cachedIDs() async -> [FilterPackageID] { lru }

    // MARK: - Internals

    private func directory(for id: FilterPackageID) -> URL {
        config.directory.appendingPathComponent(id.value, isDirectory: true)
    }

    private static let lruSidecarFilename = "lru.json"

    /// Load the persisted LRU sidecar. Returns nil if the file does not exist
    /// or fails to decode — callers fall back to mtime-based reconstruction.
    private static func loadPersistedLRU(from directory: URL) -> [FilterPackageID]? {
        let url = directory.appendingPathComponent(lruSidecarFilename)
        guard
            let data = try? Data(contentsOf: url),
            let raw = try? JSONDecoder().decode([String].self, from: data)
        else { return nil }
        // Filter out entries whose package directory no longer exists.
        let fm = FileManager.default
        return raw
            .map { FilterPackageID($0) }
            .filter { fm.fileExists(atPath: directory.appendingPathComponent($0.value).path) }
    }

    private static func restoreLRU(from directory: URL) -> [FilterPackageID] {
        let fm = FileManager.default
        guard
            let contents = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
        else { return [] }

        let sorted = contents
            // Skip the sidecar itself if it's already present.
            .filter { $0.lastPathComponent != lruSidecarFilename }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return lhsDate < rhsDate
            }
        return sorted.map { FilterPackageID($0.lastPathComponent) }
    }

    /// Atomically write the in-memory LRU order to disk.
    /// We persist on every mutation so eviction order survives process restarts.
    private func persistLRU() {
        let url = config.directory.appendingPathComponent(Self.lruSidecarFilename)
        let payload = lru.map(\.value)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func evictIfOverCap() throws {
        let fm = FileManager.default
        var totalSize = currentSize(fm: fm)
        while totalSize > config.sizeCapBytes, let oldest = lru.first {
            let pkgDir = directory(for: oldest)
            let dirSize = (try? size(of: pkgDir, fm: fm)) ?? 0
            try? fm.removeItem(at: pkgDir)
            totalSize -= dirSize
            lru.removeFirst()
        }
    }

    private func currentSize(fm: FileManager) -> Int {
        var total = 0
        for id in lru {
            total += (try? size(of: directory(for: id), fm: fm)) ?? 0
        }
        return total
    }

    private func size(of url: URL, fm: FileManager) throws -> Int {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total = 0
        for case let fileURL as URL in enumerator {
            total += (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total
    }

    private func checksum(of manifestData: Data) throws -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
            let value = (object["checksum"] as? [String: Any])?["lut"] as? String
        else {
            throw FilterPackageError.manifestMissingChecksum
        }
        return value
    }
}

// MARK: - Apply path

public protocol FilterPackageRendererBridge: Sendable {
    /// Returns a sampled color from the package's LUT at the probe — used to verify
    /// the package's renderer kernel agrees with the in-memory bake before apply.
    func smokeRender(_ package: FilterPackage, probe: RGBColor) throws -> RGBColor
}

/// Bridges a parsed `.cube` LUT from a fetched package into the existing
/// `LUTSampler` apply path. Camera/PhotoEdit renderers consume this bridge.
public struct CubeLUTRendererBridge: FilterPackageRendererBridge {
    public init() {}

    public func smokeRender(_ package: FilterPackage, probe: RGBColor) throws -> RGBColor {
        let parsed = try CubeLUTParser.parse(String(decoding: package.lutData, as: UTF8.self))
        guard case .threeDimensional(let lut) = parsed else {
            throw FilterPackageError.parseFailed
        }
        return LUTSampler.sample(lut, color: probe)
    }
}

// MARK: - Coordinator

/// One-call coordinator: lookup cache → fetch on miss → insert → return.
public actor FilterPackageCoordinator {
    private let fetcher: FilterPackageFetcher
    private let cache: any FilterPackageCache

    public init(fetcher: FilterPackageFetcher, cache: any FilterPackageCache) {
        self.fetcher = fetcher
        self.cache = cache
    }

    public func resolve(
        id: FilterPackageID,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> FilterPackage {
        if let cached = await cache.lookup(id: id) {
            onProgress?(1.0)
            return cached
        }
        let pkg = try await fetcher.fetch(id: id, onProgress: onProgress)
        try await cache.insert(pkg)
        return pkg
    }
}
