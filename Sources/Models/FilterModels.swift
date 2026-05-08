import Foundation

public struct Filter: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let version: String
    public let author: FilterAuthor
    public let category: FilterCategory
    public let engine: FilterEngineDescriptor

    // Marketplace metadata — all optional with defaults so existing decoders
    // (BundleSeedFilterRepository's manifest.json) keep working.
    public let useCount: Int
    public let createdAt: Date?
    public let status: FilterStatus
    public let priceCoins: Int
    public let coverURL: URL?
    public let signatureSampleURL: URL?
    public let ratingAvg: Double?
    public let downloadCount: Int
    public let tags: [String]

    public init(
        id: UUID,
        title: String,
        version: String,
        author: FilterAuthor,
        category: FilterCategory,
        engine: FilterEngineDescriptor,
        useCount: Int = 0,
        createdAt: Date? = nil,
        status: FilterStatus = .approved,
        priceCoins: Int = 0,
        coverURL: URL? = nil,
        signatureSampleURL: URL? = nil,
        ratingAvg: Double? = nil,
        downloadCount: Int = 0,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.version = version
        self.author = author
        self.category = category
        self.engine = engine
        self.useCount = useCount
        self.createdAt = createdAt
        self.status = status
        self.priceCoins = priceCoins
        self.coverURL = coverURL
        self.signatureSampleURL = signatureSampleURL
        self.ratingAvg = ratingAvg
        self.downloadCount = downloadCount
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, version, author, category, engine
        case useCount, createdAt, status, priceCoins, coverURL, signatureSampleURL, ratingAvg, downloadCount, tags
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        version = try c.decode(String.self, forKey: .version)
        author = try c.decode(FilterAuthor.self, forKey: .author)
        category = try c.decode(FilterCategory.self, forKey: .category)
        engine = try c.decode(FilterEngineDescriptor.self, forKey: .engine)
        useCount = try c.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        status = try c.decodeIfPresent(FilterStatus.self, forKey: .status) ?? .approved
        priceCoins = try c.decodeIfPresent(Int.self, forKey: .priceCoins) ?? 0
        coverURL = try c.decodeIfPresent(URL.self, forKey: .coverURL)
        signatureSampleURL = try c.decodeIfPresent(URL.self, forKey: .signatureSampleURL)
        ratingAvg = try c.decodeIfPresent(Double.self, forKey: .ratingAvg)
        downloadCount = try c.decodeIfPresent(Int.self, forKey: .downloadCount) ?? 0
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

public enum FilterStatus: String, Codable, Sendable {
    case uploading
    case pendingReviewPre = "pending_review_pre"
    case pendingReview = "pending_review"
    case approved
    case rejected
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
