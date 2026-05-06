import Foundation

public struct RenderFilter: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let lutFile: String?
    public let lutSize: Int
    public let fallbackPreset: LUTPreset

    public init(
        id: UUID,
        title: String,
        lutFile: String?,
        lutSize: Int = 33,
        fallbackPreset: LUTPreset
    ) {
        self.id = id
        self.title = title
        self.lutFile = lutFile
        self.lutSize = max(lutSize, 2)
        self.fallbackPreset = fallbackPreset
    }
}

public struct FilterRenderConfiguration: Equatable, Sendable {
    public let filter: RenderFilter
    public let intensity: FilterIntensity

    public init(filter: RenderFilter, intensity: FilterIntensity = .full) {
        self.filter = filter
        self.intensity = intensity
    }

    public init(filter: RenderFilter, intensityValue: Float) {
        self.init(filter: filter, intensity: FilterIntensity(intensityValue))
    }
}
