import Foundation
import Models
import Testing
@testable import moodit

@MainActor
@Suite("Editor draft store")
struct EditorDraftStoreTests {
    @Test("draft mutations normalize tags and reset editor state")
    func draftMutationsNormalizeAndResetState() {
        let store = EditorDraftStore()
        let signatureData = Data([0x01, 0x02, 0x03])
        var callbackCount = 0
        store.onEditorDraftChanged = { _ in callbackCount += 1 }

        store.updateEditorParameter("exposure", value: 0.5)
        store.setEditorLUT("look.cube")
        store.addUploadCover()
        store.addUploadCover()
        store.addUploadTag(" #warm ")
        store.addUploadTag("warm")
        store.setUploadCategory(.food)
        store.setUploadSignatureSampleData(signatureData)

        #expect(store.editorDraft.parameterValues["exposure"] == 0.5)
        #expect(store.editorPreviewParameters.exposure == 1.0)
        #expect(store.editorDraft.lutFileName == "look.cube")
        #expect(store.editorImportedLUTRevision == 1)
        #expect(store.editorDraft.coverCount == 2)
        #expect(store.editorDraft.tags == ["warm"])
        #expect(store.editorDraft.category == .food)
        #expect(store.editorDraft.signatureSamplePhotoData == signatureData)
        #expect(store.editorDraft.signatureSampleKind == nil)
        #expect(callbackCount > 0)

        store.resetEditorDraft()

        #expect(store.editorDraft == .empty)
        #expect(store.editorImportedLUT == nil)
        #expect(store.editorImportedLUTRevision == 0)
        #expect(store.uploadStep == .cover)
    }

    @Test("submit moves draft to pending and upserts maker filter")
    func submitMovesDraftToPending() {
        let store = EditorDraftStore()
        store.updateEditorDraft { draft in
            draft.name = "Amber"
            draft.summary = "Warm look"
            draft.tosOriginal = true
            draft.tosPolicy = true
            draft.tosCommercial = true
        }

        let submitted = store.submitCurrentDraft()

        #expect(submitted.status == .pending)
        #expect(submitted.submittedAt != nil)
        #expect(store.uploadStep == .pending)
        #expect(store.makerFilters.count == 1)
        #expect(store.makerFilters.first?.status == .pending)
    }

    @Test("reference sample and user scoped reset clear maker state")
    func referenceAndUserScopedReset() {
        let store = EditorDraftStore()
        store.setEditorReferencePhotoData(Data([0x0A]))
        store.setEditorReferenceSampleKind(.indoor)
        store.addUploadTag("reset")
        store.selectedMakerStatus = .live
        _ = store.saveEditorDraft()

        #expect(store.editorReferencePhotoData == nil)
        #expect(store.editorReferenceSampleKind == .indoor)
        #expect(store.editorReferencePhotoRevision == 2)
        #expect(!store.makerFilters.isEmpty)

        store.resetUserScopedState()

        #expect(store.editorDraft == .empty)
        #expect(store.editorReferencePhotoData == nil)
        #expect(store.editorReferenceSampleKind == .portrait)
        #expect(store.editorReferencePhotoRevision == 0)
        #expect(store.selectedMakerStatus == .all)
        #expect(store.makerFilters.isEmpty)
    }
}
