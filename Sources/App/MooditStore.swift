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

    /// Preview / Xcode SwiftUI Preview 전용 — 실제 앱에서는 사용하지 않음.
    static let preview = EditableProfile(
        displayName: "강지수",
        handle: "jisoo.films",
        bio: "필름 카메라와 햇빛을 좋아합니다. 카페·여행·일상 위주로 필터를 만들어요.",
        website: "https://jisoo.films",
        makerPageVisible: true,
        photoSharingAllowed: false,
        avatarVariant: 0
    )

    /// 비로그인 / 로딩 중 placeholder. 실제 displayName/handle 은 Firebase Auth + Firestore 에서 채워짐.
    static let empty = EditableProfile(
        displayName: "",
        handle: "",
        bio: "",
        website: "",
        makerPageVisible: true,
        photoSharingAllowed: false,
        avatarVariant: 0
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
        case .profile: "표시 이름, 핸들, 바이오, 링크"
        case .marketplace: "다운로드, 좋아요, 리뷰, 댓글"
        case .wallet: "Coin 잔액, 주문, 환불 요청"
        case .activity: "검색, 알림, 설정 변경 이력"
        }
    }
}

struct DataExportRequest: Identifiable, Equatable {
    let id = UUID()
    let categories: Set<DataExportCategory>
    let format: DataExportFormat
    let requestedAt: Date
    var status: String

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
    var beforeAfterEnabled: Bool
    var tosOriginal: Bool
    var tosPolicy: Bool
    var tosCommercial: Bool
    var status: MakerFilterStatus
    var updatedAt: Date
    var submittedAt: Date?

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
    @Published var editableProfile = EditableProfile.empty
    @Published var lastProfileSavedAt: Date?
    @Published var accountDeletionRequestedAt: Date?
    @Published var selectedExportCategories: Set<DataExportCategory> = Set(DataExportCategory.allCases)
    @Published var selectedExportFormat: DataExportFormat = .json
    /// 데이터 내보내기 요청 이력 — 진짜 데이터는 Firestore /users/{uid}/exportRequests에서 들어와야 함.
    /// (이전: 2개 하드코딩 mock 잔재 — 사용자가 요청한 적 없는 export 이력이 노출되는 문제 해결)
    @Published var exportRequests: [DataExportRequest] = []
    @Published var notificationPreferences = NotificationPreferences()
    @Published var editorDraft = MakerFilterDraft.preview
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
    private var authStateHandle: AuthStateDidChangeListenerHandle?
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
        guard authStateHandle == nil else { return } // idempotent
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.attachWalletListeners(uid: user?.uid)
        }
    }

    private func attachWalletListeners(uid: String?) {
        walletListener?.remove()
        proStatusListener?.remove()
        userDocListener?.remove()
        walletListener = nil
        proStatusListener = nil
        userDocListener = nil

        guard let uid else {
            coinBalance = 0
            isProActive = false
            editableProfile = .empty
            return
        }
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
                avatarVariant: editableProfile.avatarVariant
            )
        }
        walletListener = db.collection("users").document(uid)
            .collection("wallet").document("balance")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let value = (snapshot?.data()?["value"] as? Int) ?? 0
                self.coinBalance = value
            }
        proStatusListener = db.collection("users").document(uid)
            .collection("proStatus").document("status")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let active = (snapshot?.data()?["active"] as? Bool) ?? false
                self.isProActive = active
            }
        userDocListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                guard let data = snapshot?.data() else { return }
                self.editableProfile = EditableProfile(
                    displayName: (data["displayName"] as? String) ?? self.editableProfile.displayName,
                    handle: (data["handle"] as? String) ?? self.editableProfile.handle,
                    bio: (data["bio"] as? String) ?? self.editableProfile.bio,
                    website: (data["website"] as? String) ?? self.editableProfile.website,
                    makerPageVisible: (data["makerPageVisible"] as? Bool) ?? self.editableProfile.makerPageVisible,
                    photoSharingAllowed: (data["photoSharingAllowed"] as? Bool) ?? self.editableProfile.photoSharingAllowed,
                    avatarVariant: (data["avatarVariant"] as? Int) ?? self.editableProfile.avatarVariant
                )
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

    func select(_ filter: Filter) {
        selectedFilterID = filter.id
        downloadedFilterIDs.insert(filter.id)
    }

    func download(_ filter: Filter) {
        downloadedFilterIDs.insert(filter.id)
    }

    func removeDownload(_ filter: Filter) {
        downloadedFilterIDs.remove(filter.id)
        favoriteFilterIDs.remove(filter.id)
        if selectedFilterID == filter.id {
            selectedFilterID = libraryFilters.first?.id ?? filters.first?.id
        }
    }

    func toggleFavorite(_ filter: Filter) {
        if favoriteFilterIDs.contains(filter.id) {
            favoriteFilterIDs.remove(filter.id)
        } else {
            favoriteFilterIDs.insert(filter.id)
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

    func saveProfile(_ profile: EditableProfile) {
        editableProfile = profile
        lastProfileSavedAt = Date()
        // Firestore /users/{uid} 영속화 — Cloud Function updateProfile callable로 위임 (서버 측 검증 + 일관 schema).
        // 핸들 변경은 별도 setHandle callable로 분리 (uniqueness check + reservation 보호).
        Task.detached { [profile] in
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
                // 실패해도 로컬 store는 갱신된 상태 유지 — 다음 진입 시 Firestore listener가 정정.
            }
        }
    }

    func markAccountDeletionRequested() {
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
        let request = DataExportRequest(
            categories: selectedExportCategories,
            format: selectedExportFormat,
            requestedAt: Date(),
            status: "요청됨"
        )
        exportRequests.insert(request, at: 0)
    }

    func resetEditorDraft() {
        editorDraft = MakerFilterDraft.preview
        uploadStep = .cover
    }

    func updateEditorParameter(_ key: String, value: Double) {
        editorDraft.parameterValues[key] = value
        editorDraft.updatedAt = Date()
    }

    func setEditorLUT(_ fileName: String) {
        editorDraft.lutFileName = fileName
        editorDraft.updatedAt = Date()
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
