import Combine
import FirebaseFirestore
import Foundation
import FilterEngine
import Marketplace
import Models

// Disambiguate from FirebaseFirestore.Filter (which is bridged from FIRFilter).
typealias Filter = Models.Filter

@MainActor
final class MooditStore: ObservableObject {
    let filterLibraryStore: FilterLibraryStore
    let walletStore: WalletStore
    let editorDraftStore: EditorDraftStore
    let sessionStore: SessionStore
    let cameraStateStore: CameraStateStore
    var filters: [Filter] { filterLibraryStore.filters }
    var downloadedFilterIDs: Set<Filter.ID> { filterLibraryStore.downloadedFilterIDs }
    var favoriteFilterIDs: Set<Filter.ID> { filterLibraryStore.favoriteFilterIDs }
    var likedFilterIDs: Set<String> { filterLibraryStore.likedFilterIDs }
    var selectedFilterID: Filter.ID? {
        get { filterLibraryStore.selectedFilterID }
        set { filterLibraryStore.selectedFilterID = newValue }
    }
    var cameraAspectRatio: PhotoCropAspectRatio {
        get { cameraStateStore.aspectRatio }
        set { cameraStateStore.aspectRatio = newValue }
    }
    var cameraTimerOption: CameraTimerOption {
        get { cameraStateStore.timerOption }
        set { cameraStateStore.timerOption = newValue }
    }
    var cameraGridEnabled: Bool {
        get { cameraStateStore.gridEnabled }
        set { cameraStateStore.gridEnabled = newValue }
    }
    var cameraFlashMode: CameraFlashMode {
        get { cameraStateStore.flashMode }
        set { cameraStateStore.flashMode = newValue }
    }
    var cameraZoomPreset: Double {
        get { cameraStateStore.zoomPreset }
        set { cameraStateStore.zoomPreset = newValue }
    }
    var importedPhotoData: Data? { cameraStateStore.importedPhotoData }
    var editorReferencePhotoData: Data? { editorDraftStore.editorReferencePhotoData }
    var editorReferencePhotoRevision: Int { editorDraftStore.editorReferencePhotoRevision }
    var editorReferenceSampleKind: EditorReferenceSampleKind { editorDraftStore.editorReferenceSampleKind }
    var editableProfile: EditableProfile {
        get { sessionStore.editableProfile }
        set { sessionStore.editableProfile = newValue }
    }
    var lastProfileSavedAt: Date? { sessionStore.lastProfileSavedAt }
    var accountDeletionRequestedAt: Date? { sessionStore.accountDeletionRequestedAt }
    var selectedExportCategories: Set<DataExportCategory> {
        get { sessionStore.selectedExportCategories }
        set { sessionStore.selectedExportCategories = newValue }
    }
    var selectedExportFormat: DataExportFormat {
        get { sessionStore.selectedExportFormat }
        set { sessionStore.selectedExportFormat = newValue }
    }
    var exportRequests: [DataExportRequest] { sessionStore.exportRequests }
    var notificationPreferences: NotificationPreferences { sessionStore.notificationPreferences }
    var editorDraft: MakerFilterDraft {
        get { editorDraftStore.editorDraft }
        set { editorDraftStore.editorDraft = newValue }
    }
    var editorImportedLUT: LUT3D? { editorDraftStore.editorImportedLUT }
    var editorImportedLUTRevision: Int { editorDraftStore.editorImportedLUTRevision }
    var uploadStep: UploadStep {
        get { editorDraftStore.uploadStep }
        set { editorDraftStore.uploadStep = newValue }
    }
    var selectedMakerStatus: MakerFilterStatus {
        get { editorDraftStore.selectedMakerStatus }
        set { editorDraftStore.selectedMakerStatus = newValue }
    }
    /// 메이커 본인의 드래프트/검수/공개 필터 — 진짜 데이터는 Firestore /filters where authorUid==uid에서 들어옴.
    /// 사용자가 처음 진입하면 빈 배열 → FMEmptyState 노출. 이후 createDraft / submitDraft 흐름으로 채워짐.
    /// (이전: 4개 하드코딩 mock 잔재 — 사용자 본인이 만들지 않은 필터가 노출되는 문제 해결)
    var makerFilters: [MakerFilterDraft] {
        get { editorDraftStore.makerFilters }
        set { editorDraftStore.makerFilters = newValue }
    }
    /// manifest 로드 실패 시 마지막 에러. UI 는 이 값을 보고 ErrorBanner / FMEmptyState 를 노출.
    var loadError: FriendlyError? { filterLibraryStore.loadError }
    /// 로드 진행 상태. skeleton vs 에러 vs 빈 상태 분기에 사용.
    var isLoading: Bool { filterLibraryStore.isLoading }
    /// 마켓 트렌딩 — useCount 내림차순. 비어 있으면 FMEmptyState.
    var trendingFilters: [Filter] { filterLibraryStore.trendingFilters }
    /// 마켓 신규 — createdAt 내림차순. 비어 있으면 FMEmptyState.
    var newFiltersList: [Filter] { filterLibraryStore.newFiltersList }
    /// 코인 잔액 — Firestore /users/{uid}/wallet/balance.value 미러.
    /// `subscribeToWallet()` 호출 시 실시간 갱신.
    var coinBalance: Int { walletStore.coinBalance }
    var isAuthenticated: Bool { sessionStore.isAuthenticated }
    /// Pro 멤버십 활성화 여부 — /users/{uid}/proStatus.active 미러.
    var isProActive: Bool { walletStore.isProActive }

