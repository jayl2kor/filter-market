import Foundation
import Marketplace
import Models

@MainActor
final class MooditStore: ObservableObject {
    @Published private(set) var filters: [Filter] = []
    @Published private(set) var downloadedFilterIDs: Set<Filter.ID> = []
    @Published var selectedFilterID: Filter.ID?
    /// manifest 로드 실패 시 마지막 에러. UI 는 이 값을 보고 ErrorBanner / FMEmptyState 를 노출.
    @Published private(set) var loadError: Error?
    /// 로드 진행 상태. skeleton vs 에러 vs 빈 상태 분기에 사용.
    @Published private(set) var isLoading = false

    private let repository: any FilterRepository

    init(repository: any FilterRepository = BundleSeedFilterRepository()) {
        self.repository = repository
    }

    var selectedFilter: Filter? {
        guard let selectedFilterID else { return filters.first }
        return filters.first { $0.id == selectedFilterID }
    }

    var libraryFilters: [Filter] {
        filters.filter { downloadedFilterIDs.contains($0.id) }
    }

    func load() async {
        // 이미 정상 로드된 상태면 재호출 무시. 실패 후 retry 는 통과시킨다.
        guard filters.isEmpty else { return }

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
        } catch {
            loadError = error
            filters = []
        }
    }

    /// 로드 실패 후 사용자가 재시도. 직전 에러를 비우고 `load()` 를 재실행한다.
    func retry() async {
        loadError = nil
        await load()
    }

    func select(_ filter: Filter) {
        selectedFilterID = filter.id
        downloadedFilterIDs.insert(filter.id)
    }

    func download(_ filter: Filter) {
        downloadedFilterIDs.insert(filter.id)
    }

    func isDownloaded(_ filter: Filter) -> Bool {
        downloadedFilterIDs.contains(filter.id)
    }
}
