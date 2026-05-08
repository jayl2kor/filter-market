import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import FilterEngine
import Marketplace
import Models

// Disambiguate from FirebaseFirestore.Filter (which is bridged from FIRFilter).
typealias Filter = Models.Filter

enum CameraTimerOption: Int, CaseIterable, Identifiable, Hashable {
    case off = 0
    case three = 3
    case ten = 10

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .off: "OFF"
        case .three: "3s"
        case .ten: "10s"
        }
    }
}

enum EditorReferenceSampleKind: String, CaseIterable, Identifiable, Hashable {
    case portrait
    case landscape
    case indoor
    case lifestyle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portrait: "인물"
        case .landscape: "풍경"
        case .indoor: "실내"
        case .lifestyle: "일상"
        }
    }
}

enum CameraFlashMode: String, CaseIterable, Identifiable, Hashable {
    case off
    case auto
    case on

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "OFF"
        case .auto: "AUTO"
        case .on: "ON"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "bolt.slash"
        case .auto: "bolt.badge.a"
        case .on: "bolt.fill"
        }
    }
}

struct EditableProfile: Equatable {
    var displayName: String
    var handle: String
    var bio: String
    var website: String
    var makerPageVisible: Bool
    var photoSharingAllowed: Bool
    var avatarVariant: Int
    var avatarImageData: Data?

    /// Preview / Xcode SwiftUI Preview 전용 — 실제 앱에서는 사용하지 않음.
    static let preview = EditableProfile(
        displayName: "강지수",
        handle: "sample.maker",
        bio: "필름 카메라와 햇빛을 좋아합니다. 카페·여행·일상 위주로 필터를 만들어요.",
        website: "https://example.com",
        makerPageVisible: true,
        photoSharingAllowed: false,
        avatarVariant: 0,
        avatarImageData: nil
    )

    /// 비로그인 / 로딩 중 placeholder. 실제 displayName/handle 은 Firebase Auth + Firestore 에서 채워짐.
    static let empty = EditableProfile(
        displayName: "",
        handle: "",
        bio: "",
        website: "",
        makerPageVisible: true,
        photoSharingAllowed: false,
        avatarVariant: 0,
        avatarImageData: nil
    )

    var displayHandle: String {
        "@" + handle
    }

    var initials: String {
        let source = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return source.isEmpty ? "MD" : String(source.prefix(2)).uppercased()
    }
}

enum DataExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case csv = "CSV"
    case html = "HTML"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .json: "기계 판독 권장"
        case .csv: "테이블 분리"
        case .html: "사람이 읽기"
        }
    }
}

enum DataExportCategory: String, CaseIterable, Identifiable {
    case account
    case profile
    case marketplace
    case wallet
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: "계정 정보"
        case .profile: "프로필"
        case .marketplace: "마켓 활동"
        case .wallet: "구매와 지갑"
        case .activity: "앱 활동"
        }
    }

    var detail: String {
        switch self {
        case .account: "이메일, 가입일, 인증 메타"
        case .profile: "표시 이름, 유저네임, 바이오, 링크"
        case .marketplace: "다운로드, 좋아요, 리뷰, 댓글"
        case .wallet: "Coin 잔액, 주문, 환불 요청"
        case .activity: "검색, 알림, 설정 변경 이력"
        }
    }
}

struct DataExportRequest: Identifiable, Equatable {
    let id: String
    let categories: Set<DataExportCategory>
    let format: DataExportFormat
    let requestedAt: Date
    var status: String
    var downloadURL: URL?

    var title: String {
        categories.count == DataExportCategory.allCases.count ? "전체 데이터" : "\(categories.count)개 카테고리"
    }
}

struct NotificationPreferences: Equatable {
    var systemEnabled = true
    var social = true
    var reviews = true
    var marketplace = true
    var creator = true
    var wallet = true
    var product = false
    var quietHoursEnabled = true
    var quietStart = "22:00"
    var quietEnd = "07:00"
}

enum EditorParameterSection: String, CaseIterable, Identifiable {
    case lighting
    case color
    case detail
    case effects
    case lut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lighting: "조명"
        case .color: "색"
        case .detail: "디테일"
        case .effects: "효과"
        case .lut: "LUT"
        }
    }

    var actionID: String {
        "editor.tab.\(rawValue)"
    }
}

