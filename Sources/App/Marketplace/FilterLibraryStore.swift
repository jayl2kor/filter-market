import Foundation
import Marketplace
import Models

// Disambiguate from FirebaseFirestore.Filter.
typealias AppFilter = Models.Filter

@MainActor
final class FilterLibraryStore: ObservableObject {
    @Published private(set) var filters: [AppFilter] = []
    @Published private(set) var downloadedFilterIDs: Set<AppFilter.ID> = []
    @Published private(set) var favoriteFilterIDs: Set<AppFilter.ID> = []
    @Published var selectedFilterID: AppFilter.ID?
    @Published private(set) var loadError: Error?
    @Published private(set) var isLoading = false
    @Published private(set) var trendingFilters: [AppFilter] = []
    @Published private(set) var newFiltersList: [AppFilter] = []

    private let repository: any FilterRepository

    init(repository: any FilterRepository = BundleSeedFilterRepository()) {
        self.repository = repository
    }

    var selectedFilter: AppFilter? {
        guard let selectedFilterID else { return filters.first }
        return filters.first { $0.id == selectedFilterID }
    }

    var libraryFilters: [AppFilter] {
        filters.filter { downloadedFilterIDs.contains($0.id) }
    }

    func load(force: Bool = false) async {
        guard force || filters.isEmpty || loadError != nil else { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let loadedFilters = try await repository.listFilters()
            filters = loadedFilters
            selectedFilterID = loadedFilters.first?.id
            if let firstFilter = loadedFilters.first {
                downloadedFilterIDs.insert(firstFilter.id)
            }
            do {
                trendingFilters = try await repository.trending(limit: 24)
            } catch {
                trendingFilters = []
            }
            do {
                newFiltersList = try await repository.newFilters(limit: 24)
            } catch {
                newFiltersList = []
            }
        } catch {
            loadError = error
            filters = []
            trendingFilters = []
            newFiltersList = []
        }
    }

    func retry() async {
        loadError = nil
        await load()
    }

    func resetUserScopedState() {
        downloadedFilterIDs = []
        favoriteFilterIDs = []
        selectedFilterID = nil
    }

    func setDownloadedFilterIDs(_ ids: Set<AppFilter.ID>) {
        downloadedFilterIDs = ids
    }

    func setFavoriteFilterIDs(_ ids: Set<AppFilter.ID>) {
        favoriteFilterIDs = ids
    }

    func select(_ filter: AppFilter) {
        selectedFilterID = filter.id
        downloadedFilterIDs.insert(filter.id)
    }

    func markDownloaded(_ id: AppFilter.ID) {
        downloadedFilterIDs.insert(id)
    }

    func removeDownload(_ filter: AppFilter) -> FilterLibraryRemovalSnapshot {
        let snapshot = FilterLibraryRemovalSnapshot(
            filterID: filter.id,
            hadDownload: downloadedFilterIDs.contains(filter.id),
            hadFavorite: favoriteFilterIDs.contains(filter.id)
        )
        downloadedFilterIDs.remove(filter.id)
        favoriteFilterIDs.remove(filter.id)
        if selectedFilterID == filter.id {
            selectedFilterID = libraryFilters.first?.id ?? filters.first?.id
        }
        return snapshot
    }

    func restore(_ snapshot: FilterLibraryRemovalSnapshot) {
        if snapshot.hadDownload {
            downloadedFilterIDs.insert(snapshot.filterID)
        }
        if snapshot.hadFavorite {
            favoriteFilterIDs.insert(snapshot.filterID)
        }
    }

    @discardableResult
    func toggleFavorite(_ filter: AppFilter) -> Bool {
        if favoriteFilterIDs.contains(filter.id) {
            favoriteFilterIDs.remove(filter.id)
            return false
        } else {
            favoriteFilterIDs.insert(filter.id)
            return true
        }
    }

    func rollbackFavorite(_ filter: AppFilter, shouldSave: Bool) {
        if shouldSave {
            favoriteFilterIDs.remove(filter.id)
        } else {
            favoriteFilterIDs.insert(filter.id)
        }
    }

    func isFavorite(_ filter: AppFilter) -> Bool {
        favoriteFilterIDs.contains(filter.id)
    }

    func isDownloaded(_ filter: AppFilter) -> Bool {
        downloadedFilterIDs.contains(filter.id)
    }

    func filter(matching routeID: String) -> AppFilter? {
        let normalizedRouteID = routeID.normalizedFilterLookupKey
        if let uuid = UUID(uuidString: routeID),
           let filter = filters.first(where: { $0.id == uuid }) {
            return filter
        }
        if let exact = filters.first(where: { $0.title.normalizedFilterLookupKey == normalizedRouteID }) {
            return exact
        }
        if let partial = filters.first(where: { filter in
            let key = filter.title.normalizedFilterLookupKey
            return normalizedRouteID.contains(key) || key.contains(normalizedRouteID)
        }) {
            return partial
        }
        let routeTokens = normalizedRouteID.split(separator: " ")
        return filters.first { filter in
            let titleTokens = Set(filter.title.normalizedFilterLookupKey.split(separator: " "))
            return routeTokens.contains { titleTokens.contains($0) }
        }
    }
}

struct FilterLibraryRemovalSnapshot {
    let filterID: AppFilter.ID
    let hadDownload: Bool
    let hadFavorite: Bool
}

private extension String {
    var normalizedFilterLookupKey: String {
        lowercased()
            .replacingOccurrences(of: "@", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
