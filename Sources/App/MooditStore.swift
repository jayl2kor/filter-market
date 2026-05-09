import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import FilterEngine
import Marketplace
import Models

// Disambiguate from FirebaseFirestore.Filter (which is bridged from FIRFilter).
typealias Filter = Models.Filter

private enum ProfileAvatarUploadError: LocalizedError {
    case imageTooLarge
    case invalidUploadResponse
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .imageTooLarge:
            "프로필 사진 용량이 너무 커요. 다른 사진을 선택해주세요."
        case .invalidUploadResponse:
            "프로필 사진 업로드 정보를 읽지 못했어요."
        case .uploadFailed:
            "프로필 사진 업로드에 실패했어요."
        }
    }
}

@MainActor
final class MooditStore: ObservableObject {
    @Published private(set) var filters: [Filter] = []
    @Published private(set) var downloadedFilterIDs: Set<Filter.ID> = []
    @Published private(set) var favoriteFilterIDs: Set<Filter.ID> = []
    @Published var selectedFilterID: Filter.ID?
    @Published var cameraAspectRatio: PhotoCropAspectRatio = .fourThree
    @Published var cameraTimerOption: CameraTimerOption = .off
    @Published var cameraGridEnabled = true
    @Published var cameraFlashMode: CameraFlashMode = .off
    @Published var cameraZoomPreset: Double = 1.0
    @Published var importedPhotoData: Data?
    @Published var editorReferencePhotoData: Data?
    @Published var editorReferencePhotoRevision = 0
    @Published var editorReferenceSampleKind: EditorReferenceSampleKind = .portrait
    @Published var editableProfile = EditableProfile.empty
    @Published var lastProfileSavedAt: Date?
    @Published var accountDeletionRequestedAt: Date?
    @Published var selectedExportCategories: Set<DataExportCategory> = Set(DataExportCategory.allCases)
    @Published var selectedExportFormat: DataExportFormat = .json
    /// 데이터 내보내기 요청 이력 — 진짜 데이터는 Firestore /users/{uid}/exportRequests에서 들어와야 함.
    /// (이전: 2개 하드코딩 mock 잔재 — 사용자가 요청한 적 없는 export 이력이 노출되는 문제 해결)
    @Published var exportRequests: [DataExportRequest] = []
    @Published var notificationPreferences = NotificationPreferences() {
        didSet {
            ForegroundNotificationPolicy.shared.update(preferences: notificationPreferences)
        }
    }
    @Published var editorDraft = MakerFilterDraft.empty {
        didSet {
            guard !isApplyingRemoteEditorDraft else { return }
            scheduleEditorDraftPersistence()
        }
    }
    @Published var editorImportedLUT: LUT3D?
    @Published var editorImportedLUTRevision = 0
    @Published var uploadStep: UploadStep = .cover
    @Published var selectedMakerStatus: MakerFilterStatus = .all
    /// 메이커 본인의 드래프트/검수/공개 필터 — 진짜 데이터는 Firestore /filters where authorUid==uid에서 들어옴.
    /// 사용자가 처음 진입하면 빈 배열 → FMEmptyState 노출. 이후 createDraft / submitDraft 흐름으로 채워짐.
    /// (이전: 4개 하드코딩 mock 잔재 — 사용자 본인이 만들지 않은 필터가 노출되는 문제 해결)
    @Published var makerFilters: [MakerFilterDraft] = []
    /// manifest 로드 실패 시 마지막 에러. UI 는 이 값을 보고 ErrorBanner / FMEmptyState 를 노출.
    @Published private(set) var loadError: Error?
    /// 로드 진행 상태. skeleton vs 에러 vs 빈 상태 분기에 사용.
    @Published private(set) var isLoading = false
    /// 마켓 트렌딩 — useCount 내림차순. 비어 있으면 FMEmptyState.
    @Published private(set) var trendingFilters: [Filter] = []
    /// 마켓 신규 — createdAt 내림차순. 비어 있으면 FMEmptyState.
    @Published private(set) var newFiltersList: [Filter] = []
    /// 코인 잔액 — Firestore /users/{uid}/wallet/balance.value 미러.
    /// `subscribeToWallet()` 호출 시 실시간 갱신.
    @Published private(set) var coinBalance: Int = 0
    @Published private(set) var isAuthenticated: Bool = false
    /// Pro 멤버십 활성화 여부 — /users/{uid}/proStatus.active 미러.
    @Published private(set) var isProActive: Bool = false

