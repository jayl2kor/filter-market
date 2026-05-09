import Combine
import Foundation
import FilterEngine
import Models

@MainActor
final class EditorDraftStore: ObservableObject {
    @Published var editorReferencePhotoData: Data?
    @Published var editorReferencePhotoRevision = 0
    @Published var editorReferenceSampleKind: EditorReferenceSampleKind = .portrait
    @Published var editorDraft = MakerFilterDraft.empty {
        didSet {
            onEditorDraftChanged?(editorDraft)
        }
    }
    @Published var editorImportedLUT: LUT3D?
    @Published var editorImportedLUTRevision = 0
    @Published var uploadStep: UploadStep = .cover
    @Published var selectedMakerStatus: MakerFilterStatus = .all
    @Published var makerFilters: [MakerFilterDraft] = []

    var onEditorDraftChanged: ((MakerFilterDraft) -> Void)?

    func resetUserScopedState() {
        editorReferencePhotoData = nil
        editorReferencePhotoRevision = 0
        editorReferenceSampleKind = .portrait
        editorImportedLUT = nil
        editorImportedLUTRevision = 0
        editorDraft = MakerFilterDraft.empty
        uploadStep = .cover
        selectedMakerStatus = .all
        makerFilters = []
    }

    func setEditorReferencePhotoData(_ data: Data?) {
        editorReferencePhotoData = data
        editorReferencePhotoRevision += 1
    }

    func setEditorReferenceSampleKind(_ kind: EditorReferenceSampleKind) {
        editorReferenceSampleKind = kind
        if editorReferencePhotoData != nil {
            editorReferencePhotoData = nil
            editorReferencePhotoRevision += 1
        }
    }

    func resetEditorDraft() {
        editorReferencePhotoData = nil
        editorReferencePhotoRevision = 0
        editorReferenceSampleKind = .portrait
        editorImportedLUT = nil
        editorImportedLUTRevision = 0
        editorDraft = MakerFilterDraft.empty
        uploadStep = .cover
    }

    func updateEditorDraft(
        _ mutate: (inout MakerFilterDraft) -> Void,
        touchUpdatedAt: Bool = true
    ) {
        var draft = editorDraft
        mutate(&draft)
        if touchUpdatedAt {
            draft.updatedAt = Date()
        }
        editorDraft = draft
    }

    func updateEditorParameter(_ key: String, value: Double) {
        updateEditorDraft { draft in
            draft.parameterValues[key] = value
        }
    }

    func setEditorLUT(_ fileName: String, lut: LUT3D? = nil) {
        editorImportedLUT = lut
        editorImportedLUTRevision += 1
        updateEditorDraft { draft in
            draft.lutFileName = fileName
        }
    }

    var editorPreviewParameters: EditorParameters {
        EditorParameters(
            exposure: Float(editorDraft.parameterValues["exposure"] ?? 0) * 2,
            contrast: Float(editorDraft.parameterValues["contrast"] ?? 0),
            saturation: Float(editorDraft.parameterValues["saturation"] ?? 0),
            tint: 0
        )
    }

    var editorPreviewGrain: Float {
        max(0, Float(editorDraft.parameterValues["grain"] ?? 0))
    }

    var editorPreviewVignette: Float {
        Float(editorDraft.parameterValues["vignette"] ?? 0)
    }

    func saveEditorDraft() -> MakerFilterDraft {
        updateEditorDraft { draft in
            draft.status = .draft
        }
        upsertMakerFilter(editorDraft)
        return editorDraft
    }

    func saveCurrentUploadDraftIfNeeded() -> MakerFilterDraft? {
        guard editorDraft.hasUserContent, editorDraft.status != .pending else { return nil }
        return saveEditorDraft()
    }

    func addUploadCover() {
        updateEditorDraft { draft in
            draft.coverCount = min(6, draft.coverCount + 1)
        }
    }

    func removeUploadCover() {
        updateEditorDraft { draft in
            draft.coverCount = max(0, draft.coverCount - 1)
        }
    }

    func setUploadSignatureSampleKind(_ kind: EditorReferenceSampleKind) {
        updateEditorDraft { draft in
            draft.signatureSampleKind = kind
            draft.signatureSamplePhotoData = nil
        }
    }

    func setUploadSignatureSampleData(_ data: Data?) {
        updateEditorDraft { draft in
            draft.signatureSamplePhotoData = data
            if data != nil {
                draft.signatureSampleKind = nil
            }
        }
    }

    func clearUploadSignatureSample() {
        updateEditorDraft { draft in
            draft.signatureSampleKind = nil
            draft.signatureSamplePhotoData = nil
        }
    }

    func addUploadTag(_ tag: String) {
        let normalized = tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard !normalized.isEmpty, !editorDraft.tags.contains(normalized) else { return }
        updateEditorDraft { draft in
            draft.tags.append(normalized)
        }
    }

    func removeUploadTag(_ tag: String) {
        updateEditorDraft { draft in
            draft.tags.removeAll { $0 == tag }
        }
    }

    func setUploadCategory(_ category: FilterCategory) {
        updateEditorDraft { draft in
            draft.category = category
        }
    }

    func submitCurrentDraft() -> MakerFilterDraft {
        updateEditorDraft { draft in
            draft.status = .pending
            draft.submittedAt = Date()
        }
        uploadStep = .pending
        upsertMakerFilter(editorDraft)
        return editorDraft
    }

    func startEditing(_ draft: MakerFilterDraft) {
        editorDraft = draft
        uploadStep = .cover
    }

    func setMakerFilters(_ drafts: [MakerFilterDraft]) {
        makerFilters = drafts
    }

    func markMakerFilterPrivate(_ draft: MakerFilterDraft) -> MakerFilterDraft? {
        guard let existing = makerFilters.first(where: { $0.id == draft.id }) else { return nil }
        var updatedDraft = existing
        updatedDraft.status = .draft
        updatedDraft.updatedAt = Date()
        makerFilters = makerFilters.map { $0.id == draft.id ? updatedDraft : $0 }
        return updatedDraft
    }

    private func upsertMakerFilter(_ draft: MakerFilterDraft) {
        if makerFilters.contains(where: { $0.id == draft.id }) {
            makerFilters = makerFilters.map { $0.id == draft.id ? draft : $0 }
        } else {
            makerFilters.insert(draft, at: 0)
        }
    }
}
