import DesignSystem
import FirebaseFunctions
import Models
import SwiftUI

/// 필터 상세 진입 시 Cloud Function `getFilterDetail` 을 호출해 필터 메타데이터 +
/// 서명된 R2 다운로드 URL을 가져오고, 성공 시 `FilterDetailScreen`을 렌더링.
///
/// 로딩 / 빈 상태 / 에러 분기를 책임지며, 화면의 mock 의존을 최종적으로 떼어내기 위한
/// 어댑터 역할. (US-S1-05 acceptance 의 "loading + empty + error states" 충족)
struct FilterDetailLoaderScreen: View {
    let filterId: String

    @EnvironmentObject private var store: MooditStore
    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                // 깜빡임 방지 (#21): store.filters에 동일 ID가 있으면 .loading 단계에서도 즉시 렌더.
                if let local = synchronousLocalFilter {
                    FilterDetailScreen(filter: local)
                } else {
                    loadingView
                }
            case .loaded(let detail):
                FilterDetailScreen(mock: detail.toMock())
            case .localFilter(let filter):
                FilterDetailScreen(filter: filter)
            case .empty:
                FMEmptyState(.emptyMarket)
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

    /// 동기적으로 store.filters에서 매칭되는 필터를 즉시 반환. 번들 시드/이미 로드된 데이터 진입 시
    /// .loading 단계에서도 ProgressView 깜빡임 없이 즉시 렌더링하기 위한 fast-path.
    private var synchronousLocalFilter: Models.Filter? {
        guard let uuid = UUID(uuidString: filterId) else { return nil }
        return store.filters.first(where: { $0.id == uuid })
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
        // Local fast-path: 번들/인메모리 store.filters 에 있는 필터면 즉시 사용 (테스트/오프라인 호환).
        if let uuid = UUID(uuidString: filterId),
           let local = store.filters.first(where: { $0.id == uuid }) {
            phase = .localFilter(local)
            return
        }
        do {
            let detail = try await Self.fetchDetail(filterId: filterId)
            phase = .loaded(detail)
        } catch let error as NSError where error.domain == FunctionsErrorDomain
            && error.code == FunctionsErrorCode.notFound.rawValue {
            phase = .empty
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// 실제 Cloud Function 호출. 테스트 가능하도록 static — 추후 의존성 주입으로 분리 가능.
    static func fetchDetail(filterId: String) async throws -> FilterDetailResponse {
        let callable = Functions.functions(region: "asia-northeast3")
            .httpsCallable("getFilterDetail")
        let result = try await callable.call(["filterId": filterId])
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
    let reviews: [ReviewPreview]
    let signedDownloadURL: URL
    let expiresAt: Date

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
              let title = filterDict["title"] as? String,
              let signedURLString = dict["signedDownloadURL"] as? String,
              let signedURL = URL(string: signedURLString) else {
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
        self.signedDownloadURL = signedURL
        let expiresAtSeconds = (dict["expiresAt"] as? Double) ?? 0
        self.expiresAt = Date(timeIntervalSince1970: expiresAtSeconds)
    }

    /// 응답 → 기존 `FilterDetailMock` 으로 매핑. FilterDetailScreen 의 mock-기반 렌더링을
    /// 그대로 재사용하기 위한 어댑터.
    func toMock() -> FilterDetailMock {
        let initials = String(authorDisplayName.prefix(2)).uppercased()
        let filterCategory = FilterCategory(rawValue: category) ?? .cinematic
        let displayDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return FilterDetailMock(
            sourceID: id,
            displayTitle: title,
            makerHandle: "@\(authorDisplayName)",
            makerInitials: initials,
            categoryLabel: priceCoins > 0 ? "유료 필터 · \(priceCoins) 코인" : "무료 필터",
            downloadCount: downloadCount > 0 ? downloadCount : useCount,
            rating: ratingAvg ?? 0,
            reviewCount: reviewCount,
            likeCount: likeCount,
            description: displayDescription.isEmpty ? "필터 설명이 아직 없습니다." : displayDescription,
            tags: tags.map { $0.hasPrefix("#") ? $0 : "#\($0)" },
            coverURL: coverURL,
            signatureSampleURL: signatureSampleURL,
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
            priceLabel: priceCoins > 0 ? "\(priceCoins) 코인" : nil
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
