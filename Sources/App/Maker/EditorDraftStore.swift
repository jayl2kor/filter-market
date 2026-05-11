import Combine
import Foundation
import FirebaseFirestore
import FirebaseFunctions
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
    @Published private(set) var lastSubmitErrorMessage: String?

    var onEditorDraftChanged: ((MakerFilterDraft) -> Void)?

    func resetUserScopedState() {
        resetEditorDraft()
        selectedMakerStatus = .all
        makerFilters = []
        lastSubmitErrorMessage = nil
    }

    func clearLastSubmitError() {
        lastSubmitErrorMessage = nil
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

    @discardableResult
    func saveEditorDraft() -> MakerFilterDraft {
        updateEditorDraft { draft in
            draft.status = .draft
        }
        upsertMakerFilter(editorDraft)
        persistMakerDraft(editorDraft)
        return editorDraft
    }

    @discardableResult
    func saveCurrentUploadDraftIfNeeded() -> MakerFilterDraft? {
        guard editorDraft.hasUserContent, editorDraft.status != .pending else { return nil }
        return saveEditorDraft()
    }

    func addUploadCover() {
        updateEditorDraft { draft in
            draft.coverCount = 1
        }
    }

    func removeUploadCover() {
        updateEditorDraft { draft in
            draft.coverCount = max(0, draft.coverCount - 1)
            if draft.coverCount == 0 {
                draft.coverPhotoData = nil
            }
        }
    }

    func setUploadCoverPhotoData(_ data: Data?) {
        updateEditorDraft { draft in
            draft.coverPhotoData = data
            draft.coverCount = data == nil ? 0 : 1
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

    @discardableResult
    func submitCurrentDraft() -> MakerFilterDraft {
        updateEditorDraft { draft in
            draft.status = .pending
            draft.submittedAt = Date()
        }
        uploadStep = .pending
        upsertMakerFilter(editorDraft)
        persistMakerDraft(editorDraft)
        submitForReviewIfNeeded(editorDraft)
        return editorDraft
    }

    func startEditing(_ draft: MakerFilterDraft) {
        editorDraft = normalizedDraft(draft)
        uploadStep = .cover
    }

    func setMakerFilters(_ drafts: [MakerFilterDraft]) {
        makerFilters = drafts.map(normalizedDraft)
    }

    func makerFilter(matchingRejectionRouteID routeID: String) -> MakerFilterDraft? {
        let normalized = routeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        if let uuid = UUID(uuidString: normalized),
           let match = makerFilters.first(where: { $0.id == uuid }) {
            return match
        }
        if let match = makerFilters.first(where: { $0.firestoreFilterId == normalized }) {
            return match
        }
        return makerFilters.first { $0.name == normalized }
    }

    @discardableResult
    func markMakerFilterPrivate(_ draft: MakerFilterDraft) -> MakerFilterDraft? {
        guard let existing = makerFilters.first(where: { $0.id == draft.id }) else { return nil }
        var updatedDraft = existing
        updatedDraft.status = .draft
        updatedDraft.updatedAt = Date()
        makerFilters = makerFilters.map { $0.id == draft.id ? updatedDraft : $0 }
        persistMakerDraft(updatedDraft)
        return updatedDraft
    }

    private func upsertMakerFilter(_ draft: MakerFilterDraft) {
        let draft = normalizedDraft(draft)
        if makerFilters.contains(where: { $0.id == draft.id }) {
            makerFilters = makerFilters.map { $0.id == draft.id ? draft : $0 }
        } else {
            makerFilters.insert(draft, at: 0)
        }
    }

    private func normalizedDraft(_ draft: MakerFilterDraft) -> MakerFilterDraft {
        var draft = draft
        draft.coverCount = min(1, max(0, draft.coverCount))
        if draft.coverCount == 0 {
            draft.coverPhotoData = nil
        }
        return draft
    }

    private func persistMakerDraft(_ draft: MakerFilterDraft) {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = SessionStore.currentFirebaseUID else { return }
        var payload: [String: Any] = [
            "name": draft.name,
            "summary": draft.summary,
            "category": draft.category.rawValue,
            "tags": draft.tags,
            "parameterValues": draft.parameterValues,
            "coverCount": draft.coverCount,
            "beforeAfterEnabled": draft.beforeAfterEnabled,
            "tosOriginal": draft.tosOriginal,
            "tosPolicy": draft.tosPolicy,
            "tosCommercial": draft.tosCommercial,
            "status": draft.status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let lutFileName = draft.lutFileName {
            payload["lutFileName"] = lutFileName
        }
        if let signatureSampleKind = draft.signatureSampleKind {
            payload["signatureSampleKind"] = signatureSampleKind.rawValue
        }
        if let submittedAt = draft.submittedAt {
            payload["submittedAt"] = Timestamp(date: submittedAt)
        }
        if let rejectionReasons = draft.rejectionReasons, !rejectionReasons.isEmpty {
            payload["rejectionReasons"] = rejectionReasons.map { ["title": $0.title, "body": $0.body] }
        }
        if let moderatorNote = draft.moderatorNote {
            payload["moderatorNote"] = moderatorNote
        }
        if let rejectedAt = draft.rejectedAt {
            payload["rejectedAt"] = Timestamp(date: rejectedAt)
        }
        if let firestoreFilterId = draft.firestoreFilterId {
            payload["firestoreFilterId"] = firestoreFilterId
        }
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("makerDrafts").document(draft.id.uuidString)
            .setData(payload, merge: true) { [weak self] error in
                guard let error else { return }
                Task { @MainActor in
                    self?.lastSubmitErrorMessage = "메이커 초안 저장 실패: \(FirestoreErrorMapper.friendlyMessage(for: error))"
                }
            }
    }

    private func submitForReviewIfNeeded(_ draft: MakerFilterDraft) {
        guard let fsId = draft.firestoreFilterId else { return }
        let payload: [String: Any] = [
            "filterId": fsId,
            "tosOriginal": draft.tosOriginal,
            "tosPolicy": draft.tosPolicy,
            "tosCommercial": draft.tosCommercial,
        ]
        Task { [weak self] in
            do {
                _ = try await Functions.functions(region: "asia-northeast3")
                    .httpsCallable("submitForReview")
                    .call(payload)
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastSubmitErrorMessage = "검수 제출 실패: \(FirestoreErrorMapper.friendlyMessage(for: error))"
                }
            }
        }
    }
}
