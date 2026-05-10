import Foundation
import FirebaseFirestore
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
    @Published private(set) var lastSyncErrorMessage: String?

    private let repository: any FilterRepository
    private let recordDownload: @Sendable (String) async throws -> Void

    init(
        repository: any FilterRepository = BundleSeedFilterRepository(),
        recordDownload: @escaping @Sendable (String) async throws -> Void = FilterLibraryStore.defaultRecordDownload
    ) {
        self.repository = repository
        self.recordDownload = recordDownload
    }

    var selectedFilter: AppFilter? {
        guard let selectedFilterID else { return nil }
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
            applyLoadedFilters(loadedFilters)
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
        lastSyncErrorMessage = nil
    }

    func clearLastSyncError() {
        lastSyncErrorMessage = nil
    }

    func setDownloadedFilterIDs(_ ids: Set<AppFilter.ID>) {
        downloadedFilterIDs = ids
    }

    func setFavoriteFilterIDs(_ ids: Set<AppFilter.ID>) {
        favoriteFilterIDs = ids
    }

    func select(_ filter: AppFilter) {
        selectedFilterID = filter.id
    }

    func markDownloaded(_ id: AppFilter.ID) {
        downloadedFilterIDs.insert(id)
    }

    func download(_ filter: AppFilter) async throws {
        try await persistSavedFilter(filterID: filter.id, save: true)
        try await recordDownload(filter.id.uuidString)
        markDownloaded(filter.id)
    }

    func download(filterID: String) async throws {
        guard let id = UUID(uuidString: filterID) else { return }
        try await persistSavedFilter(filterID: id, save: true)
        try await recordDownload(id.uuidString)
        markDownloaded(id)
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
            selectedFilterID = libraryFilters.first?.id
        }
        return snapshot
    }

    func removeDownloadAndPersist(_ filter: AppFilter) {
        let snapshot = removeDownload(filter)
        Task { [weak self] in
            do {
                try await self?.persistSavedFilter(filterID: filter.id, save: false)
                try await self?.persistFavorite(filterID: filter.id, save: false)
            } catch {
                await MainActor.run { [weak self] in
                    self?.restore(snapshot)
                    self?.lastSyncErrorMessage = "저장 상태 동기화 실패: \(error.localizedDescription)"
                }
            }
        }
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

    func toggleFavoriteAndPersist(_ filter: AppFilter) {
        let shouldSave = toggleFavorite(filter)
        Task { [weak self] in
            do {
                try await self?.persistFavorite(filterID: filter.id, save: shouldSave)
            } catch {
                await MainActor.run { [weak self] in
                    self?.rollbackFavorite(filter, shouldSave: shouldSave)
                    self?.lastSyncErrorMessage = "즐겨찾기 동기화 실패: \(error.localizedDescription)"
                }
            }
        }
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

    private func persistSavedFilter(filterID: AppFilter.ID, save: Bool) async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = SessionStore.currentFirebaseUID else { return }
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("savedFilters").document(filterID.uuidString)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if save {
                ref.setData([
                    "filterId": filterID.uuidString,
                    "savedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } else {
                ref.delete { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    private static func defaultRecordDownload(filterID: String) async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard SessionStore.currentFirebaseUID != nil else { return }
        _ = try await FirebaseSideEffects.callFunction(
            "recordDownload",
            data: ["filterId": filterID]
        )
    }

    private func applyLoadedFilters(_ loadedFilters: [AppFilter]) {
        let previousSelectedFilterID = selectedFilterID

        filters = loadedFilters

        if let previousSelectedFilterID,
           loadedFilters.contains(where: { $0.id == previousSelectedFilterID }) {
            selectedFilterID = previousSelectedFilterID
        } else if let firstDownloadedFilter = loadedFilters.first(where: { downloadedFilterIDs.contains($0.id) }) {
            selectedFilterID = firstDownloadedFilter.id
        } else {
            selectedFilterID = nil
        }
    }

    private func persistFavorite(filterID: AppFilter.ID, save: Bool) async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = SessionStore.currentFirebaseUID else { return }
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("favorites").document(filterID.uuidString)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if save {
                ref.setData([
                    "filterId": filterID.uuidString,
                    "favoritedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } else {
                ref.delete { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
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
