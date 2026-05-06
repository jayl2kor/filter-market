import Foundation

public struct Filter: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let version: String
    public let author: FilterAuthor
    public let category: FilterCategory
    public let engine: FilterEngineDescriptor

    public init(
        id: UUID,
        title: String,
        version: String,
        author: FilterAuthor,
        category: FilterCategory,
        engine: FilterEngineDescriptor
    ) {
        self.id = id
        self.title = title
        self.version = version
        self.author = author
        self.category = category
        self.engine = engine
    }
}

public struct FilterAuthor: Codable, Equatable, Sendable {
    public let uid: String
    public let displayName: String

    public init(uid: String, displayName: String) {
        self.uid = uid
        self.displayName = displayName
    }
}

public enum FilterCategory: String, Codable, CaseIterable, Sendable {
    case cinematic
    case vintage
    case pastel
    case bw
    case portrait
    case food
    case travel
    case anime
    case mood
    case bright
    case moody
    case skin
}

public struct FilterEngineDescriptor: Codable, Equatable, Sendable {
    public let type: FilterEngineType
    public let minAppVersion: String
    public let minIOSVersion: String
    public let lutSize: Int?
    public let lutFile: String?

    public init(
        type: FilterEngineType,
        minAppVersion: String,
        minIOSVersion: String,
        lutSize: Int?,
        lutFile: String?
    ) {
        self.type = type
        self.minAppVersion = minAppVersion
        self.minIOSVersion = minIOSVersion
        self.lutSize = lutSize
        self.lutFile = lutFile
    }
}

public enum FilterEngineType: String, Codable, Sendable {
    case lutParams = "lut+params"
    case lutMSL = "lut+msl"
    case nodeGraph = "nodegraph"
}

public struct FilterParameter: Codable, Equatable, Sendable {
    public let key: String
    public let label: String
    public let type: FilterParameterType
    public let min: Double?
    public let max: Double?
    public let defaultValue: Double?

    public init(
        key: String,
        label: String,
        type: FilterParameterType,
        min: Double? = nil,
        max: Double? = nil,
        defaultValue: Double? = nil
    ) {
        self.key = key
        self.label = label
        self.type = type
        self.min = min
        self.max = max
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case label
        case type
        case min
        case max
        case defaultValue = "default"
    }
}

public enum FilterParameterType: String, Codable, Sendable {
    case float
    case color
    case bool
}
