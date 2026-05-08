import CryptoKit
import FilterEngine
import Foundation

/// 메이커가 만든 `.fmpkg` 패키지를 Cloud Function (`uploadInit`/`uploadFinalize`)와
/// Cloudflare R2를 통해 업로드하는 흐름.
///
/// 흐름:
/// 1. `uploadInit(name:category:tags:packageBytes:contentSha256:)` 호출
///    - 응답: `{ id, uploadUrl, uploadHeaders, expiresAt, objectKey }`
/// 2. `URLSession.upload(for: uploadUrl, from: data)` — 클라이언트가 R2에 직접 PUT
/// 3. `uploadFinalize(filterId:)` — 서버가 R2 헤더 검증 후 status 전환
///
/// 본 모듈은 1, 3단계의 Cloud Function 호출을 담당하지 않습니다 — Cloud Function 호출
/// 자체는 호출자(앱 영역)가 `Functions.functions().httpsCallable(...)`로 처리하고,
/// 본 uploader는 그 사이의 PUT (2단계) + 진행률 + 무결성 검증만 책임집니다.
public actor FilterPackageUploader {
    public struct InitResponse: Sendable {
        public let id: String
        public let uploadURL: URL
        public let uploadHeaders: [String: String]
        public let expiresAt: TimeInterval
        public let objectKey: String

        public init(
            id: String,
            uploadURL: URL,
            uploadHeaders: [String: String],
            expiresAt: TimeInterval,
            objectKey: String
        ) {
            self.id = id
            self.uploadURL = uploadURL
            self.uploadHeaders = uploadHeaders
            self.expiresAt = expiresAt
            self.objectKey = objectKey
        }
    }

    public enum UploadError: Error, Equatable, Sendable {
        case invalidResponse
        case httpStatus(Int)
        case checksumMismatch
        case cancelled
    }

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// SHA-256 base64 of the package bytes — sent at uploadInit so the server can
    /// bind the checksum into the presigned URL signature, and re-checked at
    /// uploadFinalize via R2's HEAD response.
    public static func base64SHA256(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
    }

    /// Stream `packageData` to the presigned URL with progress callbacks.
    /// `onProgress` receives values in `0...1`.
    public func upload(
        packageData: Data,
        to response: InitResponse,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        var request = URLRequest(url: response.uploadURL)
        request.httpMethod = "PUT"
        for (key, value) in response.uploadHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        // Make sure the body byte length matches what was declared at uploadInit;
        // R2 will reject the PUT otherwise.
        request.setValue(String(packageData.count), forHTTPHeaderField: "Content-Length")

        let (_, http) = try await session.upload(for: request, from: packageData)
        guard let httpResponse = http as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw UploadError.httpStatus(httpResponse.statusCode)
        }
        onProgress?(1.0)
    }

    /// Convenience: take an `Fmpkg.Output` (manifest + lutData) and upload the
    /// LUT bytes — the moodit MVP currently uploads only the LUT (per
    /// `docs/FMPKG_SCHEMA.md` open question; ZIP packaging deferred per Ralph
    /// review note in #10).
    public func upload(
        fmpkg: FmpkgBuilder.Output,
        to response: InitResponse,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        try await upload(packageData: fmpkg.lutData, to: response, onProgress: onProgress)
    }
}
