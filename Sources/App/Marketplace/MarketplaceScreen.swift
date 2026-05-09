import DesignSystem
import Foundation
import Models
import SwiftUI

// MARK: - MarketplaceScreen

/// 마켓 홈 — 6번 화면.
///
/// Phase D3 — `mockups/screens/06-marketplace-home.html` 와 정합.
/// 검색 헤더 + 인사 + 트렌딩 캐러셀 + 카테고리 칩 + 신규 그리드 + 큐레이션.
struct MarketplaceScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: MooditStore

    @State private var selectedCategory: String = "전체"
    @State private var hasAppeared = false
    @State private var prefetchedImageURLs: Set<URL> = []

    /// store.load() 가 끝났을 때 false 가 된다. 로딩 시는 skeleton.
    private var isLoading: Bool {
        !hasAppeared || (store.isLoading && store.filters.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Sp.lg) {
                    headerBar

                    greeting
                        .padding(.horizontal, Sp.md)

                    if let error = store.loadError, store.filters.isEmpty {
                        errorState(error)
                    } else if isLoading {
                        loadingState
                    } else {
                        loadedSections
                    }
                }
                .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
            }
            .refreshable {
                await store.load(force: true)
            }
            .background(FMColors.Background.bg0)
            .appRouteDestinations()
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            // 첫 진입 시 hasAppeared를 즉시 true — store.isLoading + 데이터 도착 여부로
            // skeleton/empty/content를 분기. (#18 hardcoded 350ms sleep 제거)
            hasAppeared = true
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: Sp.sm) {
            NavigationLink(value: AppRoute.search(initialQuery: nil, category: nil)) {
                HStack(spacing: Sp.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: IconSize.sm, weight: .medium))
                        .foregroundStyle(FMColors.Text.tertiary)
                    Text("필터, 메이커, 분위기 검색")
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.tertiary)
                    Spacer()
                }
                .padding(.horizontal, Sp.sm)
                .frame(height: 44)
                .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                .overlay {
                    RoundedRectangle(cornerRadius: R.md)
                        .strokeBorder(FMColors.Border.default, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            NavigationLink(value: AppRoute.wallet) {
                HStack(spacing: 4) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: IconSize.sm, weight: .semibold))
                        .foregroundStyle(FMColors.Accent.primary)
                    Text(store.coinBalance.formatted())
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                        .monospacedDigit()
                }
                .padding(.horizontal, Sp.sm)
                .frame(height: 44)
                .background(FMColors.Background.bg2, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("market.header.coinBalance")
            .accessibilityLabel("코인 잔액 \(store.coinBalance)개, 지갑 열기")

            NavigationLink(value: AppRoute.notifications) {
                Image(systemName: "bell")
                    .font(.system(size: IconSize.lg, weight: .regular))
                    .foregroundStyle(FMColors.Text.primary)
                    .frame(width: 44, height: 44)
                    .background(FMColors.Background.bg2, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("알림")
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.sm)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("오늘의 빛,")
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)
            (
                Text("지금 ")
                    .foregroundStyle(FMColors.Text.primary)
                + Text("만나보세요")
                    .foregroundStyle(FMColors.Accent.primary)
            )
            .fmTypography(.titleLarge)
        }
    }

    // MARK: - Loaded sections

    private var loadedSections: some View {
        VStack(alignment: .leading, spacing: Sp.lg) {
            trendingSection
            categoriesSection
            newFiltersSection
            collectionsSection
        }
        .onAppear {
            prefetchCovers(in: Array(store.trendingFilters.prefix(8)) + Array(filteredNewFilters.prefix(8)))
        }
    }

    // Trending carousel
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionHeader(title: "트렌딩", more: "더보기 →")
                .padding(.horizontal, Sp.md)

            if store.trendingFilters.isEmpty {
                FMEmptyState(.emptyMarket)
                    .padding(.horizontal, Sp.md)
                    .accessibilityIdentifier("market.trending.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Sp.sm) {
                        ForEach(Array(store.trendingFilters.enumerated()), id: \.element.id) { index, filter in
                            NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                                FeaturedCard(data: filter.toTileData(), isHighlighted: index == 0)
                                    .frame(width: 268)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                prefetchCovers(in: Array(store.trendingFilters.dropFirst(index + 1).prefix(8)))
                            }
                            .accessibilityIdentifier("market.trending.\(index)")
                        }
                    }
                    .padding(.horizontal, Sp.md)
                }
            }
        }
    }

    // Categories chip row
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionHeader(title: "카테고리", more: nil)
                .padding(.horizontal, Sp.md)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Sp.xs) {
                        ForEach(categoryChips, id: \.self) { category in
                            FMChip(
                                category,
                                isSelected: category == selectedCategory,
                                size: .sm
                            ) {
                                selectedCategory = category
                            }
                            .id(category)
                            .accessibilityIdentifier("market.category.\(category)")
                            .accessibilityValue(category == selectedCategory ? "선택됨" : "미선택")
                        }
                    }
                    .padding(.horizontal, Sp.md)
                }
                .onAppear {
                    proxy.scrollTo(selectedCategory, anchor: .center)
                }
                .onChange(of: selectedCategory) { _, category in
                    withAnimation(reduceMotion ? nil : .fmSpringSwipe) {
                        proxy.scrollTo(category, anchor: .center)
                    }
                }
            }
        }
    }

    // New filters grid
    private var newFiltersSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionHeader(title: "새로 들어온 필터", more: nil)
                .padding(.horizontal, Sp.md)

            if filteredNewFilters.isEmpty {
                FMEmptyState(.emptyMarket)
                    .padding(.horizontal, Sp.md)
                    .accessibilityIdentifier("market.new.empty")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Sp.sm),
                        GridItem(.flexible(), spacing: Sp.sm)
                    ],
                    spacing: Sp.sm
                ) {
                    ForEach(Array(filteredNewFilters.enumerated()), id: \.element.id) { index, filter in
                        NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                            FMFilterTile(data: filter.toTileData())
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            prefetchCovers(in: Array(filteredNewFilters.dropFirst(index + 1).prefix(8)))
                        }
                        .accessibilityIdentifier("market.tile.\(index)")
                    }
                }
                .padding(.horizontal, Sp.md)
            }
        }
    }

    // Curated collections — Firestore /collections 백엔드 미구현 시 UI 테스트에서만 mock 노출.
    // 프로덕션은 빈 목록일 때 섹션 자체를 숨김.
    @ViewBuilder
    private var collectionsSection: some View {
        #if DEBUG
        let entries = isUITesting ? MarketplaceMockData.collections : []
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: Sp.sm) {
                sectionHeader(title: "큐레이션 컬렉션", more: "전체 →")
                    .padding(.horizontal, Sp.md)

                VStack(spacing: Sp.sm) {
                    ForEach(entries) { collection in
                        NavigationLink(value: AppRoute.search(initialQuery: nil, category: collection.title)) {
                            CollectionCard(entry: collection)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("market.collection.\(collection.title)")
                    }
                }
                .padding(.horizontal, Sp.md)
            }
        }
        #endif
    }

    // MARK: - Error

    private func errorState(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            HStack(alignment: .top, spacing: Sp.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: IconSize.md, weight: .semibold))
                    .foregroundStyle(FMColors.Semantic.error)
                VStack(alignment: .leading, spacing: 2) {
                    Text("필터를 불러오지 못했어요")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(error.localizedDescription)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMColors.Semantic.errorBg)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(FMColors.Semantic.error.opacity(0.35), lineWidth: 1)
            }

            FMButton("다시 시도", variant: .primary, size: .md) {
                Task { await store.retry() }
            }
            .accessibilityIdentifier("market.loadError.retry")
        }
        .padding(.horizontal, Sp.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("필터 로드 실패")
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: Sp.lg) {
            // trending skeleton
            VStack(alignment: .leading, spacing: Sp.sm) {
                FMSkeleton.line(width: 80, height: 16)
                    .padding(.horizontal, Sp.md)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Sp.sm) {
                        ForEach(0..<3, id: \.self) { _ in
                            FMSkeleton.rect(width: 268, height: 200, cornerRadius: R.lg)
                        }
                    }
                    .padding(.horizontal, Sp.md)
                }
            }

            // grid skeleton
            VStack(alignment: .leading, spacing: Sp.sm) {
                FMSkeleton.line(width: 140, height: 16)
                    .padding(.horizontal, Sp.md)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Sp.sm),
                        GridItem(.flexible(), spacing: Sp.sm)
                    ],
                    spacing: Sp.sm
                ) {
                    ForEach(0..<6, id: \.self) { _ in
                        FMSkeleton.rect(height: 200, cornerRadius: R.lg)
                    }
                }
                .padding(.horizontal, Sp.md)
            }
        }
        .accessibilityLabel("로딩 중")
    }

    // MARK: - Helpers

    private var filteredNewFilters: [Filter] {
        guard selectedCategory != "전체" else {
            return store.newFiltersList
        }
        guard let category = filterCategory(for: selectedCategory) else {
            return store.newFiltersList
        }
        return store.newFiltersList.filter { $0.category == category }
    }

    /// 카테고리 칩 라벨 (예: "Cinematic", "B&W") → `FilterCategory` enum.
    /// 매칭되는 카테고리가 없으면 nil — 그 경우 필터링하지 않고 전체 노출.
    private func filterCategory(for chip: String) -> FilterCategory? {
        FilterCategory.allCases.first { $0.displayTitle == chip }
    }

    private var categoryChips: [String] {
        ["전체"] + FilterCategory.allCases.map(\.displayTitle)
    }

    private func prefetchCovers(in filters: [Filter]) {
        let urls = filters
            .compactMap { $0.toTileData().previewImageURL }
            .filter { !prefetchedImageURLs.contains($0) }
        guard !urls.isEmpty else { return }
        prefetchedImageURLs.formUnion(urls)
        urls.forEach { url in
            Task.detached(priority: .utility) {
                _ = try? await URLSession.shared.data(from: url)
            }
        }
    }

    private func sectionHeader(title: String, more: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .fmTypography(.title)
                .foregroundStyle(FMColors.Text.primary)
            Spacer()
            if let more {
                NavigationLink(value: title == "트렌딩" ? AppRoute.forYou : AppRoute.favoritesCollection) {
                    Text(more)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Accent.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func detailMock(from tile: FMFilterTileData) -> FilterDetailMock {
        FilterDetailMock(
            displayTitle: tile.title,
            makerHandle: tile.makerName,
            makerInitials: String(tile.makerName.replacingOccurrences(of: "@", with: "").prefix(2)).uppercased(),
            categoryLabel: "필터",
            downloadCount: tile.downloadCount,
            rating: 4.7,
            reviewCount: max(50, tile.downloadCount / 30),
            likeCount: tile.downloadCount / 5,
            description: "메이커가 직접 조정한 톤커브로, 일상의 순간을 한 단계 더 풍부한 분위기로 끌어올립니다. 강도 60~80% 에서 가장 자연스럽게 어울려요.",
            tags: ["#mood", "#daily", "#warm", "#analog"],
            coverURL: tile.previewImageURL,
            signatureSampleURL: nil,
            filterCategory: .cinematic,
            reviews: [],
            categoryHint: tile.categoryHint ?? FMColors.Category.cinematic,
            isPaid: tile.priceLabel != nil,
            priceLabel: tile.priceLabel
        )
    }
}

// MARK: - FMFilterTileRoute (Hashable navigation value)

struct FMFilterTileRoute: Hashable {
    let mock: FilterDetailMockHashable

    init(mock: FilterDetailMock) {
        self.mock = FilterDetailMockHashable(mock: mock)
    }
}

/// `FilterDetailMock` 은 `Color` 등 비-Hashable 필드를 포함하므로 ID 기반 wrapper 로 hashing.
struct FilterDetailMockHashable: Hashable {
    let id = UUID()
    let mock: FilterDetailMock

    static func == (lhs: FilterDetailMockHashable, rhs: FilterDetailMockHashable) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - FeaturedCard

private struct FeaturedCard: View {
    let data: FMFilterTileData
    let isHighlighted: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 배경 — 카테고리 색상으로 그라데이션 placeholder.
            LinearGradient(
                colors: [
                    (data.categoryHint ?? FMColors.Accent.soft).opacity(0.55),
                    Color.black.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.4),
                    .init(color: Color.black.opacity(0.78), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 좌상단 태그
            HStack(spacing: 4) {
                if isHighlighted {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(isHighlighted ? "이 주의 추천" : "트렌딩")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                    .textCase(.uppercase)
            }
            .foregroundStyle(FMColors.Accent.primary)
            .padding(.horizontal, Sp.xs + 2)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: R.sm))
            .padding(Sp.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // 하단 정보
            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .fmTypography(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(data.makerName) · 다운로드 \(formattedCount(data.downloadCount))")
                    .fmTypography(.subhead)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(Sp.md)
        }
        .aspectRatio(4.0/3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .overlay {
            RoundedRectangle(cornerRadius: R.lg)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.title), \(data.makerName), 다운로드 \(formattedCount(data.downloadCount))")
        .accessibilityAddTraits(.isButton)
    }

    private func formattedCount(_ count: Int) -> String {
        switch count {
        case ..<1_000: "\(count)"
        case 1_000..<10_000: String(format: "%.1fK", Double(count) / 1_000)
        default: "\(count / 1_000)K"
        }
    }
}

// MARK: - CollectionCard

#if DEBUG
private struct CollectionCard: View {
    let entry: MarketplaceMockData.CollectionEntry

    var body: some View {
        HStack(spacing: Sp.md) {
            cluster
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Text(entry.subtitle)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FMColors.Text.tertiary)
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .overlay {
            RoundedRectangle(cornerRadius: R.lg)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(entry.subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    private var cluster: some View {
        ZStack {
            ForEach(Array(entry.symbols.prefix(3).enumerated()), id: \.offset) { offset, symbol in
                let positions: [(CGFloat, CGFloat)] = [(-12, -10), (12, -10), (0, 12)]
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(entry.tint)
                    .frame(width: 36, height: 36)
                    .background(FMColors.Background.bg1, in: RoundedRectangle(cornerRadius: R.sm))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.sm)
                            .strokeBorder(FMColors.Background.bg2, lineWidth: 2)
                    }
                    .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
                    .offset(x: positions[offset].0, y: positions[offset].1)
            }
        }
        .frame(width: 64, height: 64)
    }
}
#endif

// MARK: - Preview

#Preview("MarketplaceScreen — Loaded") {
    MarketplaceScreen()
        .environmentObject({
            let store = MooditStore()
            // Preview 에서는 즉시 mock 채우기 위해 selectedFilterID 만 설정.
            return store
        }())
}

#Preview("MarketplaceScreen — Dark") {
    MarketplaceScreen()
        .environmentObject(MooditStore())
        .preferredColorScheme(.dark)
}
