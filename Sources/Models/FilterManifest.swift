import Foundation

public struct FilterManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: UUID
    public let version: String
    public let title: String
    public let slug: String?
    public let description: String?
    public let author: FilterAuthor
    public let category: FilterCategory?
    public let tags: [String]?
    public let license: FilterLicense?
    public let engine: FilterEngineDescriptor
    public let parameters: [FilterParameter]?
    public let createdAt: Date
    public let checksum: String

    public init(
        schemaVersion: Int,
        id: UUID,
        version: String,
        title: String,
        slug: String? = nil,
        description: String? = nil,
        author: FilterAuthor,
        category: FilterCategory? = nil,
        tags: [String]? = nil,
        license: FilterLicense? = nil,
        engine: FilterEngineDescriptor,
        parameters: [FilterParameter]? = nil,
        createdAt: Date,
        checksum: String
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.version = version
        self.title = title
        self.slug = slug
        self.description = description
        self.author = author
        self.category = category
        self.tags = tags
        self.license = license
        self.engine = engine
        self.parameters = parameters
        self.createdAt = createdAt
        self.checksum = checksum
    }
}

public enum FilterLicense: String, Codable, Sendable {
    case cc0 = "CC0-1.0"
    case ccBy = "CC-BY-4.0"
    case ccBySA = "CC-BY-SA-4.0"
    case ccByNC = "CC-BY-NC-4.0"
    case allRightsReserved = "All-Rights-Reserved"
    case commercial = "Commercial"
}
