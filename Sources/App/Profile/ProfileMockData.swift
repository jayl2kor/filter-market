import DesignSystem
import Foundation
import SwiftUI

// MARK: - ProfileUser

/// Profile 화면 표시용 mock 사용자 모델.
///
/// 실제 API 도입 전 시각 통합용. `Models.User` 와 분리해 디자인 시스템 친화적인 표시 데이터만 보유.
struct ProfileUser: Sendable {
    let displayName: String
    let handle: String
    let bio: String
    let avatarInitials: String
    let avatarURL: URL?
    let filterCount: Int
    let followerCount: Int
    let followingCount: Int
    let isOwnProfile: Bool
}

// MARK: - ProfileUserSeed

/// 프로필 화면에 즉시 보여줄 수 있는 사전 정보 — `Filter.author` 처럼 호출지에서 이미 알고 있는 식별 정보를
/// Firestore 응답 이전/누락 시 채우기 위해 사용. Hashable: `AppRoute` 가 NavigationStack 의 hashable
/// 식별자로 사용되므로 필요.
struct ProfileUserSeed: Hashable, Sendable {
    let displayName: String?
    let handle: String?
    let avatarURL: URL?
    let avatarInitials: String?
}

extension ProfileUser {
    static let preview = ProfileUser(
        displayName: "강지수",
        handle: "@sample.maker",
        bio: "필름 카메라가 추억이 된 시대,\n디지털 위에 빛을 그립니다.",
        avatarInitials: "JS",
        avatarURL: nil,
        filterCount: 24,
        followerCount: 1_240,
        followingCount: 86,
        isOwnProfile: true
    )

    static let other = ProfileUser(
        displayName: "Alex Lab",
        handle: "@alex.lab",
        bio: "Color science / film emulation.",
        avatarInitials: "AL",
        avatarURL: nil,
        filterCount: 18,
        followerCount: 2_400,
        followingCount: 142,
        isOwnProfile: false
    )

    static let empty = ProfileUser(
        displayName: "신규 메이커",
        handle: "@newcomer",
        bio: "이제 막 시작한 메이커입니다.",
        avatarInitials: "NC",
        avatarURL: nil,
        filterCount: 0,
        followerCount: 0,
        followingCount: 12,
        isOwnProfile: true
    )
}

// MARK: - ProfileGridItem

/// 프로필 그리드 1셀.
struct ProfileGridItem: Identifiable, Sendable {
    enum Kind: Sendable {
        case filter
        case capture
    }

    let id: String
    let title: String
    let routeId: String
    let kind: Kind
    let downloadCount: Int
    let categoryHint: Color

    init(
        id: String = UUID().uuidString,
        title: String,
        routeId: String? = nil,
        kind: Kind = .filter,
        downloadCount: Int,
        categoryHint: Color
    ) {
        self.id = id
        self.title = title
        self.routeId = routeId ?? id
        self.kind = kind
        self.downloadCount = downloadCount
        self.categoryHint = categoryHint
    }
}

// MARK: - ProfileMockData

/// Profile 화면 — Phase D3 mock 표시 데이터.
enum ProfileMockData {
    static let myFilters: [ProfileGridItem] = [
        .init(title: "Sample Film", downloadCount: 2_400, categoryHint: FMColors.Category.vintage),
        .init(title: "Mono Soft", downloadCount: 1_800, categoryHint: FMColors.Category.monochrome),
        .init(title: "Teal Story", downloadCount: 3_100, categoryHint: FMColors.Category.cinematic),
        .init(title: "Honey Glow", downloadCount: 980, categoryHint: FMColors.Category.food),
        .init(title: "Cold Blue", downloadCount: 1_200, categoryHint: FMColors.Category.travel),
        .init(title: "Midnight", downloadCount: 540, categoryHint: FMColors.Category.mood),
        .init(title: "Pastel Air", downloadCount: 2_000, categoryHint: FMColors.Category.pastel),
        .init(title: "Skin Glow", downloadCount: 3_600, categoryHint: FMColors.Category.portrait),
        .init(title: "Mountain", downloadCount: 720, categoryHint: FMColors.Category.travel),
        .init(title: "Cafe Cream", downloadCount: 1_140, categoryHint: FMColors.Category.food),
        .init(title: "Indigo Mood", downloadCount: 870, categoryHint: FMColors.Category.mood),
        .init(title: "Soft Portra", downloadCount: 4_120, categoryHint: FMColors.Category.portrait)
    ]

    static let saved: [ProfileGridItem] = [
        .init(title: "Velvet Dusk", downloadCount: 6_320, categoryHint: FMColors.Category.cinematic),
        .init(title: "Golden Hour", downloadCount: 1_240, categoryHint: FMColors.Category.vintage),
        .init(title: "Mint Note", downloadCount: 1_510, categoryHint: FMColors.Category.pastel),
        .init(title: "Seoul Night", downloadCount: 3_980, categoryHint: FMColors.Category.mood),
        .init(title: "Airy Trip", downloadCount: 6_510, categoryHint: FMColors.Category.travel),
        .init(title: "Skin Bloom", downloadCount: 880, categoryHint: FMColors.Category.portrait)
    ]

    static let captures: [ProfileGridItem] = [
        .init(title: "촬영 1", downloadCount: 0, categoryHint: FMColors.Category.cinematic),
        .init(title: "촬영 2", downloadCount: 0, categoryHint: FMColors.Category.vintage),
        .init(title: "촬영 3", downloadCount: 0, categoryHint: FMColors.Category.travel),
        .init(title: "촬영 4", downloadCount: 0, categoryHint: FMColors.Category.portrait),
        .init(title: "촬영 5", downloadCount: 0, categoryHint: FMColors.Category.mood)
    ]
}
