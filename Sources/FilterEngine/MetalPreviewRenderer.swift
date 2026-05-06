@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import Metal
import MetalKit
import QuartzCore
import UIKit

public enum MetalPreviewError: Error, Sendable {
    case missingImageBuffer
    case cannotCreateTextureCache
    case cannotCreateTexture(CVReturn)
    case missingShaderLibrary
    case missingShaderFunction(String)
}

public final class MetalPreviewRenderer: NSObject, @unchecked Sendable {
    public var isAvailable: Bool {
        device != nil && commandQueue != nil
    }

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let lutResourceBundle: Bundle?
    private var textureCache: CVMetalTextureCache?
    private var pipelineState: MTLRenderPipelineState?
    private var lutTexture: MTLTexture?
    private var activeConfiguration: FilterRenderConfiguration?
    private var uniforms = PreviewUniforms(intensity: 0.65, frameAspectRatio: 1, drawableAspectRatio: 1)

    private let lock = NSLock()
    private var currentFrame: CameraFrameTextures?
    private var metrics = RenderMetrics()
    private var frameCount = 0
    private var fpsWindowStart = CACurrentMediaTime()

    public convenience override init() {
        self.init(lutResourceBundle: nil)
    }

    public init(lutResourceBundle: Bundle?) {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.lutResourceBundle = lutResourceBundle

        super.init()

        if let device {
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
            pipelineState = try? Self.makePipelineState(device: device)
            lutTexture = LUTTextureFactory.makeWarmLUT(device: device)
        }
    }

    public func snapshotMetrics() -> RenderMetrics {
        lock.lock()
        defer { lock.unlock() }
        return metrics
    }

    public func setIntensity(_ intensity: Float) {
        let intensity = FilterIntensity(intensity)
        lock.lock()
        uniforms.intensity = intensity.value
        if let activeConfiguration {
            self.activeConfiguration = FilterRenderConfiguration(
                filter: activeConfiguration.filter,
                intensity: intensity
            )
        }
        lock.unlock()
    }

    public func applyFilter(_ filter: PreviewFilter) {
        apply(configuration: FilterRenderConfiguration(filter: filter.renderFilter, intensityValue: currentIntensity()))
    }

    public func apply(configuration: FilterRenderConfiguration) {
        guard let device else { return }

        lock.lock()
        let shouldReloadTexture = activeConfiguration?.filter != configuration.filter
        lock.unlock()

        let texture: MTLTexture?
        if shouldReloadTexture {
            texture = makeLUTTexture(device: device, filter: configuration.filter)
            guard texture != nil else { return }
        } else {
            texture = nil
        }

        lock.lock()
        activeConfiguration = configuration
        uniforms.intensity = configuration.intensity.value
        if let texture {
            lutTexture = texture
        }
        lock.unlock()
    }

    private func currentIntensity() -> Float {
        lock.lock()
        defer { lock.unlock() }
        return uniforms.intensity
    }

    private func makeLUTTexture(device: MTLDevice, filter: RenderFilter) -> MTLTexture? {
        if let lutResourceBundle, let lutFile = filter.lutFile {
            return (try? LUTTextureFactory.makeLUT(
                device: device,
                bundle: lutResourceBundle,
                resourcePath: lutFile,
                size: filter.lutSize
            )) ?? LUTTextureFactory.makeLUT(device: device, preset: filter.fallbackPreset, size: filter.lutSize)
        }

        return LUTTextureFactory.makeLUT(device: device, preset: filter.fallbackPreset, size: filter.lutSize)
    }

