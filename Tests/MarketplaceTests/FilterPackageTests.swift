import CryptoKit
import XCTest
@testable import Marketplace
@testable import FilterEngine

final class FilterPackageTests: XCTestCase {

    // MARK: - Test fixtures

    /// Build a deterministic package payload from a small LUT, matching the
    /// `.fmpkg` manifest shape produced by `FmpkgBuilder`.
    private func makePackage(
        size: Int = 4,
        id: FilterPackageID = FilterPackageID("sunset")
    ) -> FilterPackage {
        let lut = LUT3D.identity(size: size)
        let lutText = CubeLUTWriter.text(for: lut, title: "test")
        let lutData = Data(lutText.utf8)
        let checksum = sha256Hex(lutData)
        let manifest: [String: Any] = [
            "schemaVersion": 1,
            "id": id.value,
            "checksum": ["algorithm": "sha256", "lut": checksum],
            "engine": ["type": "lut+params", "lutSize": size, "lutFile": "luts/lut.cube"],
        ]
        let manifestData = try! JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        return FilterPackage(
            id: id,
            manifestData: manifestData,
            lutData: lutData,
            expectedChecksum: checksum
        )
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Integrity

    func testVerifyIntegritySucceedsForGoodPackage() throws {
        let pkg = makePackage()
        try pkg.verifyIntegrity()
    }

    func testVerifyIntegrityRejectsTampering() {
        let original = makePackage()
        var bytes = Array(original.lutData)
        bytes[5] ^= 0xFF
        let tampered = FilterPackage(
            id: original.id,
            manifestData: original.manifestData,
            lutData: Data(bytes),
            expectedChecksum: original.expectedChecksum
        )
        XCTAssertThrowsError(try tampered.verifyIntegrity()) { error in
            guard case FilterPackageError.checksumMismatch = error else {
                return XCTFail("Expected checksumMismatch, got \(error)")
            }
        }
    }

    // MARK: - Disk cache

    func testCacheRoundTripPersistsAndRetrievesPackage() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("moodit-fpkg-test-\(UUID().uuidString)")
        let cache = try DiskFilterPackageCache(
            config: DiskFilterPackageCache.Config(directory: temp)
        )
        let pkg = makePackage()
        try await cache.insert(pkg)

        let restored = await cache.lookup(id: pkg.id)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.expectedChecksum, pkg.expectedChecksum)
        XCTAssertEqual(restored?.lutData, pkg.lutData)

