import Marketplace
import Models
import XCTest
@testable import moodit

@MainActor
final class MooditStoreTests: XCTestCase {
    func testLoadPopulatesFilterStateAndDerivedLists() async {
        let older = makeFilter(
            id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3A01",
            title: "Older",
            useCount: 20,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newer = makeFilter(
            id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3A02",
            title: "Newer",
            useCount: 40,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let rejected = makeFilter(
            id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3A03",
            title: "Rejected",
            useCount: 100,
            status: .rejected,
            createdAt: Date(timeIntervalSince1970: 300)
        )
        let store = MooditStore(repository: MockFilterRepository(filters: [older, newer, rejected]))

        await store.load()

        XCTAssertEqual(store.filters.map(\.title), ["Older", "Newer", "Rejected"])
        XCTAssertNil(store.selectedFilterID)
        XCTAssertNil(store.selectedFilter)
        XCTAssertTrue(store.downloadedFilterIDs.isEmpty)
        XCTAssertEqual(store.trendingFilters.map(\.title), ["Newer", "Older"])
        XCTAssertEqual(store.newFiltersList.map(\.title), ["Newer", "Older"])
        XCTAssertNil(store.loadError)
        XCTAssertFalse(store.isLoading)
    }

    func testDownloadFavoriteAndRemoveDoNotRequireFirebaseApp() async throws {
        let first = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3B01", title: "First")
        let second = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3B02", title: "Second")
        let store = MooditStore(repository: MockFilterRepository(filters: [first, second]))
        await store.load()

        try await store.download(second)
        store.select(second)
        store.toggleFavorite(second)

        XCTAssertTrue(store.isDownloaded(second))
        XCTAssertTrue(store.isFavorite(second))
        XCTAssertEqual(store.selectedFilterID, second.id)

        store.removeDownload(second)

        XCTAssertFalse(store.isDownloaded(second))
        XCTAssertFalse(store.isFavorite(second))
        XCTAssertNil(store.selectedFilterID)
    }

    func testEditorDraftMutationsNormalizeAndResetState() {
        let store = MooditStore(repository: MockFilterRepository(filters: []))
        let signatureData = Data([0x01, 0x02, 0x03])

        store.updateEditorParameter("exposure", value: 0.5)
        store.setEditorLUT("look.cube")
        store.addUploadCover()
        store.addUploadCover()
        store.addUploadTag(" #warm ")
        store.addUploadTag("warm")
        store.setUploadCategory(.food)
        store.setUploadSignatureSampleData(signatureData)

        XCTAssertEqual(store.editorDraft.parameterValues["exposure"], 0.5)
        XCTAssertEqual(store.editorPreviewParameters.exposure, 1.0)
        XCTAssertEqual(store.editorDraft.lutFileName, "look.cube")
        XCTAssertEqual(store.editorImportedLUTRevision, 1)
        XCTAssertEqual(store.editorDraft.coverCount, 1)
        XCTAssertEqual(store.editorDraft.tags, ["warm"])
        XCTAssertEqual(store.editorDraft.category, .food)
        XCTAssertEqual(store.editorDraft.signatureSamplePhotoData, signatureData)
        XCTAssertNil(store.editorDraft.signatureSampleKind)

        store.resetEditorDraft()

        XCTAssertEqual(store.editorDraft, .empty)
        XCTAssertNil(store.editorImportedLUT)
        XCTAssertEqual(store.editorImportedLUTRevision, 0)
        XCTAssertEqual(store.uploadStep, .cover)
    }

    func testSubmitDraftMovesToPendingAndUpsertsMakerFilter() {
        let store = MooditStore(repository: MockFilterRepository(filters: []))
        store.editorDraft.name = "Amber"
        store.editorDraft.summary = "Warm look"
        store.editorDraft.tosOriginal = true
        store.editorDraft.tosPolicy = true
        store.editorDraft.tosCommercial = true

        store.submitCurrentDraft()

        XCTAssertEqual(store.editorDraft.status, .pending)
        XCTAssertNotNil(store.editorDraft.submittedAt)
        XCTAssertEqual(store.uploadStep, .pending)
        XCTAssertEqual(store.makerFilters.count, 1)
        XCTAssertEqual(store.makerFilters.first?.status, .pending)
    }

    func testResetUserScopedStateClearsUserData() async throws {
        let filter = makeFilter(id: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3C01", title: "Reset")
        let store = MooditStore(repository: MockFilterRepository(filters: [filter]))
        await store.load()
        try await store.download(filter)
        store.toggleFavorite(filter)
        store.filterLibraryStore.setLikedFilterIDs([filter.id.uuidString])
        store.creditCoinsOptimistically(500)
        store.markProActiveOptimistically()
        store.setImportedPhotoData(Data([0x0A]))
        store.addUploadTag("reset")
        store.requestDataExport()

        store.resetUserScopedState()

        XCTAssertEqual(store.coinBalance, 0)
        XCTAssertFalse(store.isProActive)
        XCTAssertTrue(store.downloadedFilterIDs.isEmpty)
        XCTAssertTrue(store.favoriteFilterIDs.isEmpty)
        XCTAssertTrue(store.likedFilterIDs.isEmpty)
        XCTAssertNil(store.importedPhotoData)
        XCTAssertEqual(store.editorDraft, .empty)
        XCTAssertTrue(store.makerFilters.isEmpty)
        XCTAssertTrue(store.exportRequests.isEmpty)
        XCTAssertNil(store.selectedFilterID)
        XCTAssertNil(store.lastSubmitErrorMessage)
    }

    private func makeFilter(
        id: String,
        title: String,
        useCount: Int = 0,
        status: FilterStatus = .approved,
        createdAt: Date? = nil
    ) -> Filter {
        Filter(
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
            status: status
        )
    }
}