    @MainActor
    public func configure(_ view: MTKView) {
        view.device = device
        view.delegate = self
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.025, alpha: 1)
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer) {
        guard let frame = try? makeFrameTextures(from: sampleBuffer) else { return }

        lock.lock()
        currentFrame = frame
        lock.unlock()
    }

    private static func makePipelineState(device: MTLDevice) throws -> MTLRenderPipelineState {
        let bundle = Bundle(for: MetalPreviewRenderer.self)
        let library = (try? device.makeDefaultLibrary(bundle: bundle)) ?? (try? device.makeLibrary(source: ShaderSources.basicYUV, options: nil))

        guard let library else {
            throw MetalPreviewError.missingShaderLibrary
        }
        guard let vertex = library.makeFunction(name: "fullscreen_vertex") else {
            throw MetalPreviewError.missingShaderFunction("fullscreen_vertex")
        }
        guard let fragment = library.makeFunction(name: "yuv_to_rgb_fragment") else {
            throw MetalPreviewError.missingShaderFunction("yuv_to_rgb_fragment")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func makeFrameTextures(from sampleBuffer: CMSampleBuffer) throws -> CameraFrameTextures {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw MetalPreviewError.missingImageBuffer
        }
        guard let textureCache else {
            throw MetalPreviewError.cannotCreateTextureCache
        }

        let width = CVPixelBufferGetWidthOfPlane(imageBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0)
        let chromaWidth = CVPixelBufferGetWidthOfPlane(imageBuffer, 1)
        let chromaHeight = CVPixelBufferGetHeightOfPlane(imageBuffer, 1)

        var yRef: CVMetalTexture?
        var cbcrRef: CVMetalTexture?

        let yStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            imageBuffer,
            nil,
            .r8Unorm,
            width,
            height,
            0,
            &yRef
        )
        guard yStatus == kCVReturnSuccess, let yRef, let yTexture = CVMetalTextureGetTexture(yRef) else {
            throw MetalPreviewError.cannotCreateTexture(yStatus)
        }

        let cbcrStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            imageBuffer,
            nil,
            .rg8Unorm,
            chromaWidth,
            chromaHeight,
            1,
            &cbcrRef
        )
        guard cbcrStatus == kCVReturnSuccess, let cbcrRef, let cbcrTexture = CVMetalTextureGetTexture(cbcrRef) else {
            throw MetalPreviewError.cannotCreateTexture(cbcrStatus)
        }

        let aspectRatio = Float(width) / Float(max(height, 1))
        return CameraFrameTextures(
            yRef: yRef,
            cbcrRef: cbcrRef,
            yTexture: yTexture,
            cbcrTexture: cbcrTexture,
            aspectRatio: aspectRatio
        )
    }
}

extension MetalPreviewRenderer: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let commandQueue, let drawable = view.currentDrawable, let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

        lock.lock()
        let frame = currentFrame
        let lutTexture = lutTexture
        var uniforms = uniforms
        lock.unlock()

        if let pipelineState, let frame, let lutTexture {
            uniforms.frameAspectRatio = frame.aspectRatio
            if view.drawableSize.width > 0, view.drawableSize.height > 0 {
                uniforms.drawableAspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
            }

            let frameStart = CACurrentMediaTime()
            encoder?.setRenderPipelineState(pipelineState)
            encoder?.setFragmentTexture(frame.yTexture, index: 0)
            encoder?.setFragmentTexture(frame.cbcrTexture, index: 1)
            encoder?.setFragmentTexture(lutTexture, index: 2)
            encoder?.setFragmentBytes(&uniforms, length: MemoryLayout<PreviewUniforms>.stride, index: 0)
            encoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

            commandBuffer?.addCompletedHandler { [weak self] buffer in
                let cpuFrameMS = (CACurrentMediaTime() - frameStart) * 1000
                let gpuFrameMS = max(buffer.gpuEndTime - buffer.gpuStartTime, 0) * 1000
                self?.recordFrame(cpuFrameMS: cpuFrameMS, gpuFrameMS: gpuFrameMS)
            }
        }

        encoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }

    private func recordFrame(cpuFrameMS: Double, gpuFrameMS: Double) {
        lock.lock()
        defer { lock.unlock() }

        frameCount += 1
        let now = CACurrentMediaTime()
        let elapsed = now - fpsWindowStart

        var fps = metrics.framesPerSecond
        if elapsed >= 1 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            fpsWindowStart = now
        }

        metrics = RenderMetrics(
            framesPerSecond: fps,
            lastGPUFrameTimeMS: gpuFrameMS,
            lastCPUFrameTimeMS: cpuFrameMS
        )
    }
}

private struct CameraFrameTextures {
    let yRef: CVMetalTexture
    let cbcrRef: CVMetalTexture
    let yTexture: MTLTexture
    let cbcrTexture: MTLTexture
    let aspectRatio: Float
}
