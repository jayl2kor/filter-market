import Foundation
import Marketplace
import Models
import Testing
@testable import moodit

@MainActor
@Suite("Filter library store")
struct FilterLibraryStoreTests {
    @Test("load derives selected, downloaded, trending, and new filters")
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
        #expect(store.selectedFilterID == older.id)
        #expect(store.downloadedFilterIDs == [older.id])
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
        #expect(store.selectedFilterID == first.id)

        store.restore(snapshot)
        store.rollbackFavorite(second, shouldSave: shouldSave)

        #expect(store.isDownloaded(second))
        #expect(!store.isFavorite(second))
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
            status: .approved
        )
    }
}
