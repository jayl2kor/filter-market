import DesignSystem
import Foundation
import Models
import SwiftUI

#if DEBUG

// MARK: - MarketplaceMockData

/// 마켓 화면 — Phase D3 mock 표시 데이터.
///
/// 실제 API 연결 전 시각 통합용 임시 데이터.
/// `FMFilterTileData` 와 메이커/카테고리 칩은 도메인 모델 (`Filter`) 와 매핑되지 않은 별도 객체로 유지한다.
enum MarketplaceMockData {
    // MARK: Trending (가로 캐러셀)

    static let trending: [FMFilterTileData] = [
        FMFilterTileData(
            title: "Teal Story",
            makerName: "@alex.lab",
            downloadCount: 12_400,
            priceLabel: nil,
            categoryHint: FMColors.Category.cinematic
        ),
        FMFilterTileData(
            title: "Sample Film",
            makerName: "@sample.maker",
            downloadCount: 9_800,
            priceLabel: nil,
            categoryHint: FMColors.Category.vintage
        ),
        FMFilterTileData(
            title: "Midnight Walk",
            makerName: "@noon.studio",
            downloadCount: 2_100,
            priceLabel: nil,
            categoryHint: FMColors.Category.mood
        ),
        FMFilterTileData(
            title: "Velvet Dusk",
            makerName: "유나",
            downloadCount: 6_320,
            priceLabel: "₩2,900",
            categoryHint: FMColors.Category.cinematic
        )
    ]

    // MARK: Categories (가로 칩)

    static let categories: [String] = [
        "전체",
        "Cinematic",
        "Vintage",
        "Pastel",
        "B&W",
        "Portrait",
        "Food",
        "Travel",
        "Mood"
    ]

    // MARK: New filters (그리드)

    static let newFilters: [FMFilterTileData] = [
        FMFilterTileData(
            title: "Honey Glow",
            makerName: "@warm.house",
            downloadCount: 3_200,
            priceLabel: nil,
            categoryHint: FMColors.Category.food
        ),
        FMFilterTileData(
            title: "Cold Blue 02",
            makerName: "@noon.studio",
            downloadCount: 1_800,
            priceLabel: nil,
            categoryHint: FMColors.Category.travel
        ),
        FMFilterTileData(
            title: "Mono Soft",
            makerName: "@sample.maker",
            downloadCount: 5_100,
            priceLabel: nil,
            categoryHint: FMColors.Category.monochrome
        ),
        FMFilterTileData(
            title: "Pastel Air",
            makerName: "@air.films",
            downloadCount: 2_000,
            priceLabel: "₩1,500",
            categoryHint: FMColors.Category.pastel
        ),
        FMFilterTileData(
            title: "Cafe Cream",
            makerName: "Nora",
            downloadCount: 4_320,
            priceLabel: nil,
            categoryHint: FMColors.Category.food
        ),
        FMFilterTileData(
            title: "Soft Portra",
            makerName: "Mina",
            downloadCount: 7_840,
            priceLabel: nil,
            categoryHint: FMColors.Category.portrait
        ),
        FMFilterTileData(
            title: "Seoul Night",
            makerName: "Joon",
            downloadCount: 3_980,
            priceLabel: "₩2,500",
            categoryHint: FMColors.Category.mood
        ),
        FMFilterTileData(
            title: "Airy Trip",
            makerName: "Leo",
            downloadCount: 6_510,
            priceLabel: nil,
            categoryHint: FMColors.Category.travel
        ),
        FMFilterTileData(
            title: "Golden Hour",
            makerName: "@warm.house",
            downloadCount: 1_240,
            priceLabel: nil,
            categoryHint: FMColors.Category.vintage
        ),
        FMFilterTileData(
            title: "Skin Bloom",
            makerName: "@portra.note",
            downloadCount: 880,
            priceLabel: nil,
            categoryHint: FMColors.Category.portrait
        ),
        FMFilterTileData(
            title: "Indigo Mood",
            makerName: "@studio.paper",
            downloadCount: 2_750,
            priceLabel: "₩1,900",
            categoryHint: FMColors.Category.mood
        ),
        FMFilterTileData(
            title: "Mint Note",
            makerName: "@air.films",
            downloadCount: 1_510,
            priceLabel: nil,
            categoryHint: FMColors.Category.pastel
        )
    ]

    // MARK: Curated collections

    static let collections: [CollectionEntry] = [
        CollectionEntry(
            title: "시네마 다이어리",
            subtitle: "영화 같은 순간을 위한 12종",
            symbols: ["film", "rectangle.stack", "moon.stars"],
            tint: FMColors.Category.cinematic
        ),
        CollectionEntry(
            title: "필름 한 통",
            subtitle: "아날로그의 결을 담은 8종",
            symbols: ["camera.aperture", "sparkles", "sun.max"],
            tint: FMColors.Category.vintage
        )
    ]

    struct CollectionEntry: Identifiable, Sendable {
        let id = UUID()
        let title: String
        let subtitle: String
        let symbols: [String]
        let tint: Color
    }
}

#endif

// MARK: - FilterDetail mock