    private var userDocListener: ListenerRegistration?
    private var notificationPrefsListener: ListenerRegistration?
    private var savedFiltersListener: ListenerRegistration?
    private var favoritesListener: ListenerRegistration?
    private var likedFiltersListener: ListenerRegistration?
    private var exportRequestsListener: ListenerRegistration?
    private var makerDraftsListener: ListenerRegistration?
    private var editorDraftListener: ListenerRegistration?
    private var editorDraftSaveTask: Task<Void, Never>?
    private var isApplyingRemoteEditorDraft = false
    /// Universal Link / push tap에서 도착한 라우트. RootShell이 관찰해 표시한다.
    /// 한 번 처리되면 nil로 리셋한다.
    @Published var pendingDeepLinkRoute: AppRoute?

    private var filterLibraryCancellable: AnyCancellable?
    private var walletCancellable: AnyCancellable?
    private var editorDraftCancellable: AnyCancellable?
    private var sessionCancellable: AnyCancellable?
    private var cameraStateCancellable: AnyCancellable?

    init(repository: any FilterRepository = BundleSeedFilterRepository()) {
        let filterLibraryStore = FilterLibraryStore(repository: repository)
        let walletStore = WalletStore()
        let editorDraftStore = EditorDraftStore()
        let sessionStore = SessionStore()
        let cameraStateStore = CameraStateStore()
        self.filterLibraryStore = filterLibraryStore
        self.walletStore = walletStore
        self.editorDraftStore = editorDraftStore
        self.sessionStore = sessionStore
        self.cameraStateStore = cameraStateStore
        filterLibraryCancellable = filterLibraryStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        walletCancellable = walletStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        editorDraftCancellable = editorDraftStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        sessionCancellable = sessionStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        cameraStateCancellable = cameraStateStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        editorDraftStore.onEditorDraftChanged = { [weak self] _ in
            guard let self, !self.isApplyingRemoteEditorDraft else { return }
            self.scheduleEditorDraftPersistence()
        }
    }

    private static func url(from value: Any?) -> URL? {
        guard let string = value as? String else { return nil }
        return URL(string: string)
    }

    // MooditStore lives the entire app lifetime so explicit deinit cleanup is
    // not required. Swift 6 strict concurrency disallows touching non-Sendable
    // ListenerRegistration / AuthStateDidChangeListenerHandle from a nonisolated
    // deinit, so we rely on app termination to drop the listeners.

    // MARK: - Wallet

