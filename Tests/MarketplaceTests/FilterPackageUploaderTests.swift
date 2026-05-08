import CryptoKit
import XCTest
@testable import Marketplace

final class FilterPackageUploaderTests: XCTestCase {

    // MARK: - SHA-256 helper

    func testBase64SHA256MatchesCryptoKit() {
        let data = Data("hello world".utf8)
        let expected = Data(SHA256.hash(data: data)).base64EncodedString()
        XCTAssertEqual(FilterPackageUploader.base64SHA256(of: data), expected)
    }

    // MARK: - Successful upload

    func testUploadIssuesPutToPresignedURLWithDeclaredHeaders() async throws {
        let payload = Data(repeating: 0xAB, count: 1024)
        let presignedURL = URL(string: "https://r2.test/upload?signed=1")!
        let captureBox = RequestCapture()

        URLProtocolMock.requestHandler = { request in
            captureBox.set(request: request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["ETag": "\"abc\""]
            )!
            return (response, Data())
        }

        let uploader = FilterPackageUploader(session: makeMockSession())
        let response = FilterPackageUploader.InitResponse(
            id: "filter-1",
            uploadURL: presignedURL,
            uploadHeaders: [
                "Content-Type": "application/x-moodit-package",
                "x-amz-checksum-sha256": FilterPackageUploader.base64SHA256(of: payload),
            ],
            expiresAt: Date().timeIntervalSince1970 + 600,
            objectKey: "filters/u/filter-1.fmpkg"
        )
        let progressBox = ProgressBox()
        try await uploader.upload(packageData: payload, to: response) { progressBox.set($0) }

        XCTAssertEqual(progressBox.last, 1.0, accuracy: 1e-3)
        let request = captureBox.last
        XCTAssertEqual(request?.url, presignedURL)
        XCTAssertEqual(request?.httpMethod, "PUT")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/x-moodit-package")
        XCTAssertEqual(
            request?.value(forHTTPHeaderField: "x-amz-checksum-sha256"),
            FilterPackageUploader.base64SHA256(of: payload)
        )
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Length"), String(payload.count))
    }

    // MARK: - Error mapping

    func testUploadMapsNon2xxResponseToHttpStatusError() async throws {
        let payload = Data(repeating: 0x01, count: 16)
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let uploader = FilterPackageUploader(session: makeMockSession())
        let response = FilterPackageUploader.InitResponse(
            id: "filter-x",
            uploadURL: URL(string: "https://r2.test/upload")!,
            uploadHeaders: [:],
            expiresAt: 0,
            objectKey: "filters/u/x.fmpkg"
        )
        do {
            try await uploader.upload(packageData: payload, to: response)
            XCTFail("Expected throw on 403")
        } catch FilterPackageUploader.UploadError.httpStatus(let code) {
            XCTAssertEqual(code, 403)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeMockSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: cfg)
    }
}

// MARK: - Test mocks (file-private to avoid clashes with FilterPackageTests)

private final class RequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var value: URLRequest?

    var last: URLRequest? {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set(request: URLRequest) {
        lock.lock(); defer { lock.unlock() }
        value = request
    }
}

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

private final class URLProtocolMock: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = URLProtocolMock.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