/// 상세 화면 mock — `Filter` 도메인 모델만으로는 부족한 표시 정보(다운로드/리뷰/태그/샘플/댓글)를 보강.
struct FilterDetailMock: Sendable {
    let sourceID: String?
    let displayTitle: String
    let makerHandle: String
    let makerInitials: String
    let categoryLabel: String
    let downloadCount: Int
    let rating: Double
    let reviewCount: Int
    let likeCount: Int
    let description: String
    let tags: [String]
    let coverURL: URL?
    let signatureSampleURL: URL?
    let samples: [Sample]
    let filterCategory: FilterCategory
    let reviews: [Review]
    let categoryHint: Color
    let isPaid: Bool
    let priceLabel: String?

    init(
        sourceID: String? = nil,
        displayTitle: String,
        makerHandle: String,
        makerInitials: String,
        categoryLabel: String,
        downloadCount: Int,
        rating: Double,
        reviewCount: Int,
        likeCount: Int,
        description: String,
        tags: [String],
        coverURL: URL?,
        signatureSampleURL: URL?,
        samples: [Sample] = [],
        filterCategory: FilterCategory,
        reviews: [Review],
        categoryHint: Color,
        isPaid: Bool,
        priceLabel: String?
    ) {
        self.sourceID = sourceID
        self.displayTitle = displayTitle
        self.makerHandle = makerHandle
        self.makerInitials = makerInitials
        self.categoryLabel = categoryLabel
        self.downloadCount = downloadCount
        self.rating = rating
        self.reviewCount = reviewCount
        self.likeCount = likeCount
        self.description = description
        self.tags = tags
        self.coverURL = coverURL
        self.signatureSampleURL = signatureSampleURL
        self.samples = samples
        self.filterCategory = filterCategory
        self.reviews = reviews
        self.categoryHint = categoryHint
        self.isPaid = isPaid
        self.priceLabel = priceLabel
    }

    struct Review: Identifiable, Sendable {
        let id = UUID()
        let initials: String
        let avatarTint: Color
        let name: String
        let timeAgo: String
        let body: String
        let stars: Int
        let isVerifiedDownload: Bool
    }

    struct Sample: Identifiable, Equatable, Sendable {
        let id: String
        let kind: String
        let title: String
        let imageURL: URL
        let thumbnailURL: URL?
        let categoryHint: String?
    }
}

extension FilterDetailMock {
    /// 샘플 default — 화면 단독 Preview / placeholder 용.
    static let preview = FilterDetailMock(
        displayTitle: "Sample Film",
        makerHandle: "@sample.maker",
        makerInitials: "SM",
        categoryLabel: "빈티지 · 시네마틱",
        downloadCount: 9_800,
        rating: 4.8,
        reviewCount: 324,
        likeCount: 2_100,
        description: "73년 코닥 필름의 따뜻한 황혼을 담았습니다. 카페 조명, 골목길 가로등, 노을이 깔리는 시간에 가장 잘 어울려요. 인물 피부톤은 자연스럽게 살리되 배경은 한 단계 깊은 톤으로.",
        tags: ["#warm", "#golden-hour", "#film", "#cafe", "#analog"],
        coverURL: nil,
        signatureSampleURL: nil,
        filterCategory: .vintage,
        reviews: [
            Review(
                initials: "SJ",
                avatarTint: FMColors.Category.travel,
                name: "soojin_92",
                timeAgo: "3시간",
                body: "와 카페 사진에 너무 잘 어울려요. 강도 60%로 쓰니까 자연스럽고 좋네요.",
                stars: 5,
                isVerifiedDownload: true
            ),
            Review(
                initials: "MJ",
                avatarTint: FMColors.Category.vintage,
                name: "minjun.shoots",
                timeAgo: "1일",
                body: "필름 디테일이 살아있어요. 인물에 적용해도 피부톤이 안 죽음.",
                stars: 4,
                isVerifiedDownload: true
            ),
            Review(
                initials: "HY",
                avatarTint: FMColors.Category.portrait,
                name: "hyeona.k",
                timeAgo: "3일",
                body: "골든아워에 정말 찰떡! 강도 살짝 낮춰서 일상 사진에도 잘 써요.",
                stars: 5,
                isVerifiedDownload: false
            )
        ],
        categoryHint: FMColors.Category.vintage,
        isPaid: false,
        priceLabel: nil
    )

    /// 도메인 `Filter` 와 결합하기 전, mock 매핑.
    static func mock(for filter: Filter) -> FilterDetailMock {
        FilterDetailMock(
            sourceID: filter.id.uuidString,
            displayTitle: filter.title,
            makerHandle: "@" + filter.author.displayName.lowercased(),
            makerInitials: String(filter.author.displayName.prefix(2)).uppercased(),
            categoryLabel: filter.category.displayTitle,
            downloadCount: 4_280,
            rating: 4.6,
            reviewCount: 152,
            likeCount: 980,
            description: "메이커가 직접 조정한 톤커브로, 일상의 순간을 한 단계 더 풍부한 분위기로 끌어올립니다. 강도 60~80%에서 가장 자연스럽게 어울려요.",
            tags: ["#mood", "#golden", "#warm", "#daily"],
            coverURL: filter.coverURL,
            signatureSampleURL: filter.signatureSampleURL,
            filterCategory: filter.category,
            reviews: [],
            categoryHint: filter.category.swatch.first ?? FMColors.Category.cinematic,
            isPaid: false,
            priceLabel: nil
        )
    }
}