    /// 로그인 상태 변화에 따라 /users/{uid}/wallet 와 /users/{uid}/proStatus 리스너를 설치 / 해제.
    /// 앱 진입 시 한 번만 호출하면 자동으로 추적.
    func subscribeToWallet() {
        sessionStore.subscribeToAuthState { [weak self] user in
            guard let self else { return }
            Telemetry.setUserId(user?.uid)
            self.attachWalletListeners(uid: user?.uid)
            if user != nil {
                PushRegistration.shared.retryDeviceRegistrationForCurrentUser()
            }
        }
    }

    func refreshOnForeground() async {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let user = SessionStore.currentFirebaseUser else {
            sessionStore.setAuthenticated(false)
            attachWalletListeners(uid: nil)
            return
        }
        do {
            _ = try await user.getIDTokenResult(forcingRefresh: true)
        } catch {
            Telemetry.record(error: error, context: ["source": "refreshOnForeground"])
        }
        attachWalletListeners(uid: user.uid)
        sessionStore.setAuthenticated(true)
        PushRegistration.shared.retryDeviceRegistrationForCurrentUser()
        await load(force: true)
    }

    func setLocalAuthenticationFallback(_ authenticated: Bool) {
        sessionStore.setLocalAuthenticationFallback(authenticated)
        if !authenticated {
            resetUserScopedState()
        }
    }

