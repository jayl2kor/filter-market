import Foundation
import FilterEngine
import Marketplace
import Models

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

    static let preview = EditableProfile(
        displayName: "강지수",
        handle: "jisoo.films",
        bio: "필름 카메라와 햇빛을 좋아합니다. 카페·여행·일상 위주로 필터를 만들어요.",
        website: "https://jisoo.films",
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
    var comments = true
    var marketplace = true
    var creator = true
    var wallet = true
    var product = false
    var quietHoursEnabled = true
    var quietStart = "22:00"
    var quietEnd = "07:00"
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
    @Published var editableProfile = EditableProfile.preview
    @Published var lastProfileSavedAt: Date?
    @Published var accountDeletionRequestedAt: Date?
    @Published var selectedExportCategories: Set<DataExportCategory> = Set(DataExportCategory.allCases)
    @Published var selectedExportFormat: DataExportFormat = .json
    @Published var exportRequests: [DataExportRequest] = [
        DataExportRequest(
            categories: Set(DataExportCategory.allCases),
            format: .json,
            requestedAt: Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date(),
            status: "만료"
        ),
        DataExportRequest(
            categories: [.account, .profile, .activity],
            format: .json,
            requestedAt: Calendar.current.date(byAdding: .hour, value: -7, to: Date()) ?? Date(),
            status: "처리 중"
        )
    ]
    @Published var notificationPreferences = NotificationPreferences()
    /// manifest 로드 실패 시 마지막 에러. UI 는 이 값을 보고 ErrorBanner / FMEmptyState 를 노출.
    @Published private(set) var loadError: Error?
    /// 로드 진행 상태. skeleton vs 에러 vs 빈 상태 분기에 사용.
    @Published private(set) var isLoading = false

    private let repository: any FilterRepository

    init(repository: any FilterRepository = BundleSeedFilterRepository()) {
        self.repository = repository
    }

    var selectedFilter: Filter? {
        guard let selectedFilterID else { return filters.first }
        return filters.first { $0.id == selectedFilterID }
    }

    var libraryFilters: [Filter] {
        filters.filter { downloadedFilterIDs.contains($0.id) }
    }

    func load() async {
        // 이미 정상 로드된 상태면 재호출 무시. 실패 후 retry 는 통과시킨다.
        guard filters.isEmpty else { return }

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
        } catch {
            loadError = error
            filters = []
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
