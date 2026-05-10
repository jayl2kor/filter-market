import Foundation
import Models

enum CameraTimerOption: Int, CaseIterable, Identifiable, Hashable {
    case off = 0
    case three = 3
    case five = 5
    case ten = 10

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .off: "OFF"
        case .three: "3s"
        case .five: "5s"
        case .ten: "10s"
        }
    }
}

enum EditorReferenceSampleKind: String, CaseIterable, Identifiable, Hashable, Codable {
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
    var avatarURL: URL?

    /// Preview / Xcode SwiftUI Preview 전용 — 실제 앱에서는 사용하지 않음.
    static let preview = EditableProfile(
        displayName: "강지수",
        handle: "sample.maker",
        bio: "필름 카메라와 햇빛을 좋아합니다. 카페·여행·일상 위주로 필터를 만들어요.",
        website: "https://example.com",
        makerPageVisible: true,
        photoSharingAllowed: false,
        avatarVariant: 0,
        avatarImageData: nil,
        avatarURL: nil
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
        avatarImageData: nil,
        avatarURL: nil
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

    /// Parameter keys whose sliders belong to this section.
    /// `.lut` returns `[]` because the LUT section uses dedicated controls instead of sliders.
    /// The union of all non-`.lut` cases is the canonical set of slider parameters.
    var parameterKeys: [String] {
        switch self {
        case .lighting: ["exposure", "contrast"]
        case .color: ["saturation"]
        case .detail: ["grain"]
        case .effects: ["vignette"]
        case .lut: []
        }
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

enum MakerFilterStatus: String, CaseIterable, Identifiable, Codable {
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

struct MakerFilterDraft: Identifiable, Equatable, Codable {
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
    var rejectionReasons: [RejectionReason]?
    var moderatorNote: String?
    var rejectedAt: Date?
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
        submittedAt: nil,
        rejectionReasons: nil,
        moderatorNote: nil,
        rejectedAt: nil
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

    var hasUserContent: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !tags.isEmpty
            || !parameterValues.isEmpty
            || lutFileName != nil
            || coverCount > 0
            || signatureSampleKind != nil
            || signatureSamplePhotoData != nil
            || beforeAfterEnabled
            || tosOriginal
            || tosPolicy
            || tosCommercial
            || firestoreFilterId != nil
    }
}
