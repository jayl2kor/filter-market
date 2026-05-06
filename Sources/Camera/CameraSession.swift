@preconcurrency import AVFoundation
import Foundation

public enum CameraSessionError: Error, Sendable {
    case permissionDenied
    case noVideoDevice
    case cannotAddInput
    case cannotAddOutput
    case photoDataUnavailable
    case sessionUnavailable
}

public struct CapturedPhoto: Equatable, Sendable {
    public let data: Data
    public let capturedAt: Date

    public init(data: Data, capturedAt: Date = Date()) {
        self.data = data
        self.capturedAt = capturedAt
    }

    public var byteCount: Int {
        data.count
    }
}

public final class CameraSession: NSObject, @unchecked Sendable {
    public typealias FrameHandler = @Sendable (CMSampleBuffer) -> Void

    public var onFrame: FrameHandler?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.filtermarket.camera.session", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCaptureDelegates: [Int64: PhotoCaptureDelegate] = [:]
    private var isConfigured = false

    public override init() {
        super.init()
    }

    public func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            true
        case .notDetermined:
            await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            false
        @unknown default:
            false
        }
    }

    public func start() throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraSessionError.permissionDenied
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                try configureIfNeeded()
                if !captureSession.isRunning {
                    captureSession.startRunning()
                }
            } catch {
                // Start errors are surfaced during explicit configuration calls in later milestones.
            }
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self, captureSession.isRunning else { return }
            captureSession.stopRunning()
        }
    }

    public func capturePhoto() async throws -> CapturedPhoto {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraSessionError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraSessionError.sessionUnavailable)
                    return
                }

                do {
                    try configureIfNeeded()
                    if !captureSession.isRunning {
                        captureSession.startRunning()
                    }

                    let settings = AVCapturePhotoSettings()
                    let settingsID = settings.uniqueID
                    let delegate = PhotoCaptureDelegate(settingsID: settingsID) { [weak self] result in
                        self?.sessionQueue.async {
                            self?.photoCaptureDelegates[settingsID] = nil
                        }
                        continuation.resume(with: result)
                    }

                    photoCaptureDelegates[settingsID] = delegate
                    photoOutput.capturePhoto(with: settings, delegate: delegate)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1920x1080

        defer {
            captureSession.commitConfiguration()
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraSessionError.noVideoDevice
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(input) else {
            throw CameraSessionError.cannotAddInput
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw CameraSessionError.cannotAddOutput
        }
        captureSession.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        guard captureSession.canAddOutput(photoOutput) else {
            throw CameraSessionError.cannotAddOutput
        }
        captureSession.addOutput(photoOutput)

        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        isConfigured = true
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer)
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let settingsID: Int64
    private let completion: @Sendable (Result<CapturedPhoto, Error>) -> Void
    private let lock = NSLock()
    private var didComplete = false

    init(
        settingsID: Int64,
        completion: @escaping @Sendable (Result<CapturedPhoto, Error>) -> Void
    ) {
        self.settingsID = settingsID
        self.completion = completion
        super.init()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            finish(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            finish(.failure(CameraSessionError.photoDataUnavailable))
            return
        }

        finish(.success(CapturedPhoto(data: data)))
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        guard resolvedSettings.uniqueID == settingsID, let error else { return }
        finish(.failure(error))
    }

    private func finish(_ result: Result<CapturedPhoto, Error>) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        lock.unlock()

        completion(result)
    }
}
