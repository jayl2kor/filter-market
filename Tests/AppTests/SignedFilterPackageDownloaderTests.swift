import CryptoKit
import FilterEngine
import XCTest
@testable import moodit

final class SignedFilterPackageDownloaderTests: XCTestCase {
    override func tearDown() {
        SignedDownloadURLProtocolMock.requestHandler = nil
        super.tearDown()
    }

    func testDownloadPersistsOnlyValidLUTPayload() async throws {
        let lutData = makeLUTData()
        SignedDownloadURLProtocolMock.requestHandler = { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Length": "\(lutData.count)"]
                )!,
                lutData
            )
        }
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let expectedSHA256 = sha256Hex(lutData)
        let storedURL = try await SignedFilterPackageDownloader.download(
            from: URL(string: "https://signed.example.com/filter.fmpkg")!,
            filterID: "filter/one",
            expectedSHA256: expectedSHA256,
            session: makeMockSession(),
            directory: directory,
            onProgress: { _ in }
        )

        XCTAssertEqual(storedURL.lastPathComponent, "\(expectedSHA256).fmpkg")
        XCTAssertEqual(try Data(contentsOf: storedURL), lutData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(expectedSHA256).fmpkg.download").path))
    }

    func testDownloadUsesChecksumCacheWhenPresent() async throws {
        let lutData = makeLUTData()
        let expectedSHA256 = sha256Hex(lutData)
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cachedURL = directory.appendingPathComponent("\(expectedSHA256).fmpkg")
        try lutData.write(to: cachedURL)
        SignedDownloadURLProtocolMock.requestHandler = { _ in
            XCTFail("Cache hit should not fetch the signed URL")
            throw URLError(.badServerResponse)
        }

        let storedURL = try await SignedFilterPackageDownloader.download(
            from: URL(string: "https://signed.example.com/filter.fmpkg")!,
            filterID: "filter/one",
            expectedSHA256: expectedSHA256,
            session: makeMockSession(),
            directory: directory,
            onProgress: { _ in }
        )

        XCTAssertEqual(storedURL, cachedURL)
        XCTAssertEqual(try Data(contentsOf: storedURL), lutData)
    }

    func testDownloadRejectsChecksumMismatchAndRemovesTemporaryFile() async throws {
        let lutData = makeLUTData()
        SignedDownloadURLProtocolMock.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                lutData
            )
        }
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            _ = try await SignedFilterPackageDownloader.download(
                from: URL(string: "https://signed.example.com/filter.fmpkg")!,
                filterID: "filter-one",
                expectedSHA256: "wrong-checksum",
                session: makeMockSession(),
                directory: directory,
                onProgress: { _ in }
            )
            XCTFail("Expected checksum mismatch")
        } catch SignedFilterPackageDownloader.DownloadError.checksumMismatch {
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("filter-one.fmpkg").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("filter-one.fmpkg.download").path))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDownloadRejectsInvalidLUTPayload() async throws {
        let invalidData = Data("not a cube lut".utf8)
        SignedDownloadURLProtocolMock.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                invalidData
            )
        }
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            _ = try await SignedFilterPackageDownloader.download(
                from: URL(string: "https://signed.example.com/filter.fmpkg")!,
                filterID: "filter-one",
                session: makeMockSession(),
                directory: directory,
                onProgress: { _ in }
            )
            XCTFail("Expected invalid LUT payload")
        } catch SignedFilterPackageDownloader.DownloadError.invalidLUTPayload {
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("filter-one.fmpkg").path))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDownloadRejectsResponseOverSizeLimitBeforeWriting() async throws {
        let lutData = makeLUTData()
        SignedDownloadURLProtocolMock.requestHandler = { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Length": "\(lutData.count)"]
                )!,
                lutData
            )
        }
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            _ = try await SignedFilterPackageDownloader.download(
                from: URL(string: "https://signed.example.com/filter.fmpkg")!,
                filterID: "filter-one",
                maxBytes: 8,
                session: makeMockSession(),
                directory: directory,
                onProgress: { _ in }
            )
            XCTFail("Expected response too large")
        } catch SignedFilterPackageDownloader.DownloadError.responseTooLarge {
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("filter-one.fmpkg").path))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPackageCacheUsageBytesSumsCachedFilesRecursively() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 3).write(to: directory.appendingPathComponent("one.fmpkg"))

        let nestedDirectory = directory.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try Data(repeating: 0x2, count: 5).write(to: nestedDirectory.appendingPathComponent("two.fmpkg"))

        XCTAssertEqual(SignedFilterPackageDownloader.packageCacheUsageBytes(directory: directory), 8)
    }

    func testFormattedCacheUsageDoesNotUseLegacyHardcodedValue() {
        let text = SignedFilterPackageDownloader.formattedCacheUsage(usedBytes: 0)

        XCTAssertFalse(text.contains("42"))
        XCTAssertTrue(text.contains("/"))
        XCTAssertFalse(text.isEmpty)
    }

    private func makeLUTData() -> Data {
        let lut = LUT3D.identity(size: 4)
        return Data(CubeLUTWriter.text(for: lut, title: "download-test").utf8)
    }

    private func sha256Base64(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).base64EncodedString()
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("moodit-signed-download-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SignedDownloadURLProtocolMock.self]
        return URLSession(configuration: config)
    }
}

private final class SignedDownloadURLProtocolMock: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
