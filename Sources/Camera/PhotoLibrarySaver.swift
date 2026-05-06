import Foundation
@preconcurrency import Photos

public enum PhotoLibraryAuthorizationStatus: Equatable, Sendable {
    case authorized
    case limited
    case denied
    case restricted
    case notDetermined
}

public enum PhotoLibrarySaveResult: Equatable, Sendable {
    case saved
    case permissionDenied
    case permissionRestricted
    case permissionNotDetermined
    case invalidData
    case failed
}

public protocol PhotoLibrarySaving: Sendable {
    func savePhoto(data: Data) async -> PhotoLibrarySaveResult
}

public struct PhotoLibrarySaver: PhotoLibrarySaving {
    private let authorizationStatus: @Sendable () async -> PhotoLibraryAuthorizationStatus
    private let writePhotoData: @Sendable (Data) async throws -> Void

    public init(
        authorizationStatus: @escaping @Sendable () async -> PhotoLibraryAuthorizationStatus,
        writePhotoData: @escaping @Sendable (Data) async throws -> Void
    ) {
        self.authorizationStatus = authorizationStatus
        self.writePhotoData = writePhotoData
    }

    public static func live() -> PhotoLibrarySaver {
        PhotoLibrarySaver(
            authorizationStatus: {
                await PhotoKitPhotoLibrary.requestAddOnlyAuthorizationStatus()
            },
            writePhotoData: { data in
                try await PhotoKitPhotoLibrary.writePhoto(data: data)
            }
        )
    }

    public func savePhoto(data: Data) async -> PhotoLibrarySaveResult {
        guard !data.isEmpty else {
            return .invalidData
        }

        switch await authorizationStatus() {
        case .authorized, .limited:
            do {
                try await writePhotoData(data)
                return .saved
            } catch {
                return .failed
            }
        case .denied:
            return .permissionDenied
        case .restricted:
            return .permissionRestricted
        case .notDetermined:
            return .permissionNotDetermined
        }
    }
}

private enum PhotoKitPhotoLibrary {
    static func requestAddOnlyAuthorizationStatus() async -> PhotoLibraryAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status != .notDetermined {
            return PhotoLibraryAuthorizationStatus(status)
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: PhotoLibraryAuthorizationStatus(status))
            }
        }
    }

    static func writePhoto(data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { isSaved, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if isSaved {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibraryWriteError.notSaved)
                }
            }
        }
    }
}

private extension PhotoLibraryAuthorizationStatus {
    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            self = .authorized
        case .limited:
            self = .limited
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .restricted
        }
    }
}

private enum PhotoLibraryWriteError: Error {
    case notSaved
}
