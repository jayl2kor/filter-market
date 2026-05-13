import DesignSystem
import Foundation
import Models
import SwiftUI

// MARK: - MarketplaceScreen

/// 마켓 홈 — 6번 화면.
///
/// Phase D3 — `mockups/screens/06-marketplace-home.html` 와 정합.
/// 브랜딩 바 + 인사 + 트렌딩 캐러셀 + 카테고리 칩 + 신규 그리드 + 큐레이션.
struct MarketplaceScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.routeRouter) private var router
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @EnvironmentObject private var walletStore: WalletStore

    @State private var selectedCategory: String = "전체"
    @State private var hasAppeared = false
    @State private var prefetchedImageURLs: Set<URL> = []
    @State private var pendingPrefetchImageURLs: Set<URL> = []
    @State private var coverPrefetchQueue: [URL] = []
    @State private var coverPrefetchTask: Task<Void, Never>?

    private let ownsNavigationStack: Bool
    private static let coverPrefetchConcurrency = 3
    private static let coverPrefetchBatchSize = 12

    init(ownsNavigationStack: Bool = true) {
        self.ownsNavigationStack = ownsNavigationStack
    }

    /// filterLibraryStore.load() 가 끝났을 때 false 가 된다. 로딩 시는 skeleton.
    private var isLoading: Bool {
        !hasAppeared || (filterLibraryStore.isLoading && filterLibraryStore.filters.isEmpty)
    }

    var body: some View {
        Group {
            if ownsNavigationStack {
                NavigationStack {
                    content
                        .appRouteDestinations()
                }
            } else {
                content
            }
        }
        .task {
            // 첫 진입 시 hasAppeared를 즉시 true — 로딩 상태 + 데이터 도착 여부로
            // skeleton/empty/content를 분기. (#18 hardcoded 350ms sleep 제거)
            hasAppeared = true
        }
        .storeErrorToast(
            message: filterLibraryStore.lastSyncErrorMessage,
            title: "동기화 실패"
        ) {
            filterLibraryStore.clearLastSyncError()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                brandingBar

                greeting
                    .padding(.horizontal, Sp.md)

                if let error = filterLibraryStore.loadError, filterLibraryStore.filters.isEmpty {
                    errorState(message: error.message)
                } else if isLoading {
                    loadingState
                } else {
                    loadedSections
                }
            }
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .refreshable {
            Telemetry.trackPullToRefresh(.marketplaceHome)
            await filterLibraryStore.load(force: true)
        }
        .overlay(alignment: .top) {
            topSafeAreaCover
        }
        .onDisappear {
            cancelCoverPrefetch()
        }
        .background(FMColors.Background.bg0)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var topSafeAreaCover: some View {
        GeometryReader { proxy in
            FMColors.Background.bg0
                .frame(height: proxy.safeAreaInsets.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }

    private var brandingBar: some View {
        ZStack {
            Image("MooditWordmark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(FMColors.Text.primary)
                .frame(width: 104, height: 26)
                .accessibilityLabel("moodit")
                .accessibilityIdentifier("market.brandbar.logo")
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 0) {
                Button {
                    Telemetry.trackAction("create_filter_from_market", screen: .marketplaceHome, parameters: [
                        "source": "brandbar_plus"
                    ])
                    router.navigate(to: .editor)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: IconSize.md, weight: .semibold))
                        .foregroundStyle(FMColors.Text.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("market.brandbar.create")
                .accessibilityLabel("새 필터 만들기")
                .accessibilityHint("탭하면 필터 에디터로 이동합니다")

                Spacer(minLength: Sp.sm)

                HStack(spacing: Sp.sm) {
                    walletBalanceButton
                    notificationsButton
                }
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.sm)
    }

    private var walletBalanceButton: some View {
        NavigationLink(value: AppRoute.wallet) {
            HStack(spacing: 4) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: IconSize.sm, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                    .accessibilityHidden(true)
                Text(walletStore.coinBalance.formatted())
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
        .simultaneousGesture(TapGesture().onEnded {
            Telemetry.trackAction("wallet_opened", screen: .marketplaceHome, parameters: ["source": "header"])
        })
        .accessibilityIdentifier("market.header.coinBalance")
        .accessibilityLabel("코인 잔액 \(walletStore.coinBalance)개, 지갑 열기")
    }

    private var notificationsButton: some View {
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
        .simultaneousGesture(TapGesture().onEnded {
            Telemetry.trackAction("notifications_opened", screen: .marketplaceHome, parameters: ["source": "header"])
        })
        .accessibilityIdentifier("market.header.notifications")
        .accessibilityLabel("알림")
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
            prefetchCovers(in: Array(filterLibraryStore.trendingFilters.prefix(8)) + Array(filteredNewFilters.prefix(8)))
        }
    }

    // Trending carousel
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionHeader(title: "트렌딩", more: "더보기 →")
                .padding(.horizontal, Sp.md)

            if filterLibraryStore.trendingFilters.isEmpty {
                FMEmptyState(.emptyMarket, ctaTitle: "새로고침") {
                    Telemetry.trackAction("empty_state_cta_tapped", screen: .marketplaceHome, parameters: ["section": "trending"])
                    Task { await filterLibraryStore.load(force: true) }
                }
                    .padding(.horizontal, Sp.md)
                    .onAppear {
                        Telemetry.trackEmptyState("market_trending_empty", screen: .marketplaceHome)
                    }
                    .accessibilityIdentifier("market.trending.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Sp.sm) {
                        ForEach(Array(filterLibraryStore.trendingFilters.enumerated()), id: \.element.id) { index, filter in
                            NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                                FeaturedCard(data: filter.toTileData(), isHighlighted: index == 0)
                                    .frame(width: 268)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                Telemetry.trackFunnelStep("marketplace_download", step: "filter_card_opened", screen: .marketplaceHome, parameters: [
                                    "section": "trending",
                                    "position": index
                                ])
                            })
                            .onAppear {
                                prefetchCovers(in: Array(filterLibraryStore.trendingFilters.dropFirst(index + 1).prefix(8)))
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
                                Telemetry.trackAction("category_selected", screen: .marketplaceHome, parameters: [
                                    "category": category
                                ])
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
                FMEmptyState(.emptyMarket, ctaTitle: "새로고침") {
                    Telemetry.trackAction("empty_state_cta_tapped", screen: .marketplaceHome, parameters: [
                        "section": "new_filters",
                        "category": selectedCategory
                    ])
                    Task { await filterLibraryStore.load(force: true) }
                }
                    .padding(.horizontal, Sp.md)
                    .onAppear {
                        Telemetry.trackEmptyState("market_new_filters_empty", screen: .marketplaceHome, parameters: [
                            "category": selectedCategory
                        ])
                    }
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
                        .simultaneousGesture(TapGesture().onEnded {
                            Telemetry.trackFunnelStep("marketplace_download", step: "filter_card_opened", screen: .marketplaceHome, parameters: [
                                "section": "new_filters",
                                "position": index,
                                "category": selectedCategory
                            ])
                        })
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
                        .simultaneousGesture(TapGesture().onEnded {
                            Telemetry.trackAction("collection_opened", screen: .marketplaceHome, parameters: [
                                "collection": collection.title
                            ])
                        })
                        .accessibilityIdentifier("market.collection.\(collection.title)")
                    }
                }
                .padding(.horizontal, Sp.md)
            }
        }
        #endif
    }

    // MARK: - Error

    private func errorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            HStack(alignment: .top, spacing: Sp.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: IconSize.md, weight: .semibold))
                    .foregroundStyle(FMColors.Semantic.error)
                VStack(alignment: .leading, spacing: 2) {
                    Text("필터를 불러오지 못했어요")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(message)
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
                Telemetry.trackAction("load_retry_tapped", screen: .marketplaceHome)
                Task { await filterLibraryStore.retry() }
            }
            .accessibilityIdentifier("market.loadError.retry")
        }
        .padding(.horizontal, Sp.md)
        .onAppear {
            Telemetry.trackError("market_load_error", screen: .marketplaceHome, parameters: [
                "error_type": "FriendlyError"
            ])
        }
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
            return filterLibraryStore.newFiltersList
        }
        guard let category = filterCategory(for: selectedCategory) else {
            return filterLibraryStore.newFiltersList
        }
        return filterLibraryStore.newFiltersList.filter { $0.category == category }
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
            .filter { !prefetchedImageURLs.contains($0) && !pendingPrefetchImageURLs.contains($0) }
        guard !urls.isEmpty else { return }
        pendingPrefetchImageURLs.formUnion(urls)
        coverPrefetchQueue.append(contentsOf: urls)
        startCoverPrefetchIfNeeded()
    }

    private func startCoverPrefetchIfNeeded() {
        guard coverPrefetchTask == nil else { return }
        coverPrefetchTask = Task(priority: .utility) {
            defer {
                Task { @MainActor in
                    coverPrefetchTask = nil
                }
            }
            while !Task.isCancelled {
                let batch = await MainActor.run {
                    dequeueNextCoverPrefetchBatch()
                }
                guard !batch.isEmpty else { return }
                await Self.prefetchCoverURLs(batch, maxConcurrent: Self.coverPrefetchConcurrency)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    pendingPrefetchImageURLs.subtract(batch)
                    prefetchedImageURLs.formUnion(batch)
                }
            }
        }
    }

    private func dequeueNextCoverPrefetchBatch() -> [URL] {
        guard !coverPrefetchQueue.isEmpty else { return [] }
        let count = min(Self.coverPrefetchBatchSize, coverPrefetchQueue.count)
        let batch = Array(coverPrefetchQueue.prefix(count))
        coverPrefetchQueue.removeFirst(count)
        return batch
    }

    private func cancelCoverPrefetch() {
        coverPrefetchTask?.cancel()
        coverPrefetchTask = nil
        coverPrefetchQueue.removeAll()
        pendingPrefetchImageURLs.removeAll()
    }

    private static func prefetchCoverURLs(_ urls: [URL], maxConcurrent: Int) async {
        guard maxConcurrent > 0 else { return }
        var iterator = urls.makeIterator()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<maxConcurrent {
                guard let url = iterator.next() else { return }
                group.addTask {
                    await prefetchCoverURL(url)
                }
            }

            while await group.next() != nil {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }
                if let url = iterator.next() {
                    group.addTask {
                        await prefetchCoverURL(url)
                    }
                }
            }
        }
    }

    private static func prefetchCoverURL(_ url: URL) async {
        guard !Task.isCancelled else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                debugPrint("[MarketplacePrefetch] cover image returned HTTP \(httpResponse.statusCode): \(url.absoluteString)")
            }
            #endif
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
            debugPrint("[MarketplacePrefetch] cover image failed: \(url.absoluteString) \(error.localizedDescription)")
            #endif
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
            makerAvatarURL: tile.makerAvatarURL,
            categoryLabel: "필터",
            downloadCount: tile.downloadCount,
            rating: 4.7,
            reviewCount: 0,
            likeCount: 0,
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
                HStack(spacing: Sp.xxs) {
                    FMAvatar(
                        url: data.makerAvatarURL,
                        size: .xs,
                        fallback: String(data.makerName.replacingOccurrences(of: "@", with: "").prefix(2)).uppercased()
                    )
                    Text(data.makerName)
                        .fmTypography(.subhead)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    Text("·")
                        .fmTypography(.subhead)
                        .foregroundStyle(.white.opacity(0.65))
                    Text("다운로드 \(formattedCount(data.downloadCount))")
                        .fmTypography(.subhead)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
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
        .accessibilityHint("탭하면 필터 상세를 봅니다")
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
                .accessibilityHidden(true)
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
        .accessibilityHint("탭하면 컬렉션을 봅니다")
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
    let store = MooditStore()
    MarketplaceScreen()
        .environmentObject(store.filterLibraryStore)
        .environmentObject(store.walletStore)
}

#Preview("MarketplaceScreen — Dark") {
    let store = MooditStore()
    MarketplaceScreen()
        .environmentObject(store.filterLibraryStore)
        .environmentObject(store.walletStore)
        .preferredColorScheme(.dark)
}