    private var walletListener: ListenerRegistration?
    private var proStatusListener: ListenerRegistration?
    private var userDocListener: ListenerRegistration?
    private var notificationPrefsListener: ListenerRegistration?
    private var savedFiltersListener: ListenerRegistration?
    private var favoritesListener: ListenerRegistration?
    private var exportRequestsListener: ListenerRegistration?
    private var makerDraftsListener: ListenerRegistration?
    private var editorDraftListener: ListenerRegistration?
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var optimisticCoinReconcileTask: Task<Void, Never>?
    private var notificationPreferencesSaveTask: Task<Void, Never>?
    private var editorDraftSaveTask: Task<Void, Never>?
    private var saveProfileTask: Task<Void, Never>?
    private var saveProfileGeneration = 0
    private var currentUserID: String?
    private var isApplyingRemoteEditorDraft = false
    private struct ProfileAvatarUpload {
        let publicURL: URL
        let objectKey: String
    }
    /// Universal Link / push tap에서 도착한 라우트. RootShell이 관찰해 표시한다.
    /// 한 번 처리되면 nil로 리셋한다.
    @Published var pendingDeepLinkRoute: AppRoute?

    private let repository: any FilterRepository

    init(repository: any FilterRepository = BundleSeedFilterRepository()) {
        self.repository = repository
        #if DEBUG
        if isUITesting {
            isAuthenticated = Self.uiTestingAuthenticationFlag()
        }
        #endif
    }

    private static func url(from value: Any?) -> URL? {
        guard let string = value as? String else { return nil }
        return URL(string: string)
    }

    nonisolated private static var currentFirebaseUser: User? {
        guard !isUnitTesting, FirebaseApp.app() != nil else { return nil }
        return Auth.auth().currentUser
    }

    nonisolated private static var currentFirebaseUID: String? {
        currentFirebaseUser?.uid
    }

    nonisolated private static var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MooditStore lives the entire app lifetime so explicit deinit cleanup is
    // not required. Swift 6 strict concurrency disallows touching non-Sendable
    // ListenerRegistration / AuthStateDidChangeListenerHandle from a nonisolated
    // deinit, so we rely on app termination to drop the listeners.

    // MARK: - Wallet

