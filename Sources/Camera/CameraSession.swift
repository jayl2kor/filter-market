@preconcurrency import AVFoundation
import Foundation

public enum CameraSessionError: Error, Sendable {
    case permissionDenied
    case noVideoDevice
    case cannotAddInput
    case cannotAddOutput
}

public final class CameraSession: NSObject, @unchecked Sendable {
    public typealias FrameHandler = @Sendable (CMSampleBuffer) -> Void

    public var onFrame: FrameHandler?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.filtermarket.camera.session", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
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
