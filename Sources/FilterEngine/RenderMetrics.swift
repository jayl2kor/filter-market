import Foundation

public struct RenderMetrics: Equatable, Sendable {
    public let framesPerSecond: Double
    public let lastGPUFrameTimeMS: Double
    public let lastCPUFrameTimeMS: Double

    public init(
        framesPerSecond: Double = 0,
        lastGPUFrameTimeMS: Double = 0,
        lastCPUFrameTimeMS: Double = 0
    ) {
        self.framesPerSecond = framesPerSecond
        self.lastGPUFrameTimeMS = lastGPUFrameTimeMS
        self.lastCPUFrameTimeMS = lastCPUFrameTimeMS
    }

    public var displayText: String {
        let fps = Int(framesPerSecond.rounded())
        let gpu = String(format: "%.2f", lastGPUFrameTimeMS)
        let cpu = String(format: "%.2f", lastCPUFrameTimeMS)
        return "\(fps) FPS · GPU \(gpu)ms · CPU \(cpu)ms"
    }
}