enum UploadStep: String, CaseIterable, Identifiable {
    case cover
    case tags
    case submit
    case pending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cover: "표지"
        case .tags: "정보"
        case .submit: "제출"
        case .pending: "검수"
        }
    }
}

enum MakerFilterStatus: String, CaseIterable, Identifiable {
    case all
    case live
    case pending
    case rejected
    case draft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "전체"
        case .live: "공개"
        case .pending: "검수중"
        case .rejected: "반려"
        case .draft: "초안"
        }
    }
}

struct MakerFilterDraft: Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var summary: String
    var category: FilterCategory
    var tags: [String]
    var parameterValues: [String: Double]
    var lutFileName: String?
    var coverCount: Int
    var signatureSampleKind: EditorReferenceSampleKind?
    var signatureSamplePhotoData: Data?
    var beforeAfterEnabled: Bool
    var tosOriginal: Bool
    var tosPolicy: Bool
    var tosCommercial: Bool
    var status: MakerFilterStatus
    var updatedAt: Date
    var submittedAt: Date?
    /// uploadInit Cloud Function이 반환한 Firestore /filters/{id} 문서 ID (#44).
    /// nil이면 아직 R2 업로드 init 전 — submitCurrentDraft가 submitForReview 호출 가드.
    var firestoreFilterId: String? = nil

    /// 신규 드래프트 — 사용자가 처음 에디터 진입 시 빈 상태에서 시작.
    static let empty = MakerFilterDraft(
        name: "",
        summary: "",
        category: .cinematic,
        tags: [],
        parameterValues: [:],
        lutFileName: nil,
        coverCount: 0,
        signatureSampleKind: nil,
        signatureSamplePhotoData: nil,
        beforeAfterEnabled: false,
        tosOriginal: false,
        tosPolicy: false,
        tosCommercial: false,
        status: .draft,
        updatedAt: Date(),
        submittedAt: nil
    )

    /// Preview / SwiftUI Preview 전용 — 실제 앱에서는 사용 안 함.
    static let preview = MakerFilterDraft(
        name: "Amber Cafe",
        summary: "70년대 필름 카메라 톤. 카페, 실내, 골든아워에 어울리는 부드러운 골드.",
        category: .vintage,
        tags: ["카페", "골든아워", "필름", "warm"],
        parameterValues: [
            "exposure": 0.12,
            "contrast": 0.34,
            "saturation": 0.42,
            "grain": 0.28,
            "vignette": 0.18
        ],
        lutFileName: "amber_cafe_33.cube",
        coverCount: 3,
        signatureSampleKind: .lifestyle,
        signatureSamplePhotoData: nil,
        beforeAfterEnabled: true,
        tosOriginal: false,
        tosPolicy: false,
        tosCommercial: false,
        status: .draft,
        updatedAt: Date(),
        submittedAt: nil
    )

    var isReadyForSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !tags.isEmpty
            && coverCount > 0
            && tosOriginal
            && tosPolicy
            && tosCommercial
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
    @Published var editorDraft = MakerFilterDraft.empty
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
    /// Pro 멤버십 활성화 여부 — /users/{uid}/proStatus.active 미러.
    @Published private(set) var isProActive: Bool = false

    private var walletListener: ListenerRegistration?
    private var proStatusListener: ListenerRegistration?
    private var userDocListener: ListenerRegistration?
    private var notificationPrefsListener: ListenerRegistration?
    private var savedFiltersListener: ListenerRegistration?
    private var favoritesListener: ListenerRegistration?
    private var exportRequestsListener: ListenerRegistration?
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var optimisticCoinReconcileTask: Task<Void, Never>?
    private var notificationPreferencesSaveTask: Task<Void, Never>?
    /// Universal Link / push tap에서 도착한 라우트. RootShell이 관찰해 표시한다.
    /// 한 번 처리되면 nil로 리셋한다.
    @Published var pendingDeepLinkRoute: AppRoute?

    private let repository: any FilterRepository

    init(repository: any FilterRepository = BundleSeedFilterRepository()) {
        self.repository = repository
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
            return
        }
        #endif
        guard authStateHandle == nil else { return } // idempotent
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                Telemetry.setUserId(user?.uid)
                self.attachWalletListeners(uid: user?.uid)
                if user != nil {
                    PushRegistration.shared.retryDeviceRegistrationForCurrentUser()
                }
            }
        }
    }

    private func attachWalletListeners(uid: String?) {
        walletListener?.remove()
        proStatusListener?.remove()
        userDocListener?.remove()
        notificationPrefsListener?.remove()
        savedFiltersListener?.remove()
        favoritesListener?.remove()
        exportRequestsListener?.remove()
        notificationPreferencesSaveTask?.cancel()
        walletListener = nil
        proStatusListener = nil
        userDocListener = nil
        notificationPrefsListener = nil
        savedFiltersListener = nil
        favoritesListener = nil
        exportRequestsListener = nil
        optimisticCoinReconcileTask?.cancel()
        optimisticCoinReconcileTask = nil
        notificationPreferencesSaveTask = nil

        guard let uid else {
            // 로그아웃 / 미로그인 — 본인 스코프 모든 상태 즉시 정리.
            // 이전 사용자 잔재 방지 (#17).
            hasLoadedProfile = false  // (#47) 미로그인 reset
            resetUserScopedState()
            return
        }
        hasLoadedProfile = false  // (#47) 새 uid attach 시 — 다음 snapshot이 도착하면 true
        let db = Firestore.firestore()
        // Auth.currentUser의 displayName/email 즉시 사용해 editableProfile 부분 채움.
        if let authUser = Auth.auth().currentUser {
            editableProfile = EditableProfile(
                displayName: authUser.displayName ?? authUser.email?.split(separator: "@").first.map(String.init) ?? "",
                handle: authUser.email?.split(separator: "@").first.map(String.init) ?? String(authUser.uid.prefix(8)),
                bio: editableProfile.bio,
                website: editableProfile.website,
                makerPageVisible: editableProfile.makerPageVisible,
                photoSharingAllowed: editableProfile.photoSharingAllowed,
                avatarVariant: editableProfile.avatarVariant,
                avatarImageData: editableProfile.avatarImageData
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
                        avatarImageData: self.editableProfile.avatarImageData
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
        guard Auth.auth().currentUser?.uid != nil else { return }
        notificationPreferencesSaveTask?.cancel()
        notificationPreferencesSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await self?.persistNotificationPreferences(preferences)
        }
    }

    private func persistNotificationPreferences(_ preferences: NotificationPreferences) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
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

    private func persistSavedFilterAsync(filterId: Filter.ID, save: Bool) async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return }
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
        guard let uid = Auth.auth().currentUser?.uid else { return }
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
        guard let uid = Auth.auth().currentUser?.uid else { return }
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

    func saveProfile(_ profile: EditableProfile) {
        editableProfile = profile
        lastProfileSavedAt = Date()
        // Firestore /users/{uid} 영속화 — Cloud Function updateProfile callable로 위임 (서버 측 검증 + 일관 schema).
        // 핸들 변경은 별도 setHandle callable로 분리 (uniqueness check + reservation 보호).
        Task { [weak self, profile] in
            let region = "asia-northeast3"
            do {
                let updateCallable = Functions.functions(region: region).httpsCallable("updateProfile")
                _ = try await updateCallable.call([
                    "displayName": profile.displayName,
                    "bio": profile.bio,
                    "website": profile.website,
                    "makerPageVisible": profile.makerPageVisible,
                    "photoSharingAllowed": profile.photoSharingAllowed,
                    "avatarVariant": profile.avatarVariant
                ] as [String: Any])
                if !profile.handle.isEmpty {
                    let handleCallable = Functions.functions(region: region).httpsCallable("setHandle")
                    _ = try await handleCallable.call(["handle": profile.handle])
                }
            } catch {
                // (#47) silent failure 제거 — 사용자 알림 surface.
                await MainActor.run { [weak self] in
                    self?.lastSubmitErrorMessage = "프로필 저장 실패: \(error.localizedDescription)"
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
        let uid = Auth.auth().currentUser?.uid
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
        guard let index = makerFilters.firstIndex(where: { $0.id == draft.id }) else { return }
        makerFilters[index].status = .draft
        makerFilters[index].updatedAt = Date()
    }

    private func upsertMakerFilter(_ draft: MakerFilterDraft) {
        if let index = makerFilters.firstIndex(where: { $0.id == draft.id }) {
            makerFilters[index] = draft
        } else {
            makerFilters.insert(draft, at: 0)
        }
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