    private func attachWalletListeners(uid: String?) {
        persistEditorDraftLocallyForCurrentUser()
        userDocListener?.remove()
        notificationPrefsListener?.remove()
        savedFiltersListener?.remove()
        favoritesListener?.remove()
        likedFiltersListener?.remove()
        exportRequestsListener?.remove()
        makerDraftsListener?.remove()
        editorDraftListener?.remove()
        editorDraftSaveTask?.cancel()
        userDocListener = nil
        notificationPrefsListener = nil
        savedFiltersListener = nil
        favoritesListener = nil
        likedFiltersListener = nil
        exportRequestsListener = nil
        makerDraftsListener = nil
        editorDraftListener = nil
        editorDraftSaveTask = nil
        sessionStore.attach(uid: uid)
        walletStore.attach(uid: uid)

        guard let uid else {
            // 로그아웃 / 미로그인 — 본인 스코프 모든 상태 즉시 정리.
            // 이전 사용자 잔재 방지 (#17).
            resetUserScopedState()
            return
        }
        restoreEditorDraftFromDisk(uid: uid)
        let db = Firestore.firestore()
        if let authUser = SessionStore.currentFirebaseUser {
            sessionStore.applyAuthUserBaseline(authUser)
        }
        userDocListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.sessionStore.markProfileLoaded()  // (#47) 첫 snapshot 도착 신호
                    guard let data = snapshot?.data() else { return }
                    self.sessionStore.applyUserDocument(data)
                }
            }
        // (#45) /users/{uid}/notificationPreferences/main listener — 사용자 토글 변경 즉시 반영.
        notificationPrefsListener = db.collection("users").document(uid)
            .collection("notificationPreferences").document("main")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    guard let data = snapshot?.data() else { return }
                    self.sessionStore.applyRemoteNotificationPreferences(data)
                }
            }
        savedFiltersListener = db.collection("users").document(uid)
            .collection("savedFilters")
            .order(by: "savedAt", descending: true)
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    let uuids = snapshot?.documents.compactMap { UUID(uuidString: $0.documentID) } ?? []
                    self.filterLibraryStore.setDownloadedFilterIDs(Set(uuids))
                }
            }

        favoritesListener = db.collection("users").document(uid)
            .collection("favorites")
            .order(by: "favoritedAt", descending: true)
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    let uuids = snapshot?.documents.compactMap { UUID(uuidString: $0.documentID) } ?? []
                    self.filterLibraryStore.setFavoriteFilterIDs(Set(uuids))
                }
            }

        likedFiltersListener = db.collectionGroup("likes")
            .whereField("uid", isEqualTo: uid)
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    let ids = snapshot?.documents.compactMap { document in
                        document.reference.parent.parent?.documentID
                    } ?? []
                    self.filterLibraryStore.setLikedFilterIDs(Set(ids))
                }
            }

        exportRequestsListener = db.collection("users").document(uid)
            .collection("exportRequests")
            .order(by: "requestedAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.sessionStore.setExportRequests(snapshot?.documents.compactMap(Self.decodeExportRequest) ?? [])
                }
            }

        makerDraftsListener = db.collection("users").document(uid)
            .collection("makerDrafts")
            .order(by: "updatedAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.editorDraftStore.setMakerFilters(snapshot?.documents.compactMap(Self.decodeMakerDraft) ?? [])
                }
            }

        editorDraftListener = db.collection("users").document(uid)
            .collection("editorDrafts").document("current")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    guard let snapshot, snapshot.exists, let draft = Self.decodeMakerDraft(id: snapshot.documentID, data: snapshot.data() ?? [:]) else {
                        return
                    }
                    guard draft.updatedAt >= self.editorDraft.updatedAt || !self.editorDraft.hasUserContent else { return }
                    self.isApplyingRemoteEditorDraft = true
                    self.editorDraft = draft
                    self.isApplyingRemoteEditorDraft = false
                    self.persistEditorDraftToDisk(uid: uid, draft: draft)
                }
            }
    }

    private static func decodeExportRequest(_ document: QueryDocumentSnapshot) -> DataExportRequest? {
        let data = document.data()
        let categories = (data["categories"] as? [String] ?? [])
            .compactMap(DataExportCategory.init(rawValue:))
        let formatRaw = (data["format"] as? String) ?? DataExportFormat.json.rawValue
        let requestedAt = (data["requestedAt"] as? Timestamp)?.dateValue() ?? Date()
        let rawStatus = (data["status"] as? String) ?? "requested"
        let downloadURL = (data["downloadURL"] as? String).flatMap(URL.init(string:))
        return DataExportRequest(
            id: document.documentID,
            categories: Set(categories),
            format: DataExportFormat(rawValue: formatRaw) ?? .json,
            requestedAt: requestedAt,
            status: exportStatusLabel(rawStatus, downloadURL: downloadURL),
            downloadURL: downloadURL
        )
    }

    private static func exportStatusLabel(_ rawStatus: String, downloadURL: URL?) -> String {
        if downloadURL != nil { return "준비 완료" }
        switch rawStatus {
        case "requested":
            return "요청됨"
        case "processing":
            return "처리 중"
        case "ready", "completed":
            return "준비 완료"
        case "failed":
            return "실패"
        case "expired":
            return "만료"
        default:
            return rawStatus
        }
    }

    private static func decodeMakerDraft(_ document: QueryDocumentSnapshot) -> MakerFilterDraft? {
        decodeMakerDraft(id: document.documentID, data: document.data())
    }

    private static func decodeMakerDraft(id documentID: String, data: [String: Any]) -> MakerFilterDraft? {
        let id = UUID(uuidString: documentID) ?? (data["id"] as? String).flatMap(UUID.init(uuidString:))
        guard let id else { return nil }
        let categoryRaw = (data["category"] as? String) ?? FilterCategory.cinematic.rawValue
        let statusRaw = (data["status"] as? String) ?? MakerFilterStatus.draft.rawValue
        let signatureKindRaw = data["signatureSampleKind"] as? String
        return MakerFilterDraft(
            id: id,
            name: (data["name"] as? String) ?? "",
            summary: (data["summary"] as? String) ?? "",
            category: FilterCategory(rawValue: categoryRaw) ?? .cinematic,
            tags: data["tags"] as? [String] ?? [],
            parameterValues: data["parameterValues"] as? [String: Double] ?? [:],
            lutFileName: data["lutFileName"] as? String,
            coverCount: min(1, max(0, (data["coverCount"] as? Int) ?? 0)),
            coverPhotoData: nil,
            signatureSampleKind: signatureKindRaw.flatMap(EditorReferenceSampleKind.init(rawValue:)),
            signatureSamplePhotoData: nil,
            beforeAfterEnabled: (data["beforeAfterEnabled"] as? Bool) ?? false,
            tosOriginal: (data["tosOriginal"] as? Bool) ?? false,
            tosPolicy: (data["tosPolicy"] as? Bool) ?? false,
            tosCommercial: (data["tosCommercial"] as? Bool) ?? false,
            status: MakerFilterStatus(rawValue: statusRaw) ?? .draft,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            submittedAt: (data["submittedAt"] as? Timestamp)?.dateValue(),
            rejectionReasons: decodeRejectionReasons(data),
            moderatorNote: data["moderatorNote"] as? String,
            rejectedAt: (data["rejectedAt"] as? Timestamp)?.dateValue(),
            firestoreFilterId: data["firestoreFilterId"] as? String
        )
    }

    private static func decodeRejectionReasons(_ data: [String: Any]) -> [RejectionReason]? {
        if let structured = data["rejectionReasons"] as? [[String: Any]] {
            let reasons = structured.compactMap { item -> RejectionReason? in
                let title = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let body = (item["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? (item["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? ""
                guard !title.isEmpty || !body.isEmpty else { return nil }
                return RejectionReason(title: title.isEmpty ? "검수 사유" : title, body: body)
            }
            return reasons.isEmpty ? nil : reasons
        }
        if let rawReasons = data["rejectionReasons"] as? [String] {
            let reasons = rawReasons
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { RejectionReason(title: "검수 사유", body: $0) }
            return reasons.isEmpty ? nil : reasons
        }
        if let reason = (data["rejectionReason"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reason.isEmpty {
            return [RejectionReason(title: "검수 사유", body: reason)]
        }
        return nil
    }

    var selectedFilter: Filter? {
        filterLibraryStore.selectedFilter
    }

    var libraryFilters: [Filter] {
        filterLibraryStore.libraryFilters
    }

    func load(force: Bool = false) async {
        await filterLibraryStore.load(force: force)
    }

    /// 로드 실패 후 사용자가 재시도. 직전 에러를 비우고 `load()` 를 재실행한다.
    func retry() async {
        await filterLibraryStore.retry()
    }

    /// Pro 구독 구매 직후 낙관적 활성화 (#27). Firestore listener가 도착하면 정정.
    func markProActiveOptimistically() {
        walletStore.markProActiveOptimistically()
    }

    /// 결제 실패 시 마지막 에러 메시지 (#41). PaymentFailedScreen이 표시 후 reset.
    var lastPaymentErrorMessage: String? {
        get { walletStore.lastPaymentErrorMessage }
        set { walletStore.lastPaymentErrorMessage = newValue }
    }
    /// (#47) /users/{uid} 첫 listener snapshot이 도착했는지 — RootShell의 핸들 검사 등에서 사용.
    /// listener attach 시 false → 첫 snapshot 도착 시 true. 비로그인 시 false.
    var hasLoadedProfile: Bool { sessionStore.hasLoadedProfile }
    /// 업로드/리뷰 등 비동기 callable 실패 시 사용자에 보여줄 에러 메시지 (#47).
    @Published var lastSubmitErrorMessage: String?

    func setNotificationPreference<Value: Equatable>(
        _ keyPath: WritableKeyPath<NotificationPreferences, Value>,
        to value: Value
    ) {
        sessionStore.setNotificationPreference(keyPath, to: value)
    }

    func scheduleNotificationPreferencesSave() {
        sessionStore.scheduleNotificationPreferencesSave()
    }

    /// 코인 잔액 낙관적 조정 (#29 적립, #31 차감). listener가 도착하면 정정.
    /// 양수: 적립 (IAP 구매), 음수: 차감 (필터 구매). server-side는 별도 callable이 처리.
    /// Firestore listener는 server 값으로 덮어쓰기 (비-가산)이라 중복 카운트 없음.
    func creditCoinsOptimistically(_ amount: Int) {
        walletStore.creditCoinsOptimistically(amount)
    }

    func reconcileCoinBalance(_ balance: Int) {
        walletStore.reconcileCoinBalance(balance)
    }

    /// 로그아웃 / 사용자 전환 시 본인 스코프 데이터 일괄 초기화 (#17).
    /// `Auth.signOut()` 호출 직후 또는 attachWalletListeners(uid: nil)에서 사용.
    func resetUserScopedState() {
        walletStore.reset()
        filterLibraryStore.resetUserScopedState()
        sessionStore.resetUserScopedState()
        cameraStateStore.resetUserScopedState()
        editorDraftStore.resetUserScopedState()
        sessionStore.markProfileUnloaded()
        lastPaymentErrorMessage = nil
        lastSubmitErrorMessage = nil
    }

    func select(_ filter: Filter) {
        filterLibraryStore.select(filter)
    }

    func download(_ filter: Filter) async throws {
        try await filterLibraryStore.download(filter)
    }

    func download(filterID: String) async throws {
        try await filterLibraryStore.download(filterID: filterID)
    }

    func removeDownload(_ filter: Filter) {
        filterLibraryStore.removeDownloadAndPersist(filter)
    }

    func toggleFavorite(_ filter: Filter) {
        filterLibraryStore.toggleFavoriteAndPersist(filter)
    }

    func isFavorite(_ filter: Filter) -> Bool {
        filterLibraryStore.isFavorite(filter)
    }

    func isDownloaded(_ filter: Filter) -> Bool {
        filterLibraryStore.isDownloaded(filter)
    }

    func setImportedPhotoData(_ data: Data?) {
        cameraStateStore.setImportedPhotoData(data)
    }

    func setEditorReferencePhotoData(_ data: Data?) {
        editorDraftStore.setEditorReferencePhotoData(data)
    }

    func setEditorReferenceSampleKind(_ kind: EditorReferenceSampleKind) {
        editorDraftStore.setEditorReferenceSampleKind(kind)
    }

    @discardableResult
    func saveProfile(_ profile: EditableProfile) async throws -> EditableProfile {
        try await sessionStore.saveProfile(profile)
    }

    func markAccountDeletionRequested() async throws {
        try await sessionStore.markAccountDeletionRequested()
    }

    func toggleExportCategory(_ category: DataExportCategory) {
        sessionStore.toggleExportCategory(category)
    }

    func requestDataExport() {
        sessionStore.requestDataExport()
    }

    func resetEditorDraft() {
        editorDraftStore.resetEditorDraft()
    }

    func updateEditorDraft(
        _ mutate: (inout MakerFilterDraft) -> Void,
        touchUpdatedAt: Bool = true
    ) {
        editorDraftStore.updateEditorDraft(mutate, touchUpdatedAt: touchUpdatedAt)
    }

    func updateEditorParameter(_ key: String, value: Double) {
        editorDraftStore.updateEditorParameter(key, value: value)
    }

    func setEditorLUT(_ fileName: String, lut: LUT3D? = nil) {
        editorDraftStore.setEditorLUT(fileName, lut: lut)
    }

    var editorPreviewParameters: EditorParameters {
        editorDraftStore.editorPreviewParameters
    }

    var editorPreviewGrain: Float {
        editorDraftStore.editorPreviewGrain
    }

    var editorPreviewVignette: Float {
        editorDraftStore.editorPreviewVignette
    }

    func saveEditorDraft() {
        _ = editorDraftStore.saveEditorDraft()
    }

    func saveCurrentUploadDraftIfNeeded() {
        _ = editorDraftStore.saveCurrentUploadDraftIfNeeded()
    }

    func addUploadCover() {
        editorDraftStore.addUploadCover()
    }

    func removeUploadCover() {
        editorDraftStore.removeUploadCover()
    }

    func setUploadCoverPhotoData(_ data: Data?) {
        editorDraftStore.setUploadCoverPhotoData(data)
    }

    func setUploadSignatureSampleKind(_ kind: EditorReferenceSampleKind) {
        editorDraftStore.setUploadSignatureSampleKind(kind)
    }

    func setUploadSignatureSampleData(_ data: Data?) {
        editorDraftStore.setUploadSignatureSampleData(data)
    }

    func clearUploadSignatureSample() {
        editorDraftStore.clearUploadSignatureSample()
    }

    func addUploadTag(_ tag: String) {
        editorDraftStore.addUploadTag(tag)
    }

    func removeUploadTag(_ tag: String) {
        editorDraftStore.removeUploadTag(tag)
    }

    func setUploadCategory(_ category: FilterCategory) {
        editorDraftStore.setUploadCategory(category)
    }

    func submitCurrentDraft() {
        _ = editorDraftStore.submitCurrentDraft()
    }

    func startEditing(_ draft: MakerFilterDraft) {
        editorDraftStore.startEditing(draft)
    }

    func markMakerFilterPrivate(_ draft: MakerFilterDraft) {
        _ = editorDraftStore.markMakerFilterPrivate(draft)
    }

    private func scheduleEditorDraftPersistence() {
        guard let uid = sessionStore.currentUserID else { return }
        let draft = editorDraft
        if draft.hasUserContent {
            persistEditorDraftToDisk(uid: uid, draft: draft)
        } else {
            removeEditorDraftFromDisk(uid: uid)
        }

        #if DEBUG
        guard !isUITesting else { return }
        #endif
        editorDraftSaveTask?.cancel()
        editorDraftSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await self?.persistEditorDraftRemote(uid: uid, draft: draft)
        }
    }

    private func persistEditorDraftRemote(uid: String, draft: MakerFilterDraft) async {
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("editorDrafts").document("current")
        do {
            if draft.hasUserContent {
                try await ref.setData(editorDraftPayload(draft), merge: true)
            } else {
                try await ref.delete()
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.lastSubmitErrorMessage = "에디터 초안 동기화 실패: \(FirestoreErrorMapper.friendlyMessage(for: error))"
            }
        }
    }

    private func editorDraftPayload(_ draft: MakerFilterDraft) -> [String: Any] {
        var payload: [String: Any] = [
            "id": draft.id.uuidString,
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
            "updatedAt": Timestamp(date: draft.updatedAt)
        ]
        if let lutFileName = draft.lutFileName {
            payload["lutFileName"] = lutFileName
        } else {
            payload["lutFileName"] = FieldValue.delete()
        }
        if let signatureSampleKind = draft.signatureSampleKind {
            payload["signatureSampleKind"] = signatureSampleKind.rawValue
        } else {
            payload["signatureSampleKind"] = FieldValue.delete()
        }
        if let submittedAt = draft.submittedAt {
            payload["submittedAt"] = Timestamp(date: submittedAt)
        } else {
            payload["submittedAt"] = FieldValue.delete()
        }
        if let firestoreFilterId = draft.firestoreFilterId {
            payload["firestoreFilterId"] = firestoreFilterId
        } else {
            payload["firestoreFilterId"] = FieldValue.delete()
        }
        return payload
    }

    private func persistEditorDraftLocallyForCurrentUser() {
        guard let currentUserID = sessionStore.currentUserID, editorDraft.hasUserContent else { return }
        persistEditorDraftToDisk(uid: currentUserID, draft: editorDraft)
    }

    private func restoreEditorDraftFromDisk(uid: String) {
        guard let data = UserDefaults.standard.data(forKey: editorDraftDiskKey(uid: uid)),
              let draft = try? JSONDecoder().decode(MakerFilterDraft.self, from: data),
              draft.hasUserContent else {
            return
        }
        var normalizedDraft = draft
        normalizedDraft.coverCount = min(1, max(0, normalizedDraft.coverCount))
        isApplyingRemoteEditorDraft = true
        editorDraft = normalizedDraft
        isApplyingRemoteEditorDraft = false
    }

    private func persistEditorDraftToDisk(uid: String, draft: MakerFilterDraft) {
        guard draft.hasUserContent else {
            removeEditorDraftFromDisk(uid: uid)
            return
        }
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: editorDraftDiskKey(uid: uid))
    }

    private func removeEditorDraftFromDisk(uid: String) {
        UserDefaults.standard.removeObject(forKey: editorDraftDiskKey(uid: uid))
    }

    private func editorDraftDiskKey(uid: String) -> String {
        "moodit.editorDraft.\(uid)"
    }

    func filter(matching routeID: String) -> Filter? {
        filterLibraryStore.filter(matching: routeID)
    }
}
