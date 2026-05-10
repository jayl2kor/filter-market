import DesignSystem
import Models
import SwiftUI

/// 필터 상세 진입 시 Cloud Function `getFilterDetail` 을 호출해 필터 메타데이터 +
/// 서명된 R2 다운로드 URL을 가져오고, 성공 시 `FilterDetailScreen`을 렌더링.
///
/// 로딩 / 빈 상태 / 에러 분기를 책임지며, 화면의 mock 의존을 최종적으로 떼어내기 위한
/// 어댑터 역할. (US-S1-05 acceptance 의 "loading + empty + error states" 충족)
struct FilterDetailLoaderScreen: View {
    let filterId: String

    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                loadingView
            case .loaded(let detail):
                FilterDetailScreen(mock: detail.toMock(), onRefresh: { await load() })
            case .localFilter(let filter):
                FilterDetailScreen(filter: filter)
            case .empty:
                FMEmptyState(.emptyMarket, ctaTitle: "다시 시도") {
                    Task { await load() }
                }
                    .padding(.horizontal, Sp.md)
            case .error(let message):
                errorView(message)
            }
        }
        .navigationTitle("필터 상세")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    /// 동기적으로 filterLibraryStore.filters에서 매칭되는 필터를 즉시 반환. 번들 시드/이미 로드된 데이터 진입 시
    /// .loading 단계에서도 ProgressView 깜빡임 없이 즉시 렌더링하기 위한 fast-path.
    private var synchronousLocalFilter: Models.Filter? {
        guard let uuid = UUID(uuidString: filterId) else { return nil }
        return filterLibraryStore.filters.first(where: { $0.id == uuid })
    }

    // MARK: - State machine

    enum Phase {
        case loading
        case loaded(FilterDetailResponse)
        case localFilter(Models.Filter)
        case empty
        case error(String)
    }

    private func load() async {
        phase = .loading
        var hasLocalFallback = false
        // Local fast-path: 번들/인메모리 filterLibraryStore.filters 에 있는 필터면 즉시 표시한 뒤,
        // production에서는 getFilterDetail 응답으로 샘플/리뷰/카운터를 갱신한다.
        if let uuid = UUID(uuidString: filterId),
           let local = filterLibraryStore.filters.first(where: { $0.id == uuid }) {
            phase = .localFilter(local)
            hasLocalFallback = true
            #if DEBUG
            if isUITesting {
                return
            }
            #endif
        }
        do {
            let detail = try await Self.fetchDetail(filterId: filterId)
            phase = .loaded(detail)
        } catch {
            guard !hasLocalFallback else { return }
            if FirebaseSideEffects.isFunctionNotFound(error) {
                phase = .empty
                return
            }
            phase = .error(error.localizedDescription)
        }
    }

    /// 실제 Cloud Function 호출. 테스트 가능하도록 static — 추후 의존성 주입으로 분리 가능.
    static func fetchDetail(filterId: String) async throws -> FilterDetailResponse {
        let result = try await FirebaseSideEffects.callFunction("getFilterDetail", data: ["filterId": filterId])
        guard let dict = result.data as? [String: Any] else {
            throw FilterDetailLoaderError.invalidPayload
        }
        return try FilterDetailResponse(json: dict)
    }

    // MARK: - Loading + error views

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Sp.md) {
            ProgressView()
                .controlSize(.large)
            Text("필터 정보를 불러오는 중…")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.Background.bg0)
        .accessibilityLabel("필터 로딩 중")
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: Sp.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(FMColors.Semantic.error)
            Text("필터를 불러오지 못했어요")
                .font(Font.fmHeadline)
                .foregroundStyle(FMColors.Text.primary)
            Text(message)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Sp.lg)
            FMButton("다시 시도", variant: .primary, size: .md) {
                Task { await load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Sp.md)
        .background(FMColors.Background.bg0)
        .accessibilityIdentifier("filter.detail.error")
    }
}

// MARK: - Response model