    /// 로그인 상태 변화에 따라 /users/{uid}/wallet 와 /users/{uid}/proStatus 리스너를 설치 / 해제.
    /// 앱 진입 시 한 번만 호출하면 자동으로 추적.
    func subscribeToWallet() {
        #if DEBUG
        guard !isUITesting else {
            hasLoadedProfile = true
            isAuthenticated = Self.uiTestingAuthenticationFlag()
            return
        }
        #endif
        guard !Self.isUnitTesting, FirebaseApp.app() != nil else {
            hasLoadedProfile = true
            isAuthenticated = false
            return
        }
        guard authStateHandle == nil else { return } // idempotent
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                Telemetry.setUserId(user?.uid)
                self.isAuthenticated = (user != nil)
                self.attachWalletListeners(uid: user?.uid)
                if user != nil {
                    PushRegistration.shared.retryDeviceRegistrationForCurrentUser()
                }
            }
        }
    }

    func refreshOnForeground() async {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let user = Self.currentFirebaseUser else {
            isAuthenticated = false
            attachWalletListeners(uid: nil)
            return
        }
        do {
            _ = try await user.getIDTokenResult(forcingRefresh: true)
        } catch {
            Telemetry.record(error: error, context: ["source": "refreshOnForeground"])
        }
        attachWalletListeners(uid: user.uid)
        isAuthenticated = true
        PushRegistration.shared.retryDeviceRegistrationForCurrentUser()
        await load(force: true)
    }

    func setLocalAuthenticationFallback(_ authenticated: Bool) {
        isAuthenticated = authenticated
        if !authenticated {
            resetUserScopedState()
        }
    }

    #if DEBUG
    private static func uiTestingAuthenticationFlag() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-isAuthenticated"),
              args.indices.contains(index + 1) else {
            return false
        }
        return ["1", "true", "yes"].contains(args[index + 1].lowercased())
    }
    #endif

    private func attachWalletListeners(uid: String?) {
        persistEditorDraftLocallyForCurrentUser()
        walletListener?.remove()
        proStatusListener?.remove()
        userDocListener?.remove()
        notificationPrefsListener?.remove()
        savedFiltersListener?.remove()
        favoritesListener?.remove()
        exportRequestsListener?.remove()
        makerDraftsListener?.remove()
        editorDraftListener?.remove()
        notificationPreferencesSaveTask?.cancel()
        editorDraftSaveTask?.cancel()
        walletListener = nil
        proStatusListener = nil
        userDocListener = nil
        notificationPrefsListener = nil
        savedFiltersListener = nil
        favoritesListener = nil
        exportRequestsListener = nil
        makerDraftsListener = nil
        editorDraftListener = nil
        optimisticCoinReconcileTask?.cancel()
        optimisticCoinReconcileTask = nil
        notificationPreferencesSaveTask = nil
        editorDraftSaveTask = nil
        currentUserID = uid

        guard let uid else {
            // 로그아웃 / 미로그인 — 본인 스코프 모든 상태 즉시 정리.
            // 이전 사용자 잔재 방지 (#17).
            hasLoadedProfile = false  // (#47) 미로그인 reset
            resetUserScopedState()
            return
        }
        hasLoadedProfile = false  // (#47) 새 uid attach 시 — 다음 snapshot이 도착하면 true
        restoreEditorDraftFromDisk(uid: uid)
        let db = Firestore.firestore()
        // Auth.currentUser의 displayName/email 즉시 사용해 editableProfile 부분 채움.
        if let authUser = Self.currentFirebaseUser {
            editableProfile = EditableProfile(
                displayName: authUser.displayName ?? authUser.email?.split(separator: "@").first.map(String.init) ?? "",
                handle: authUser.email?.split(separator: "@").first.map(String.init) ?? String(authUser.uid.prefix(8)),
                bio: editableProfile.bio,
                website: editableProfile.website,
                makerPageVisible: editableProfile.makerPageVisible,
                photoSharingAllowed: editableProfile.photoSharingAllowed,
                avatarVariant: editableProfile.avatarVariant,
                avatarImageData: editableProfile.avatarImageData,
                avatarURL: editableProfile.avatarURL
            )
        }
        walletListener = db.collection("users").document(uid)
            .collection("wallet").document("balance")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    let value = (snapshot?.data()?["value"] as? Int) ?? 0
                    self.optimisticCoinReconcileTask?.cancel()
                    self.optimisticCoinReconcileTask = nil
                    self.coinBalance = value
                }
            }
        proStatusListener = db.collection("users").document(uid)
            .collection("proStatus").document("status")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    let active = (snapshot?.data()?["active"] as? Bool) ?? false
                    self.isProActive = active
                }
            }
        userDocListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.hasLoadedProfile = true  // (#47) 첫 snapshot 도착 신호
                    guard let data = snapshot?.data() else { return }
                    self.editableProfile = EditableProfile(
                        displayName: (data["displayName"] as? String) ?? self.editableProfile.displayName,
                        handle: (data["handle"] as? String) ?? self.editableProfile.handle,
                        bio: (data["bio"] as? String) ?? self.editableProfile.bio,
                        website: (data["website"] as? String) ?? self.editableProfile.website,
                        makerPageVisible: (data["makerPageVisible"] as? Bool) ?? self.editableProfile.makerPageVisible,
                        photoSharingAllowed: (data["photoSharingAllowed"] as? Bool) ?? self.editableProfile.photoSharingAllowed,
                        avatarVariant: (data["avatarVariant"] as? Int) ?? self.editableProfile.avatarVariant,
                        avatarImageData: self.editableProfile.avatarImageData,
                        avatarURL: Self.url(from: data["avatarURL"])
                            ?? Self.url(from: data["photoURL"])
                            ?? self.editableProfile.avatarURL
                    )
                }
            }
        // (#45) /users/{uid}/notificationPreferences/main listener — 사용자 토글 변경 즉시 반영.
        notificationPrefsListener = db.collection("users").document(uid)
            .collection("notificationPreferences").document("main")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    guard let data = snapshot?.data() else { return }
                    let remotePreferences = NotificationPreferences(
                        systemEnabled: (data["systemEnabled"] as? Bool) ?? self.notificationPreferences.systemEnabled,
                        social: (data["social"] as? Bool) ?? self.notificationPreferences.social,
                        reviews: (data["reviews"] as? Bool) ?? self.notificationPreferences.reviews,
                        marketplace: (data["marketplace"] as? Bool) ?? self.notificationPreferences.marketplace,
                        creator: (data["creator"] as? Bool) ?? self.notificationPreferences.creator,
                        wallet: (data["wallet"] as? Bool) ?? self.notificationPreferences.wallet,
                        product: (data["product"] as? Bool) ?? self.notificationPreferences.product,
                        quietHoursEnabled: (data["quietHoursEnabled"] as? Bool) ?? self.notificationPreferences.quietHoursEnabled,
                        quietStart: (data["quietStart"] as? String) ?? self.notificationPreferences.quietStart,
                        quietEnd: (data["quietEnd"] as? String) ?? self.notificationPreferences.quietEnd
                    )
                    if remotePreferences != self.notificationPreferences {
                        self.notificationPreferences = remotePreferences
                    }
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
                    self.downloadedFilterIDs = Set(uuids)
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
                    self.favoriteFilterIDs = Set(uuids)
                }
            }

        exportRequestsListener = db.collection("users").document(uid)
            .collection("exportRequests")
            .order(by: "requestedAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.exportRequests = snapshot?.documents.compactMap(Self.decodeExportRequest) ?? []
                }
            }

        makerDraftsListener = db.collection("users").document(uid)
            .collection("makerDrafts")
            .order(by: "updatedAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.makerFilters = snapshot?.documents.compactMap(Self.decodeMakerDraft) ?? []
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
            coverCount: (data["coverCount"] as? Int) ?? 0,
            signatureSampleKind: signatureKindRaw.flatMap(EditorReferenceSampleKind.init(rawValue:)),
            signatureSamplePhotoData: nil,
            beforeAfterEnabled: (data["beforeAfterEnabled"] as? Bool) ?? false,
            tosOriginal: (data["tosOriginal"] as? Bool) ?? false,
            tosPolicy: (data["tosPolicy"] as? Bool) ?? false,
            tosCommercial: (data["tosCommercial"] as? Bool) ?? false,
            status: MakerFilterStatus(rawValue: statusRaw) ?? .draft,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            submittedAt: (data["submittedAt"] as? Timestamp)?.dateValue(),
            firestoreFilterId: data["firestoreFilterId"] as? String
        )
    }

    var selectedFilter: Filter? {
        guard let selectedFilterID else { return filters.first }
        return filters.first { $0.id == selectedFilterID }
    }

    var libraryFilters: [Filter] {
        filters.filter { downloadedFilterIDs.contains($0.id) }
    }

    func load(force: Bool = false) async {
        // 이미 정상 로드된 상태면 재호출 무시. 실패 후 retry / pull-to-refresh 는 통과시킨다.
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
            // 트렌딩/신규 — repository의 default impl이 메모리 정렬, Firestore impl은 backend 정렬.
            // 실패해도 listFilters 결과는 유지 (트렌딩/신규는 조용히 비움).
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

    /// 로드 실패 후 사용자가 재시도. 직전 에러를 비우고 `load()` 를 재실행한다.
    func retry() async {
        loadError = nil
        await load()
    }

    /// Pro 구독 구매 직후 낙관적 활성화 (#27). Firestore listener가 도착하면 정정.
    func markProActiveOptimistically() {
        isProActive = true
    }

    /// 결제 실패 시 마지막 에러 메시지 (#41). PaymentFailedScreen이 표시 후 reset.
    @Published var lastPaymentErrorMessage: String?
    /// (#47) /users/{uid} 첫 listener snapshot이 도착했는지 — RootShell의 핸들 검사 등에서 사용.
    /// listener attach 시 false → 첫 snapshot 도착 시 true. 비로그인 시 false.
    @Published private(set) var hasLoadedProfile: Bool = false
    /// 업로드/리뷰 등 비동기 callable 실패 시 사용자에 보여줄 에러 메시지 (#47).
    @Published var lastSubmitErrorMessage: String?

    func setNotificationPreference<Value: Equatable>(
        _ keyPath: WritableKeyPath<NotificationPreferences, Value>,
        to value: Value
    ) {
        var preferences = notificationPreferences
        guard preferences[keyPath: keyPath] != value else { return }
        preferences[keyPath: keyPath] = value
        notificationPreferences = preferences
        scheduleNotificationPreferencesSave(preferences)
    }

    /// NotificationPreferences를 Firestore /users/{uid}/notificationPreferences/main에 저장 (#45).
    /// 사용자 입력에서만 호출하고, listener로 들어온 remote snapshot은 다시 저장하지 않는다.
    func scheduleNotificationPreferencesSave() {
        scheduleNotificationPreferencesSave(notificationPreferences)
    }

    private func scheduleNotificationPreferencesSave(_ preferences: NotificationPreferences) {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard Self.currentFirebaseUID != nil else { return }
        notificationPreferencesSaveTask?.cancel()
        notificationPreferencesSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await self?.persistNotificationPreferences(preferences)
        }
    }

    private func persistNotificationPreferences(_ preferences: NotificationPreferences) async {
        guard let uid = Self.currentFirebaseUID else { return }
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("notificationPreferences").document("main")
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ref.setData([
                    "systemEnabled": preferences.systemEnabled,
                    "social": preferences.social,
                    "reviews": preferences.reviews,
                    "marketplace": preferences.marketplace,
                    "creator": preferences.creator,
                    "wallet": preferences.wallet,
                    "product": preferences.product,
                    "quietHoursEnabled": preferences.quietHoursEnabled,
                    "quietStart": preferences.quietStart,
                    "quietEnd": preferences.quietEnd,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            notificationPreferencesSaveTask = nil
        } catch {
            lastSubmitErrorMessage = "알림 설정 저장 실패: \(error.localizedDescription)"
        }
    }

    /// 코인 잔액 낙관적 조정 (#29 적립, #31 차감). listener가 도착하면 정정.
    /// 양수: 적립 (IAP 구매), 음수: 차감 (필터 구매). server-side는 별도 callable이 처리.
    /// Firestore listener는 server 값으로 덮어쓰기 (비-가산)이라 중복 카운트 없음.
    func creditCoinsOptimistically(_ amount: Int) {
        coinBalance = max(0, coinBalance + amount)
        optimisticCoinReconcileTask?.cancel()
        optimisticCoinReconcileTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await self?.forceReloadWalletBalance()
        }
    }

    func reconcileCoinBalance(_ balance: Int) {
        optimisticCoinReconcileTask?.cancel()
        optimisticCoinReconcileTask = nil
        coinBalance = max(0, balance)
    }

    private func persistSavedFilterAsync(filterId: Filter.ID, save: Bool) async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = Self.currentFirebaseUID else { return }
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("savedFilters").document(filterId.uuidString)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if save {
                ref.setData([
                    "filterId": filterId.uuidString,
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

    private func persistFavoriteAsync(filterId: Filter.ID, save: Bool) async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = Self.currentFirebaseUID else { return }
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("favorites").document(filterId.uuidString)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if save {
                ref.setData([
                    "filterId": filterId.uuidString,
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

    private func forceReloadWalletBalance() async {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = Self.currentFirebaseUID else { return }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("wallet").document("balance")
                .getDocument()
            let value = (snapshot.data()?["value"] as? Int) ?? 0
            await MainActor.run {
                self.coinBalance = value
                self.optimisticCoinReconcileTask = nil
            }
        } catch {
            await MainActor.run {
                self.lastPaymentErrorMessage = "잔액 동기화 실패: \(error.localizedDescription)"
            }
        }
    }

    /// 로그아웃 / 사용자 전환 시 본인 스코프 데이터 일괄 초기화 (#17).
    /// `Auth.signOut()` 호출 직후 또는 attachWalletListeners(uid: nil)에서 사용.
    func resetUserScopedState() {
        coinBalance = 0
        isProActive = false
        editableProfile = .empty
        lastProfileSavedAt = nil
        accountDeletionRequestedAt = nil
        downloadedFilterIDs = []
        favoriteFilterIDs = []
        notificationPreferences = NotificationPreferences()
        importedPhotoData = nil
        editorReferencePhotoData = nil
        editorReferencePhotoRevision = 0
        editorReferenceSampleKind = .portrait
        editorImportedLUT = nil
        editorImportedLUTRevision = 0
        editorDraft = MakerFilterDraft.empty
        uploadStep = .cover
        selectedMakerStatus = .all
        makerFilters = []
        exportRequests = []
        selectedFilterID = nil
        hasLoadedProfile = false
        lastPaymentErrorMessage = nil
        lastSubmitErrorMessage = nil
        saveProfileTask?.cancel()
        saveProfileTask = nil
        saveProfileGeneration += 1
    }

    func select(_ filter: Filter) {
        selectedFilterID = filter.id
        downloadedFilterIDs.insert(filter.id)
    }

    func download(_ filter: Filter) async throws {
        // (#24) /users/{uid}/savedFilters/{filterId} Firestore 동기화 — 앱 재시작/다른 디바이스에서도 유지.
        try await persistSavedFilterAsync(filterId: filter.id, save: true)
        downloadedFilterIDs.insert(filter.id)
    }

    func download(filterID: String) async throws {
        guard let id = UUID(uuidString: filterID) else { return }
        try await persistSavedFilterAsync(filterId: id, save: true)
        downloadedFilterIDs.insert(id)
    }

    func removeDownload(_ filter: Filter) {
        let hadDownload = downloadedFilterIDs.contains(filter.id)
        let hadFavorite = favoriteFilterIDs.contains(filter.id)
        downloadedFilterIDs.remove(filter.id)
        favoriteFilterIDs.remove(filter.id)
        Task { [weak self] in
            do {
                try await self?.persistSavedFilterAsync(filterId: filter.id, save: false)
                try await self?.persistFavoriteAsync(filterId: filter.id, save: false)
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if hadDownload { self.downloadedFilterIDs.insert(filter.id) }
                    if hadFavorite { self.favoriteFilterIDs.insert(filter.id) }
                    self.lastSubmitErrorMessage = "저장 상태 동기화 실패: \(error.localizedDescription)"
                }
            }
        }
        if selectedFilterID == filter.id {
            selectedFilterID = libraryFilters.first?.id ?? filters.first?.id
        }
    }

    func toggleFavorite(_ filter: Filter) {
        let shouldSave: Bool
        if favoriteFilterIDs.contains(filter.id) {
            favoriteFilterIDs.remove(filter.id)
            shouldSave = false
        } else {
            favoriteFilterIDs.insert(filter.id)
            shouldSave = true
        }
        Task { [weak self] in
            do {
                try await self?.persistFavoriteAsync(filterId: filter.id, save: shouldSave)
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if shouldSave {
                        self.favoriteFilterIDs.remove(filter.id)
                    } else {
                        self.favoriteFilterIDs.insert(filter.id)
                    }
                    self.lastSubmitErrorMessage = "즐겨찾기 동기화 실패: \(error.localizedDescription)"
                }
            }
        }
    }

    func isFavorite(_ filter: Filter) -> Bool {
        favoriteFilterIDs.contains(filter.id)
    }

    func isDownloaded(_ filter: Filter) -> Bool {
        downloadedFilterIDs.contains(filter.id)
    }

    func setImportedPhotoData(_ data: Data?) {
        importedPhotoData = data
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

    private func uploadProfileAvatarImageData(_ data: Data?) async throws -> ProfileAvatarUpload? {
        guard let data else { return nil }
        guard data.count <= 1_500_000 else {
            throw ProfileAvatarUploadError.imageTooLarge
        }

        let callable = Functions.functions(region: "asia-northeast3").httpsCallable("profileAvatarUploadInit")
        let result = try await callable.call([
            "contentType": "image/jpeg",
            "imageBytes": data.count
        ])
        guard let payload = result.data as? [String: Any],
              let uploadURLString = payload["uploadUrl"] as? String,
              let uploadURL = URL(string: uploadURLString),
              let publicURLString = payload["publicURL"] as? String,
              let publicURL = URL(string: publicURLString),
              let objectKey = payload["objectKey"] as? String else {
            throw ProfileAvatarUploadError.invalidUploadResponse
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.httpBody = data
        let headers = payload["uploadHeaders"] as? [String: String] ?? [:]
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ProfileAvatarUploadError.uploadFailed
        }

        return ProfileAvatarUpload(publicURL: publicURL, objectKey: objectKey)
    }

    func saveProfile(_ profile: EditableProfile) {
        editableProfile = profile
        lastProfileSavedAt = Date()
        lastSubmitErrorMessage = nil
        saveProfileTask?.cancel()
        saveProfileGeneration += 1
        let generation = saveProfileGeneration
        // Firestore /users/{uid} 영속화 — Cloud Function updateProfile callable로 위임 (서버 측 검증 + 일관 schema).
        // 핸들 변경은 별도 setHandle callable로 분리 (uniqueness check + reservation 보호).
        saveProfileTask = Task { [weak self, profile, generation] in
            let region = "asia-northeast3"
            do {
                guard let self else { return }
                let avatarUpload = try await self.uploadProfileAvatarImageData(profile.avatarImageData)
                let avatarURL = avatarUpload?.publicURL ?? profile.avatarURL
                var payload: [String: Any] = [
                    "displayName": profile.displayName,
                    "bio": profile.bio,
                    "website": profile.website,
                    "makerPageVisible": profile.makerPageVisible,
                    "photoSharingAllowed": profile.photoSharingAllowed,
                    "avatarVariant": profile.avatarVariant
                ]
                if let avatarURL {
                    payload["avatarURL"] = avatarURL.absoluteString
                    payload["photoURL"] = avatarURL.absoluteString
                }
                if let avatarUpload {
                    payload["avatarObjectKey"] = avatarUpload.objectKey
                }
                let updateCallable = Functions.functions(region: region).httpsCallable("updateProfile")
                _ = try await updateCallable.call(payload)
                if !profile.handle.isEmpty {
                    let handleCallable = Functions.functions(region: region).httpsCallable("setHandle")
                    _ = try await handleCallable.call(["handle": profile.handle])
                }
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self, self.saveProfileGeneration == generation else { return }
                    if let avatarURL {
                        self.editableProfile.avatarURL = avatarURL
                    }
                    self.lastSubmitErrorMessage = nil
                    self.saveProfileTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                // (#47) silent failure 제거 — 사용자 알림 surface.
                await MainActor.run { [weak self] in
                    guard let self, self.saveProfileGeneration == generation else { return }
                    self.lastSubmitErrorMessage = "프로필 저장 실패: \(error.localizedDescription)"
                    self.saveProfileTask = nil
                }
            }
        }
    }

    func markAccountDeletionRequested() async throws {
        let callable = Functions.functions(region: "asia-northeast3").httpsCallable("deleteAccount")
        _ = try await callable.call([:] as [String: Any])
        accountDeletionRequestedAt = Date()
    }

    func toggleExportCategory(_ category: DataExportCategory) {
        if selectedExportCategories.contains(category) {
            selectedExportCategories.remove(category)
        } else {
            selectedExportCategories.insert(category)
        }
    }

    func requestDataExport() {
        guard !selectedExportCategories.isEmpty else { return }
        let uid = Self.currentFirebaseUID
        let ref = uid.map {
            Firestore.firestore()
                .collection("users").document($0)
                .collection("exportRequests").document()
        }
        let request = DataExportRequest(
            id: ref?.documentID ?? UUID().uuidString,
            categories: selectedExportCategories,
            format: selectedExportFormat,
            requestedAt: Date(),
            status: "요청됨",
            downloadURL: nil
        )
        exportRequests.insert(request, at: 0)
        // (#42) Firestore /users/{uid}/exportRequests/{auto} 영속화 — 앱 재실행/다른 디바이스 일관성.
        guard let ref else { return }
        let categoriesArray = selectedExportCategories.map { $0.rawValue }
        ref.setData([
            "categories": categoriesArray,
            "format": selectedExportFormat.rawValue,
            "status": "requested",
            "requestedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                self?.lastSubmitErrorMessage = "데이터 내보내기 요청 실패: \(error.localizedDescription)"
            }
        }
    }

    func resetEditorDraft() {
        editorDraft = MakerFilterDraft.empty
        editorReferencePhotoData = nil
        editorReferencePhotoRevision = 0
        editorReferenceSampleKind = .portrait
        editorImportedLUT = nil
        editorImportedLUTRevision = 0
        uploadStep = .cover
    }

    func updateEditorParameter(_ key: String, value: Double) {
        editorDraft.parameterValues[key] = value
        editorDraft.updatedAt = Date()
    }

    func setEditorLUT(_ fileName: String, lut: LUT3D? = nil) {
        editorDraft.lutFileName = fileName
        editorImportedLUT = lut
        editorImportedLUTRevision += 1
        editorDraft.updatedAt = Date()
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

    func saveEditorDraft() {
        editorDraft.status = .draft
        editorDraft.updatedAt = Date()
        upsertMakerFilter(editorDraft)
    }

    func saveCurrentUploadDraftIfNeeded() {
        guard editorDraft.hasUserContent, editorDraft.status != .pending else { return }
        saveEditorDraft()
    }

    func addUploadCover() {
        editorDraft.coverCount = min(6, editorDraft.coverCount + 1)
        editorDraft.updatedAt = Date()
    }

    func removeUploadCover() {
        editorDraft.coverCount = max(0, editorDraft.coverCount - 1)
        editorDraft.updatedAt = Date()
    }

    func setUploadSignatureSampleKind(_ kind: EditorReferenceSampleKind) {
        editorDraft.signatureSampleKind = kind
        editorDraft.signatureSamplePhotoData = nil
        editorDraft.updatedAt = Date()
    }

    func setUploadSignatureSampleData(_ data: Data?) {
        editorDraft.signatureSamplePhotoData = data
        if data != nil {
            editorDraft.signatureSampleKind = nil
        }
        editorDraft.updatedAt = Date()
    }

    func clearUploadSignatureSample() {
        editorDraft.signatureSampleKind = nil
        editorDraft.signatureSamplePhotoData = nil
        editorDraft.updatedAt = Date()
    }

    func addUploadTag(_ tag: String) {
        let normalized = tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard !normalized.isEmpty, !editorDraft.tags.contains(normalized) else { return }
        editorDraft.tags.append(normalized)
        editorDraft.updatedAt = Date()
    }

    func removeUploadTag(_ tag: String) {
        editorDraft.tags.removeAll { $0 == tag }
        editorDraft.updatedAt = Date()
    }

    func setUploadCategory(_ category: FilterCategory) {
        editorDraft.category = category
        editorDraft.updatedAt = Date()
    }

    func submitCurrentDraft() {
        editorDraft.status = .pending
        editorDraft.submittedAt = Date()
        editorDraft.updatedAt = Date()
        uploadStep = .pending
        upsertMakerFilter(editorDraft)
        // (#44) firestoreFilterId가 있으면 submitForReview callable 호출.
        // uploadInit/uploadFinalize 흐름이 아직 client에서 호출되지 않으면 nil — silent skip.
        guard let fsId = editorDraft.firestoreFilterId else { return }
        let payload: [String: Any] = [
            "filterId": fsId,
            "tosOriginal": editorDraft.tosOriginal,
            "tosPolicy": editorDraft.tosPolicy,
            "tosCommercial": editorDraft.tosCommercial,
        ]
        Task { [weak self] in
            do {
                _ = try await Functions.functions(region: "asia-northeast3")
                    .httpsCallable("submitForReview")
                    .call(payload)
            } catch {
                // (#47) silent failure 제거 — 사용자에게 알림 가능하게 store에 메시지 게시.
                await MainActor.run { [weak self] in
                    self?.lastSubmitErrorMessage = "검수 제출 실패: \(error.localizedDescription)"
                }
            }
        }
    }

    func startEditing(_ draft: MakerFilterDraft) {
        editorDraft = draft
        uploadStep = .cover
    }

    func markMakerFilterPrivate(_ draft: MakerFilterDraft) {
        guard let existing = makerFilters.first(where: { $0.id == draft.id }) else { return }
        var updatedDraft = existing
        updatedDraft.status = .draft
        updatedDraft.updatedAt = Date()
        makerFilters = makerFilters.map { $0.id == draft.id ? updatedDraft : $0 }
        persistMakerDraft(updatedDraft)
    }

    private func upsertMakerFilter(_ draft: MakerFilterDraft) {
        if makerFilters.contains(where: { $0.id == draft.id }) {
            makerFilters = makerFilters.map { $0.id == draft.id ? draft : $0 }
        } else {
            makerFilters.insert(draft, at: 0)
        }
        persistMakerDraft(draft)
    }

    private func persistMakerDraft(_ draft: MakerFilterDraft) {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = Self.currentFirebaseUID else { return }
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
        if let firestoreFilterId = draft.firestoreFilterId {
            payload["firestoreFilterId"] = firestoreFilterId
        }
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("makerDrafts").document(draft.id.uuidString)
            .setData(payload, merge: true) { [weak self] error in
                guard let error else { return }
                Task { @MainActor in
                    self?.lastSubmitErrorMessage = "메이커 초안 저장 실패: \(error.localizedDescription)"
                }
            }
    }

    private func scheduleEditorDraftPersistence() {
        guard let uid = currentUserID else { return }
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
                self?.lastSubmitErrorMessage = "에디터 초안 동기화 실패: \(error.localizedDescription)"
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
        guard let currentUserID, editorDraft.hasUserContent else { return }
        persistEditorDraftToDisk(uid: currentUserID, draft: editorDraft)
    }

    private func restoreEditorDraftFromDisk(uid: String) {
        guard let data = UserDefaults.standard.data(forKey: editorDraftDiskKey(uid: uid)),
              let draft = try? JSONDecoder().decode(MakerFilterDraft.self, from: data),
              draft.hasUserContent else {
            return
        }
        isApplyingRemoteEditorDraft = true
        editorDraft = draft
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

private extension String {
    var normalizedFilterLookupKey: String {
        lowercased()
            .replacingOccurrences(of: "@", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
