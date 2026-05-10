import Foundation
import Marketplace
import Models
import Testing
@testable import moodit

@MainActor
@Suite("Filter library store")
struct FilterLibraryStoreTests {
    @Test("load derives selected, trending, and new filters without default download")
    func loadDerivesLibraryState() async {
        let older = makeFilter(
            id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4A01",
            title: "Older",
            useCount: 20,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newer = makeFilter(
            id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4A02",
            title: "Newer",
            useCount: 40,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let store = FilterLibraryStore(repository: MockFilterRepository(filters: [older, newer]))

        await store.load()

        #expect(store.filters.map(\.title) == ["Older", "Newer"])
        #expect(store.selectedFilterID == nil)
        #expect(store.selectedFilter == nil)
        #expect(store.downloadedFilterIDs.isEmpty)
        #expect(store.trendingFilters.map(\.title) == ["Newer", "Older"])
        #expect(store.newFiltersList.map(\.title) == ["Newer", "Older"])
        #expect(store.loadError == nil)
        #expect(!store.isLoading)
    }

    @Test("download removal and favorite rollback restore prior state")
    func removalAndFavoriteRollbackRestoreState() async {
        let first = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4B01", title: "First")
        let second = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4B02", title: "Second")
        let store = FilterLibraryStore(repository: MockFilterRepository(filters: [first, second]))
        await store.load()
        store.markDownloaded(second.id)
        store.select(second)
        let shouldSave = store.toggleFavorite(second)

        #expect(shouldSave)
        #expect(store.isFavorite(second))
        #expect(store.selectedFilterID == second.id)

        let snapshot = store.removeDownload(second)

        #expect(!store.isDownloaded(second))
        #expect(!store.isFavorite(second))
        #expect(store.selectedFilterID == nil)

        store.restore(snapshot)
        store.rollbackFavorite(second, shouldSave: shouldSave)

        #expect(store.isDownloaded(second))
        #expect(!store.isFavorite(second))
    }

    @Test("force reload preserves selected, downloaded, and favorite state")
    func forceReloadPreservesUserState() async {
        let first = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4D01", title: "First")
        let second = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4D02", title: "Second")
        let third = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4D03", title: "Third")
        let repository = MutableFilterRepository(filters: [first, second])
        let store = FilterLibraryStore(repository: repository)

        await store.load()
        store.select(second)
        store.markDownloaded(second.id)
        _ = store.toggleFavorite(second)
        await repository.setFilters([third, second, first])

        await store.load(force: true)

        #expect(store.filters.map(\.id) == [third.id, second.id, first.id])
        #expect(store.selectedFilterID == second.id)
        #expect(store.downloadedFilterIDs == [second.id])
        #expect(store.favoriteFilterIDs == [second.id])
    }

    @Test("load does not seed downloads and select does not mark downloaded")
    func loadAndSelectDoNotMarkDownloads() async {
        let first = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4E01", title: "First")
        let second = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4E02", title: "Second")
        let store = FilterLibraryStore(repository: MockFilterRepository(filters: [first, second]))

        await store.load()
        store.select(second)

        await store.load(force: true)

        #expect(store.downloadedFilterIDs.isEmpty)
        #expect(store.selectedFilterID == second.id)
    }

    @Test("empty download state never exposes an implicit selected filter")
    func emptyDownloadStateHasNoImplicitSelectedFilter() async {
        let first = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4F01", title: "First")
        let second = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4F02", title: "Second")
        let store = FilterLibraryStore(repository: MockFilterRepository(filters: [first, second]))

        await store.load()

        #expect(store.downloadedFilterIDs.isEmpty)
        #expect(store.selectedFilterID == nil)
        #expect(store.selectedFilter == nil)

        store.markDownloaded(second.id)
        await store.load(force: true)

        #expect(store.selectedFilterID == second.id)
        #expect(store.selectedFilter?.id == second.id)
    }

    @Test("download records the server-side download counter after saving")
    func downloadRecordsServerCounter() async throws {
        let filter = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4A11", title: "Counter")
        let recorder = DownloadRecordSpy()
        let store = FilterLibraryStore(
            repository: MockFilterRepository(filters: [filter]),
            recordDownload: { filterID in
                await recorder.record(filterID)
            }
        )
        await store.load()

        try await store.download(filter)

        #expect(store.isDownloaded(filter))
        #expect(await recorder.recordedFilterIDs() == [filter.id.uuidString])
    }

    @Test("market tile download count does not fall back to use count")
    func tileMappingUsesOnlyDownloadCount() {
        let filter = makeFilter(
            id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4A12",
            title: "Used Often",
            useCount: 9_100,
            downloadCount: 0
        )

        #expect(filter.toTileData().downloadCount == 0)
    }

    @Test("route lookup supports uuid, normalized title, and partial tokens")
    func routeLookupUsesNormalizedKeys() async {
        let filter = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E4C01", title: "Seoul-Night")
        let store = FilterLibraryStore(repository: MockFilterRepository(filters: [filter]))
        await store.load()

        #expect(store.filter(matching: filter.id.uuidString)?.id == filter.id)
        #expect(store.filter(matching: "seoul night")?.id == filter.id)
        #expect(store.filter(matching: "@seoul_night_filter")?.id == filter.id)
    }

    private func makeFilter(
        id: String,
        title: String,
        useCount: Int = 0,
        downloadCount: Int = 0,
        createdAt: Date? = nil
    ) -> AppFilter {
        AppFilter(
            id: UUID(uuidString: id)!,
            title: title,
            version: "1.0.0",
            author: FilterAuthor(uid: "maker", displayName: "Maker"),
            category: .cinematic,
            engine: FilterEngineDescriptor(
                type: .lutParams,
                minAppVersion: "1.0.0",
                minIOSVersion: "17.0",
                lutSize: 33,
                lutFile: nil
            ),
            useCount: useCount,
            createdAt: createdAt,
            status: .approved,
            downloadCount: downloadCount
        )
    }
}

private actor DownloadRecordSpy {
    private var ids: [String] = []

    func record(_ id: String) {
        ids.append(id)
    }

    func recordedFilterIDs() -> [String] {
        ids
    }
}

private actor MutableFilterRepository: FilterRepository {
    private var filters: [AppFilter]

    init(filters: [AppFilter]) {
        self.filters = filters
    }

    func setFilters(_ filters: [AppFilter]) {
        self.filters = filters
    }

    func listFilters() async throws -> [AppFilter] {
        filters
    }

    func filter(id: AppFilter.ID) async throws -> AppFilter {
        guard let filter = filters.first(where: { $0.id == id }) else {
            throw MockFilterRepositoryError.notFound
        }
        return filter
    }
}