struct FilterDetailResponse {
    let id: String
    let title: String
    let description: String
    let category: String
    let status: String
    let useCount: Int
    let downloadCount: Int
    let priceCoins: Int
    let coverURL: URL?
    let signatureSampleURL: URL?
    let ratingAvg: Double?
    let reviewCount: Int
    let likeCount: Int
    let sampleCount: Int
    let tags: [String]
    let createdAt: Date?
    let authorUid: String
    let authorDisplayName: String
    let authorAvatarURL: URL?
    let samples: [SamplePreview]
    let reviews: [ReviewPreview]
    let userHasLiked: Bool
    let signedDownloadURL: URL?
    let packageSHA256: String?
    let expiresAt: Date?
    let paywall: Bool

    struct SamplePreview {
        let id: String
        let kind: String
        let categoryHint: String?
        let coverURL: URL?
        let thumbnailURL: URL?
    }

    struct ReviewPreview {
        let authorDisplayName: String
        let stars: Int
        let body: String
        let isVerifiedDownload: Bool
        let createdAt: Date?
    }

    init(json dict: [String: Any]) throws {
        guard let filterDict = dict["filter"] as? [String: Any] else {
            throw FilterDetailLoaderError.invalidPayload
        }
        guard let id = filterDict["id"] as? String,
              let title = filterDict["title"] as? String else {
            throw FilterDetailLoaderError.invalidPayload
        }

        self.id = id
        self.title = title
        self.description = (filterDict["description"] as? String) ?? ""
        self.category = (filterDict["category"] as? String) ?? "cinematic"
        self.status = (filterDict["status"] as? String) ?? "approved"
        self.useCount = (filterDict["useCount"] as? Int) ?? 0
        self.downloadCount = (filterDict["downloadCount"] as? Int) ?? 0
        self.priceCoins = (filterDict["priceCoins"] as? Int) ?? 0
        self.coverURL = (filterDict["coverURL"] as? String).flatMap { URL(string: $0) }
        self.signatureSampleURL = (filterDict["signatureSampleURL"] as? String).flatMap { URL(string: $0) }
        self.ratingAvg = filterDict["ratingAvg"] as? Double
        self.reviewCount = (filterDict["reviewCount"] as? Int) ?? 0
        self.likeCount = (filterDict["likeCount"] as? Int) ?? 0
        self.sampleCount = (filterDict["sampleCount"] as? Int) ?? 0
        self.tags = (filterDict["tags"] as? [String]) ?? []
        if let createdAtMs = filterDict["createdAt"] as? Double, createdAtMs > 0 {
            self.createdAt = Date(timeIntervalSince1970: createdAtMs / 1000)
        } else {
            self.createdAt = nil
        }
        let authorDict = (filterDict["author"] as? [String: Any]) ?? [:]
        self.authorUid = (authorDict["uid"] as? String) ?? "unknown"
        self.authorDisplayName = (authorDict["displayName"] as? String) ?? "Unknown"
        self.authorAvatarURL = Self.urlValue(
            authorDict["avatarURL"],
            authorDict["photoURL"],
            filterDict["authorAvatarURL"],
            filterDict["authorPhotoURL"]
        )
        self.samples = ((dict["samples"] as? [[String: Any]]) ?? []).compactMap { sampleDict in
            let coverURL = (sampleDict["coverURL"] as? String).flatMap { URL(string: $0) }
            let thumbnailURL = (sampleDict["thumbnailURL"] as? String).flatMap { URL(string: $0) }
            guard coverURL != nil || thumbnailURL != nil else { return nil }
            return SamplePreview(
                id: (sampleDict["id"] as? String) ?? UUID().uuidString,
                kind: (sampleDict["kind"] as? String) ?? "user",
                categoryHint: sampleDict["categoryHint"] as? String,
                coverURL: coverURL,
                thumbnailURL: thumbnailURL
            )
        }
        self.reviews = ((dict["reviews"] as? [[String: Any]]) ?? []).map { reviewDict in
            let createdAt: Date?
            if let createdAtMs = reviewDict["createdAt"] as? Double, createdAtMs > 0 {
                createdAt = Date(timeIntervalSince1970: createdAtMs / 1000)
            } else {
                createdAt = nil
            }
            return ReviewPreview(
                authorDisplayName: (reviewDict["authorDisplayName"] as? String) ?? "사용자",
                stars: (reviewDict["stars"] as? Int) ?? 0,
                body: (reviewDict["body"] as? String) ?? "",
                isVerifiedDownload: (reviewDict["isVerifiedDownload"] as? Bool) ?? false,
                createdAt: createdAt
            )
        }
        self.userHasLiked = (dict["userHasLiked"] as? Bool) ?? false
        if let signedURLString = dict["signedDownloadURL"] as? String,
           let signedURL = URL(string: signedURLString) {
            self.signedDownloadURL = signedURL
        } else {
            self.signedDownloadURL = nil
        }
        self.packageSHA256 = Self.stringValue(
            dict["packageSHA256"],
            dict["contentSha256"],
            filterDict["packageSHA256"],
            filterDict["contentSha256"],
            filterDict["sha256"]
        )
        if let expiresAtSeconds = dict["expiresAt"] as? Double, expiresAtSeconds > 0 {
            self.expiresAt = Date(timeIntervalSince1970: expiresAtSeconds)
        } else {
            self.expiresAt = nil
        }
        self.paywall = (dict["paywall"] as? Bool) ?? false
    }