        try await cache.evictAll()
        try? FileManager.default.removeItem(at: temp)
    }

    func testCacheLookupMissReturnsNil() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("moodit-fpkg-test-\(UUID().uuidString)")
        let cache = try DiskFilterPackageCache(
            config: DiskFilterPackageCache.Config(directory: temp)
        )
        let missing = await cache.lookup(id: FilterPackageID("never-inserted"))
        XCTAssertNil(missing)
        try? FileManager.default.removeItem(at: temp)
    }

    /// Reviewer fix: LRU order must survive process restarts via the sidecar file.
    /// Without persistence, mtime-based reconstruction silently corrupts the eviction
    /// order, which is the bug this test would catch.
    func testCacheLRUOrderSurvivesProcessRestart() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("moodit-fpkg-restart-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }

        let cfg = DiskFilterPackageCache.Config(directory: temp, sizeCapBytes: 100_000)
        do {
            let cache1 = try DiskFilterPackageCache(config: cfg)
            try await cache1.insert(makePackage(size: 4, id: FilterPackageID("alpha")))
            try await cache1.insert(makePackage(size: 4, id: FilterPackageID("beta")))
            try await cache1.insert(makePackage(size: 4, id: FilterPackageID("gamma")))
            // Touch alpha so the in-memory LRU order becomes [beta, gamma, alpha].
            _ = await cache1.lookup(id: FilterPackageID("alpha"))
        }

        // Recreate the cache (simulating an app restart) and confirm the LRU
        // order matches what was last persisted.
        let cache2 = try DiskFilterPackageCache(config: cfg)
        let restored = await cache2.cachedIDs().map(\.value)
        XCTAssertEqual(restored, ["beta", "gamma", "alpha"])
    }

    func testCacheEvictsOldestWhenOverCap() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("moodit-fpkg-test-\(UUID().uuidString)")
        // Each size-4 LUT package serializes to ~1.4KB on disk. Cap at 4KB so
        // exactly two packages fit; inserting a third evicts the oldest only.
        let cache = try DiskFilterPackageCache(
            config: DiskFilterPackageCache.Config(directory: temp, sizeCapBytes: 4_000)
        )

        let a = makePackage(size: 4, id: FilterPackageID("a"))
        let b = makePackage(size: 4, id: FilterPackageID("b"))
        let c = makePackage(size: 4, id: FilterPackageID("c"))

        try await cache.insert(a)
        try await cache.insert(b)
        try await cache.insert(c)

        let cached = await cache.cachedIDs().map(\.value)
        XCTAssertFalse(cached.contains("a"), "expected 'a' to be evicted (oldest); got \(cached)")
        XCTAssertTrue(cached.contains("b"))
        XCTAssertTrue(cached.contains("c"))
        try? FileManager.default.removeItem(at: temp)
    }

    // MARK: - Fetcher (URLProtocol mock)

    func testFetcherReturnsAndVerifiesPackage() async throws {
        let pkg = makePackage()
        URLProtocolMock.requestHandler = { request in
            let url = request.url!
            let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            if url.lastPathComponent == "manifest.json" {
                return (response, pkg.manifestData)
            } else {
                return (response, pkg.lutData)
            }
        }
        let fetcher = URLSessionFilterPackageFetcher(
            session: makeMockSession(),
            config: URLSessionFilterPackageFetcher.Config(
                manifestURL: { id in
                    URL(string: "https://mock.test/\(id.value)/manifest.json")!
                },
                lutURL: { id in
                    URL(string: "https://mock.test/\(id.value)/lut.cube")!
                }
            )
        )

        let progressBox = ProgressBox()
        let fetched = try await fetcher.fetch(id: pkg.id) { progressBox.set($0) }
        XCTAssertEqual(fetched.expectedChecksum, pkg.expectedChecksum)
        XCTAssertEqual(progressBox.last, 1.0, accuracy: 0.001)
    }

    func testFetcherRejectsTamperedLUT() async {
        let pkg = makePackage()
        var corrupted = Array(pkg.lutData)
        corrupted[0] ^= 0xFF
        URLProtocolMock.requestHandler = { request in
            let url = request.url!
            let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (
                response,
                url.lastPathComponent == "manifest.json" ? pkg.manifestData : Data(corrupted)
            )
        }
        let fetcher = URLSessionFilterPackageFetcher(
            session: makeMockSession(),
            config: URLSessionFilterPackageFetcher.Config(
                manifestURL: { id in URL(string: "https://mock.test/\(id.value)/manifest.json")! },
                lutURL: { id in URL(string: "https://mock.test/\(id.value)/lut.cube")! }
            )
        )
        do {
            _ = try await fetcher.fetch(id: pkg.id, onProgress: nil)
            XCTFail("Should have rejected corrupted LUT")
        } catch FilterPackageError.checksumMismatch {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Apply path

    func testRendererBridgeRoundTripsViaSampler() throws {
        let bridge = CubeLUTRendererBridge()
        let pkg = makePackage(size: 8)
        let probe = RGBColor(red: 0.3, green: 0.6, blue: 0.9)
        let viaPackage = try bridge.smokeRender(pkg, probe: probe)
        // Identity LUT — smoke output should match probe within Float quantization
        // produced by the .cube text writer (6 decimal places).
        XCTAssertEqual(viaPackage.red, probe.red, accuracy: 1e-3)
        XCTAssertEqual(viaPackage.green, probe.green, accuracy: 1e-3)
        XCTAssertEqual(viaPackage.blue, probe.blue, accuracy: 1e-3)
    }

    // MARK: - Coordinator

    func testCoordinatorMissThenHitUsesCache() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("moodit-fpkg-coord-\(UUID().uuidString)")
        let cache = try DiskFilterPackageCache(
            config: DiskFilterPackageCache.Config(directory: temp)
        )
        let pkg = makePackage()

        URLProtocolMock.requestHandler = { request in
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, url.lastPathComponent == "manifest.json" ? pkg.manifestData : pkg.lutData)
        }
        URLProtocolMock.callCount = 0
        let fetcher = URLSessionFilterPackageFetcher(
            session: makeMockSession(),
            config: URLSessionFilterPackageFetcher.Config(
                manifestURL: { id in URL(string: "https://mock.test/\(id.value)/manifest.json")! },
                lutURL: { id in URL(string: "https://mock.test/\(id.value)/lut.cube")! }
            )
        )
        let coord = FilterPackageCoordinator(fetcher: fetcher, cache: cache)

        let first = try await coord.resolve(id: pkg.id)
        let second = try await coord.resolve(id: pkg.id)

        XCTAssertEqual(first.expectedChecksum, pkg.expectedChecksum)
        XCTAssertEqual(second.expectedChecksum, pkg.expectedChecksum)
        XCTAssertEqual(URLProtocolMock.callCount, 2, "second resolve should hit cache, only first should fetch (manifest+lut = 2 calls)")
        try? FileManager.default.removeItem(at: temp)
    }

    // MARK: - Helpers

    private func makeMockSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: cfg)
    }
}

// MARK: - ProgressBox

/// Sendable wrapper for capturing progress callbacks from a concurrently-executing
/// fetcher in tests.
private final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Double = 0

    var last: Double {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set(_ v: Double) {
        lock.lock(); defer { lock.unlock() }
        value = v
    }
}

// MARK: - URLProtocolMock

private final class URLProtocolMock: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var callCount: Int = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = URLProtocolMock.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        URLProtocolMock.callCount += 1
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
