import Foundation
import Models

public actor FilterCache {
    private var filters: [Filter.ID: Filter] = [:]

    public init() {}

    public func filter(id: Filter.ID) -> Filter? {
        filters[id]
    }

    public func store(_ filter: Filter) {
        filters[filter.id] = filter
    }
}