    private static func stringValue(_ values: Any?...) -> String? {
        for value in values {
            if let string = value as? String,
               !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return string
            }
        }
        return nil
    }

    private static func urlValue(_ values: Any?...) -> URL? {
        for value in values {
            if let string = value as? String,
               let url = URL(string: string) {
                return url
            }
        }
        return nil
    }

    /// 응답 → 기존 `FilterDetailMock` 으로 매핑. FilterDetailScreen 의 mock-기반 렌더링을
    /// 그대로 재사용하기 위한 어댑터.
    func toMock() -> FilterDetailMock {
        let initials = String(authorDisplayName.prefix(2)).uppercased()
        let filterCategory = FilterCategory(rawValue: category) ?? .cinematic
        let displayDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return FilterDetailMock(
            sourceID: id,
            makerUID: authorUid,
            displayTitle: title,
            makerHandle: "@\(authorDisplayName)",
            makerInitials: initials,
            makerAvatarURL: authorAvatarURL,
            categoryLabel: priceCoins > 0 ? "유료 필터 · \(priceCoins) 코인" : "무료 필터",
            downloadCount: downloadCount,
            rating: ratingAvg ?? 0,
            reviewCount: reviewCount,
            likeCount: likeCount,
            description: displayDescription.isEmpty ? "필터 설명이 아직 없습니다." : displayDescription,
            tags: tags.map { $0.hasPrefix("#") ? $0 : "#\($0)" },
            coverURL: coverURL,
            signatureSampleURL: signatureSampleURL,
            samples: samples.compactMap { sample in
                guard let imageURL = sample.coverURL ?? sample.thumbnailURL else { return nil }
                return FilterDetailMock.Sample(
                    id: sample.id,
                    kind: sample.kind,
                    title: sample.kind == "signature" ? "시그니처" : "사용자 샘플",
                    imageURL: imageURL,
                    thumbnailURL: sample.thumbnailURL,
                    categoryHint: sample.categoryHint
                )
            },
            filterCategory: filterCategory,
            reviews: reviews.map { review in
                FilterDetailMock.Review(
                    initials: String(review.authorDisplayName.prefix(2)).uppercased(),
                    avatarTint: FMColors.Category.portrait,
                    name: review.authorDisplayName,
                    timeAgo: review.createdAt.map(Self.relativeTimeString) ?? "방금",
                    body: review.body,
                    stars: review.stars,
                    isVerifiedDownload: review.isVerifiedDownload
                )
            },
            categoryHint: filterCategory.swatch.first ?? FMColors.Category.cinematic,
            isPaid: priceCoins > 0,
            priceLabel: priceCoins > 0 ? "\(priceCoins) 코인" : nil,
            userHasLiked: userHasLiked
        )
    }

    private static func relativeTimeString(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "방금" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)분" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)시간" }
        return "\(hours / 24)일"
    }
}

enum FilterDetailLoaderError: Error, LocalizedError {
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidPayload: "잘못된 응답 형식입니다."
        }
    }
}
