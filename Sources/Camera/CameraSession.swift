@preconcurrency import AVFoundation
import CoreGraphics
import Foundation

public enum CameraSessionError: Error, Sendable {
    case permissionDenied
    case noVideoDevice
    case cannotAddInput
    case cannotAddOutput
    case photoDataUnavailable
    case sessionUnavailable
}

public struct CameraFocusPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    public init(viewLocation: CGPoint, viewSize: CGSize, isMirrored: Bool = false) {
        let width = max(Double(viewSize.width), 1)
        let height = max(Double(viewSize.height), 1)
        let normalizedX = min(max(Double(viewLocation.x) / width, 0), 1)
        let normalizedY = min(max(Double(viewLocation.y) / height, 0), 1)

        x = isMirrored ? 1 - normalizedX : normalizedX
        y = normalizedY
    }

    public init(viewLocation: CGPoint, activeFrame: CGRect, isMirrored: Bool = false) {
        let width = max(Double(activeFrame.width), 1)
        let height = max(Double(activeFrame.height), 1)
        let normalizedX = min(max(Double(viewLocation.x - activeFrame.minX) / width, 0), 1)
        let normalizedY = min(max(Double(viewLocation.y - activeFrame.minY) / height, 0), 1)

        x = isMirrored ? 1 - normalizedX : normalizedX
        y = normalizedY
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

public enum CameraPosition: Equatable, Sendable {
    case back
    case front

    public var toggled: CameraPosition {
        switch self {
        case .back:
            .front
        case .front:
            .back
        }
    }

    var captureDevicePosition: AVCaptureDevice.Position {
        switch self {
        case .back:
            .back
        case .front:
            .front
        }
    }
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
    private let sessionQueue = DispatchQueue(label: "app.moodit.camera.session", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var photoCaptureDelegates: [Int64: PhotoCaptureDelegate] = [:]
    private var currentPosition = CameraPosition.back
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

    public func start() async throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraSessionError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self, captureSession.isRunning else { return }
            captureSession.stopRunning()
        }
    }

    public func switchCamera() async throws -> CameraPosition {
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
                    let nextPosition = currentPosition.toggled
                    try replaceCameraInput(position: nextPosition)
                    continuation.resume(returning: currentPosition)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func focusAndExpose(at point: CameraFocusPoint) async throws {
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
                    try applyFocusAndExposure(at: point)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
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

        try addCameraInput(position: currentPosition)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw CameraSessionError.cannotAddOutput
        }
        captureSession.addOutput(videoOutput)

        guard captureSession.canAddOutput(photoOutput) else {
            throw CameraSessionError.cannotAddOutput
        }
        captureSession.addOutput(photoOutput)

        updateVideoConnections()
        isConfigured = true
    }

    private func replaceCameraInput(position: CameraPosition) throws {
        let previousInput = videoInput
        let previousPosition = currentPosition

        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }

        if let previousInput {
            captureSession.removeInput(previousInput)
        }

        do {
            try addCameraInput(position: position)
            updateVideoConnections()
        } catch {
            if let previousInput, captureSession.canAddInput(previousInput) {
                captureSession.addInput(previousInput)
                videoInput = previousInput
                currentPosition = previousPosition
                updateVideoConnections()
            }
            throw error
        }
    }

    private func addCameraInput(position: CameraPosition) throws {
        guard
            let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: position.captureDevicePosition
            )
        else {
            throw CameraSessionError.noVideoDevice
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(input) else {
            throw CameraSessionError.cannotAddInput
        }

        captureSession.addInput(input)
        videoInput = input
        currentPosition = position
    }

    private func updateVideoConnections() {
        updateVideoConnection(videoOutput.connection(with: .video))
        updateVideoConnection(photoOutput.connection(with: .video))
    }

    private func updateVideoConnection(_ connection: AVCaptureConnection?) {
        guard let connection else { return }

        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = currentPosition == .front
        }
    }

    private func applyFocusAndExposure(at point: CameraFocusPoint) throws {
        guard let device = videoInput?.device else {
            throw CameraSessionError.noVideoDevice
        }

        try device.lockForConfiguration()
        defer {
            device.unlockForConfiguration()
        }

        let devicePoint = point.cgPoint
        if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
            device.focusPointOfInterest = devicePoint
            device.focusMode = .autoFocus
        }

        if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposurePointOfInterest = devicePoint
            device.exposureMode = .continuousAutoExposure
        }

        if device.isSubjectAreaChangeMonitoringEnabled == false {
            device.isSubjectAreaChangeMonitoringEnabled = true
        }
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
