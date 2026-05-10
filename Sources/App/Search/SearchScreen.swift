import DesignSystem
import FirebaseAuth
import FirebaseCore
import Models
import SwiftUI

// MARK: - SearchPhase

enum SearchPhase: Hashable {
    case discovering    // 기본 — 발견 피드
    case browsing       // 검색 필드 focus — 최근/추천/인기
    case typing         // 입력 중 — 자동완성/실시간 결과
    case results        // submit 후 — 그리드 결과 + 결과 없음 빈 상태

    var telemetryName: String {
        switch self {
        case .discovering: "discovering"
        case .browsing: "browsing"
        case .typing: "typing"
        case .results: "results"
        }
    }
}

// MARK: - PopularMaker

/// 검색 화면용 인기 메이커 표시 모델.
struct PopularMaker: Identifiable, Sendable {
    let id: String
    let initials: String
    let handle: String
    let avatarURL: URL?
    let filterCount: Int
}

// MARK: - SearchScreen

/// 발견 — 8번 화면.
///
/// 헤더 + 입력 + 취소 / discovering(발견 피드) / browsing(최근/추천/메이커) / typing(필터 + 메이커) / results(그리드 + 빈상태).
struct SearchScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var walletStore: WalletStore
    @State private var query: String = ""
    @State private var debouncedQuery: String = ""
    @State private var isSearchDebouncing = false
    @State private var searchDebounceTask: Task<Void, Never>?
    // (#39) 사용자별 최근 검색어 — UserDefaults 영속화. 신규 사용자는 빈 배열에서 시작.
    @State private var recentSearches: [String] = []
    @State private var recentSearchesStorageKey: String = ""
    @State private var cachedPopularMakers: [PopularMaker] = []
    @State private var phase: SearchPhase = .discovering
    @State private var didTrackDiscoverImpression = false
    @State private var suppressNextQueryDebounce = false
    @FocusState private var isFieldFocused: Bool

    private let initialCategory: String?
    private let showsBackButton: Bool
    private let openRoute: ((AppRoute) -> Void)?

    private let suggestedKeywords = [
        "#골든아워", "#필름룩", "#씨네마틱", "#카페",
        "#포트레이트", "#모노톤", "#비비드", "#무드"
    ]

    init(
        initialQuery: String? = nil,
        initialCategory: String? = nil,
        showsBackButton: Bool = false,
        openRoute: ((AppRoute) -> Void)? = nil
    ) {
        let query = initialQuery ?? initialCategory ?? ""
        self._query = State(initialValue: query)
        self._debouncedQuery = State(initialValue: query)
        self._phase = State(initialValue: query.isEmpty ? .discovering : .results)
        self.initialCategory = initialCategory
        self.showsBackButton = showsBackButton
        self.openRoute = openRoute
    }

    var body: some View {
        VStack(spacing: 0) {
            searchTopBar

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch phase {
                    case .discovering:
                        discoveringContent
                    case .browsing:
                        browsingContent
                    case .typing:
                        typingContent
                    case .results:
                        resultsContent
                    }
                }
                .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await refreshSearchResults()
            }
        }
        .background(FMColors.Background.bg0)
        .toolbar(.hidden, for: .navigationBar)
        .simultaneousGesture(edgeSwipeDismissGesture)
        .onAppear {
            loadRecentSearches()
            refreshPopularMakers(from: filterLibraryStore.filters)
            trackDiscoverImpressionIfNeeded()
        }
        .task {
            await filterLibraryStore.load()
        }
        .onReceive(filterLibraryStore.$filters) { filters in
            refreshPopularMakers(from: filters)
        }
        .onChange(of: query) { _, newValue in
            if suppressNextQueryDebounce {
                suppressNextQueryDebounce = false
                return
            }
            scheduleDebouncedSearch(for: newValue)
        }
        .onChange(of: isFieldFocused) { _, focused in
            guard focused, phase == .discovering else { return }
            withAnimation(.fmFast.reducedIfNeeded(reduceMotion)) {
                phase = .browsing
            }
        }
        .onChange(of: phase) { _, newValue in
            guard newValue == .discovering else { return }
            trackDiscoverImpressionIfNeeded()
        }
        .onChange(of: sessionStore.isAuthenticated) { _, _ in
            loadRecentSearches()
        }
        .onDisappear {
            searchDebounceTask?.cancel()
        }
    }

    // MARK: - Top bar

    private var searchTopBar: some View {
        HStack(spacing: Sp.sm) {
            if showsBackButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FMColors.Text.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")
                .accessibilityIdentifier("search.back")
            }

            FMSearchHeader(
                placeholder: "필터, 메이커, 분위기 검색",
                text: $query
            ) {
                guard !query.isEmpty else { return }
                searchDebounceTask?.cancel()
                debouncedQuery = query
                isSearchDebouncing = false
                phase = .results
                rememberSearch(query)
                Telemetry.trackFunnelStep("search_discovery", step: "query_submitted", screen: .search, parameters: [
                    "query_length": query.count,
                    "source": "keyboard"
                ])
            }
            .accessibilityIdentifier("search.searchHeader")
            .focused($isFieldFocused)
            .frame(maxWidth: .infinity)
            .layoutPriority(1)

            if showsHeaderActions {
                headerActions
                    .transition(
                        .fmReducible(
                            .opacity.combined(with: .move(edge: .trailing)),
                            reduceMotion: reduceMotion
                        )
                    )
            } else if showsBackButton && (!query.isEmpty || phase != .discovering) {
                Button {
                    Telemetry.trackAction("search_cancelled", screen: .search, parameters: [
                        "phase": phase.telemetryName
                    ])
                    cancelSearch()
                } label: {
                    Text("취소")
                        .fmTypography(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Accent.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(minWidth: 60, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색 취소")
                .transition(
                    .fmReducible(
                        .opacity.combined(with: .move(edge: .trailing)),
                        reduceMotion: reduceMotion
                    )
                )
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.sm)
        .padding(.bottom, Sp.sm)
        .background(FMColors.Background.bg0)
        .overlay(alignment: .bottom) {
            if showsBackButton {
                Rectangle()
                    .fill(FMColors.Border.subtle)
                    .frame(height: 1)
            }
        }
        .fmAnimation(.fmFast, value: phase)
    }

    private var showsHeaderActions: Bool {
        !showsBackButton
    }

    private var headerActions: some View {
        HStack(spacing: Sp.sm) {
            routeLink(value: .wallet) {
                HStack(spacing: 4) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: IconSize.sm, weight: .semibold))
                        .foregroundStyle(FMColors.Accent.primary)
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
                Telemetry.trackAction("wallet_opened", screen: .search, parameters: ["source": "header"])
            })
            .accessibilityIdentifier("search.header.coinBalance")
            .accessibilityLabel("코인 잔액 \(walletStore.coinBalance)개, 지갑 열기")

            routeLink(value: .notifications) {
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
                Telemetry.trackAction("notifications_opened", screen: .search, parameters: ["source": "header"])
            })
            .accessibilityLabel("알림")
        }
    }

    @ViewBuilder
    private func routeLink<Label: View>(
        value route: AppRoute,
        @ViewBuilder label: () -> Label
    ) -> some View {
        if let openRoute {
            Button {
                openRoute(route)
            } label: {
                label()
            }
        } else {
            NavigationLink(value: route) {
                label()
            }
        }
    }

    // MARK: - Discovering

    private var discoveringContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            discoverHeroSection
            sectionDivider
            discoverRailSection
            sectionDivider
            keywordsSection
            sectionDivider
            popularMakersSection
        }
    }

    // MARK: - Browsing

    private var browsingContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            recentSection
            sectionDivider
            keywordsSection
            sectionDivider
            popularMakersSection
        }
    }

    private var discoverHeroSection: some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("발견")
                    .fmTypography(.titleLarge)
                    .fontWeight(.bold)
                    .foregroundStyle(FMColors.Text.primary)
                Text("지금 많이 저장되는 필터와 새 메이커를 둘러보세요.")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
            }

            if let filter = discoverHeroFilter {
                routeLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                    ZStack(alignment: .bottomLeading) {
                        discoverCover(filter)
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.82)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        VStack(alignment: .leading, spacing: Sp.xs) {
                            Label("추천", systemImage: "sparkles")
                                .fmTypography(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(FMColors.Accent.primary)
                                .padding(.horizontal, Sp.xs)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.92), in: Capsule())

                            Text(filter.title)
                                .fmTypography(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Text("@\(filter.author.displayName) · \(filter.category.displayTitle) · ↓ \(discoverCount(filter).fmCompactCount())")
                                .fmTypography(.subhead)
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                        }
                        .padding(Sp.md)
                    }
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: R.lg))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("discover.hero")
            } else {
                VStack(alignment: .leading, spacing: Sp.xs) {
                    Text("아직 추천할 필터가 없어요.")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("마켓 데이터를 불러오면 발견 피드가 채워집니다.")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                .padding(Sp.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.lg))
                .accessibilityIdentifier("discover.empty")
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.md)
        .padding(.bottom, Sp.lg)
        .accessibilityIdentifier("discover.feed")
    }

    private var discoverRailSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Text("많이 받는 필터")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Spacer()
                routeLink(value: AppRoute.forYou) {
                    Text("For You")
                        .fmTypography(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Accent.primary)
                }
                .buttonStyle(.plain)
            }

            if discoverRailFilters.isEmpty {
                Text("추천 후보를 불러오는 중입니다.")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .padding(.vertical, Sp.xs)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Sp.sm) {
                        ForEach(Array(discoverRailFilters.enumerated()), id: \.element.id) { index, filter in
                            routeLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                                FMFilterTile(data: filter.toTileData())
                                    .frame(width: 148)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                Telemetry.trackFunnelStep("search_discovery", step: "filter_opened", screen: .search, parameters: [
                                    "source": "discover_rail",
                                    "position": index
                                ])
                            })
                            .accessibilityIdentifier("discover.rail.tile.\(index)")
                        }
                    }
                    .padding(.bottom, Sp.xs)
                }
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.md)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Text("최근 검색")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Spacer()
                if !recentSearches.isEmpty {
                    Button {
                        Telemetry.trackAction("recent_searches_cleared", screen: .search, parameters: [
                            "count": recentSearches.count
                        ])
                        clearRecentSearches()
                    } label: {
                        Text("모두 지우기")
                            .fmTypography(.subhead)
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("최근 검색 모두 지우기")
                }
            }

            if recentSearches.isEmpty {
                Text("최근 검색 기록이 없어요.")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .padding(.vertical, Sp.xs)
                    .onAppear {
                        Telemetry.trackEmptyState("recent_searches_empty", screen: .search)
                    }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentSearches.enumerated()), id: \.element) { index, term in
                        recentRow(term: term)
                        if index < recentSearches.count - 1 {
                            Rectangle()
                                .fill(FMColors.Border.subtle)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.md)
        .accessibilityIdentifier("search.makers")
    }

    private func recentRow(term: String) -> some View {
        HStack(spacing: Sp.sm) {
            Image(systemName: "clock")
                .font(.system(size: IconSize.sm, weight: .regular))
                .foregroundStyle(FMColors.Text.tertiary)
                .frame(width: 18, height: 18)

            Button {
                submitSearch(term)
                Telemetry.trackFunnelStep("search_discovery", step: "query_submitted", screen: .search, parameters: [
                    "query_length": term.count,
                    "source": "recent"
                ])
            } label: {
                Text(term)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                removeRecentSearch(term)
                Telemetry.trackAction("recent_search_removed", screen: .search)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FMColors.Text.tertiary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(term) 검색 기록 삭제")
        }
        .padding(.vertical, 10)
        .accessibilityIdentifier("search.recent.\(term)")
    }

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("추천 키워드")
                .fmTypography(.headline)
                .foregroundStyle(FMColors.Text.primary)

            FlowLayout(spacing: Sp.xs, lineSpacing: Sp.xs) {
                ForEach(suggestedKeywords, id: \.self) { keyword in
                    FMChip(keyword, size: .sm) {
                        let stripped = keyword.replacingOccurrences(of: "#", with: "")
                        submitSearch(stripped)
                        Telemetry.trackFunnelStep("search_discovery", step: "query_submitted", screen: .search, parameters: [
                            "query_length": stripped.count,
                            "source": "suggested_keyword"
                        ])
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("search.suggested.\(keyword)")
                }
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.md)
    }

    private var popularMakersSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Text("인기 메이커")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Spacer()
                routeLink(value: AppRoute.forYou) {
                    Text("전체 →")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Accent.primary)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    Telemetry.trackAction("popular_makers_all_opened", screen: .search)
                })
            }

            if cachedPopularMakers.isEmpty {
                Text("아직 인기 메이커 데이터가 없어요.")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .padding(.vertical, Sp.xs)
                    .onAppear {
                        Telemetry.trackEmptyState("popular_makers_empty", screen: .search)
                    }
                    .accessibilityIdentifier("search.makers.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Sp.md) {
                        ForEach(cachedPopularMakers) { maker in
                            makerCell(maker)
                                .accessibilityIdentifier("search.maker.\(maker.id)")
                        }
                    }
                    .padding(.bottom, Sp.xs)
                }
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.md)
    }

    private func makerCell(_ maker: PopularMaker) -> some View {
        routeLink(value: AppRoute.otherProfile(uid: maker.id)) {
            VStack(spacing: Sp.xs) {
                FMAvatar(url: maker.avatarURL, size: .lg, fallback: maker.initials)
                    .overlay {
                        Circle()
                            .strokeBorder(FMColors.Accent.soft, lineWidth: 2)
                    }
                Text(maker.handle)
                    .fmTypography(.subhead)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.Text.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("필터 \(maker.filterCount)")
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .lineLimit(1)
            }
            .frame(width: 112)
            .frame(minHeight: 116)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            Telemetry.trackFunnelStep("search_discovery", step: "maker_opened", screen: .search, parameters: [
                "source": "popular_makers"
            ])
        })
        .accessibilityElement(children: .combine)
    }

    // MARK: - Typing (live)

    private var typingContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 메이커 매치 (있으면)
            if !filteredMakers.isEmpty {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    Text("메이커")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.tertiary)

                    VStack(spacing: 0) {
                        ForEach(filteredMakers) { maker in
                            makerRow(maker)
                            if maker.id != filteredMakers.last?.id {
                                Rectangle()
                                    .fill(FMColors.Border.subtle)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, Sp.md)
                .padding(.vertical, Sp.md)

                sectionDivider
            }

            // 필터 매치 그리드
            VStack(alignment: .leading, spacing: Sp.sm) {
                Text("필터 \(filteredFilters.count)개")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.tertiary)

                if filteredFilters.isEmpty {
                    Text("입력에 맞는 필터를 찾고 있어요...")
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.secondary)
                        .padding(.vertical, Sp.lg)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Sp.sm),
                            GridItem(.flexible(), spacing: Sp.sm)
                        ],
                        spacing: Sp.sm
                    ) {
                        ForEach(Array(filteredFilters.enumerated()), id: \.offset) { index, filter in
                            routeLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                                FMFilterTile(data: filter.toTileData())
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                Telemetry.trackFunnelStep("search_discovery", step: "filter_opened", screen: .search, parameters: [
                                    "source": "typing",
                                    "position": index
                                ])
                            })
                            .accessibilityIdentifier("search.typing.tile.\(index)")
                        }
                    }
                }

                if isSearchDebouncing {
                    HStack(spacing: Sp.xs) {
                        ProgressView()
                            .controlSize(.small)
                        Text("검색 결과를 갱신하고 있어요.")
                            .fmTypography(.subhead)
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Sp.md)
                    .accessibilityIdentifier("search.debouncing")
                }
            }
            .padding(.horizontal, Sp.md)
            .padding(.vertical, Sp.md)
        }
    }

    private func makerRow(_ maker: PopularMaker) -> some View {
        routeLink(value: AppRoute.otherProfile(uid: maker.id)) {
            HStack(spacing: Sp.sm) {
                FMAvatar(url: maker.avatarURL, size: .sm, fallback: maker.initials)
                VStack(alignment: .leading, spacing: 2) {
                    Text(maker.handle)
                        .fmTypography(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("필터 \(maker.filterCount)")
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            .padding(.vertical, Sp.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            Telemetry.trackFunnelStep("search_discovery", step: "maker_opened", screen: .search, parameters: [
                "source": "typing"
            ])
        })
    }

    @ViewBuilder
    private func discoverCover(_ filter: Filter) -> some View {
        FMRemoteImage(
            url: filter.coverURL,
            cornerRadius: R.lg,
            placeholder: {
                GeometryReader { proxy in
                    FMSkeleton.rect(height: proxy.size.height, cornerRadius: R.lg)
                }
            },
            failure: {
                FMFilterCoverArt(motif: FilterCoverMotifResolver.motif(for: filter.title, category: filter.category.rawValue))
            }
        )
    }

    // MARK: - Results

    private var resultsContent: some View {
        Group {
            if filteredFilters.isEmpty {
                FMEmptyState(.noSearchResults(query: query)) {
                    Telemetry.trackAction("empty_state_cta_tapped", screen: .search, parameters: [
                        "state_name": "no_search_results"
                    ])
                    cancelSearch()
                }
                .padding(.top, Sp.xxl)
                .onAppear {
                    Telemetry.trackEmptyState("no_search_results", screen: .search, parameters: [
                        "query_length": query.count
                    ])
                }
            } else {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    Text("\"\(query)\" 결과 · \(filteredFilters.count)개")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(FMColors.Text.tertiary)
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.md)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Sp.sm),
                            GridItem(.flexible(), spacing: Sp.sm)
                        ],
                        spacing: Sp.sm
                    ) {
                        ForEach(Array(filteredFilters.enumerated()), id: \.offset) { index, filter in
                            routeLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                                FMFilterTile(data: filter.toTileData())
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                Telemetry.trackFunnelStep("search_discovery", step: "filter_opened", screen: .search, parameters: [
                                    "source": "results",
                                    "position": index
                                ])
                            })
                            .accessibilityIdentifier("search.result.tile.\(index)")
                        }
                    }
                    .padding(.horizontal, Sp.md)
                }
            }
        }
    }

    // MARK: - Helpers

    private var sectionDivider: some View {
        Rectangle()
            .fill(FMColors.Border.subtle)
            .frame(height: 1)
    }

    private var filteredFilters: [Filter] {
        let searchQuery = activeSearchQuery
        guard !searchQuery.isEmpty else { return [] }
        let normalized = normalizedSearchToken(searchQuery)
        // 컬렉션 분기는 카테고리 필터로만 — 결과 비어있으면 FMEmptyState(.noSearchResults).
        if let initialCategory, initialCategory == "컬렉션" {
            return filterLibraryStore.newFiltersList
        }
        return filterLibraryStore.filters.filter { f in
            guard f.status == .approved else { return false }
            return f.title.lowercased().contains(normalized)
                || f.author.displayName.lowercased().contains(normalized)
                || f.category.rawValue.lowercased().contains(normalized)
                || f.tags.contains { $0.lowercased().contains(normalized) }
        }
    }

    private var filteredMakers: [PopularMaker] {
        let searchQuery = activeSearchQuery
        guard !searchQuery.isEmpty else { return [] }
        let lower = normalizedSearchToken(searchQuery)
        return cachedPopularMakers.filter { $0.handle.lowercased().contains(lower) }
    }

    private var discoverRankedFilters: [Filter] {
        let source = filterLibraryStore.trendingFilters.isEmpty ? filterLibraryStore.filters : filterLibraryStore.trendingFilters
        return source
            .filter { $0.status == .approved }
            .sorted { lhs, rhs in
                let lhsScore = discoverCount(lhs) + Int((lhs.ratingAvg ?? 0) * 100)
                let rhsScore = discoverCount(rhs) + Int((rhs.ratingAvg ?? 0) * 100)
                return lhsScore == rhsScore ? lhs.title < rhs.title : lhsScore > rhsScore
            }
    }

    private var discoverHeroFilter: Filter? {
        discoverRankedFilters.first
    }

    private var discoverRailFilters: [Filter] {
        Array(discoverRankedFilters.dropFirst().prefix(8))
    }

    private var activeSearchQuery: String {
        phase == .typing ? debouncedQuery : query
    }

    private func discoverCount(_ filter: Filter) -> Int {
        filter.downloadCount > 0 ? filter.downloadCount : filter.useCount
    }

    private static func computePopularMakers(from filters: [Filter]) -> [PopularMaker] {
        let approved = filters.filter {
            $0.status == .approved && !Self.systemSeedAuthorUIDs.contains($0.author.uid)
        }
        let grouped = Dictionary(grouping: approved) { $0.author.uid }

        return grouped.compactMap { uid, filters -> PopularMaker? in
            guard let author = filters.first?.author else { return nil }
            let displayName = author.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let handleSource = displayName.isEmpty ? uid : displayName
            let initials = handleSource
                .split(separator: " ")
                .prefix(2)
                .compactMap { $0.first }
                .map(String.init)
                .joined()
                .uppercased()

            return PopularMaker(
                id: uid,
                initials: initials.isEmpty ? "M" : initials,
                handle: handleSource.hasPrefix("@") ? handleSource : "@\(handleSource)",
                avatarURL: author.avatarURL,
                filterCount: filters.count
            )
        }
        .sorted {
            if $0.filterCount == $1.filterCount {
                return $0.handle < $1.handle
            }
            return $0.filterCount > $1.filterCount
        }
        .prefix(5)
        .map { $0 }
    }

    private static let systemSeedAuthorUIDs: Set<String> = [
        "preview-maker",
        "maker-night",
        "maker-trip",
        "maker-portra",
        "maker-cafe"
    ]

    private func normalizedSearchToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .lowercased()
    }

    private func cancelSearch() {
        searchDebounceTask?.cancel()
        withAnimation(.fmFast.reducedIfNeeded(reduceMotion)) {
            isFieldFocused = false
            query = ""
            debouncedQuery = ""
            isSearchDebouncing = false
            phase = .discovering
        }
    }

    private func submitSearch(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchDebounceTask?.cancel()
        suppressNextQueryDebounce = query != trimmed
        query = trimmed
        debouncedQuery = trimmed
        isSearchDebouncing = false
        phase = .results
        rememberSearch(trimmed)
    }

    private func scheduleDebouncedSearch(for newValue: String) {
        searchDebounceTask?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            debouncedQuery = ""
            isSearchDebouncing = false
            phase = isFieldFocused ? .browsing : .discovering
            return
        }

        phase = .typing
        isSearchDebouncing = true
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, query == newValue else { return }
            debouncedQuery = newValue
            isSearchDebouncing = false
        }
    }

    private func refreshSearchResults() async {
        guard phase == .results else { return }
        Telemetry.trackPullToRefresh(.search, parameters: [
            "query_length": query.count
        ])
        await filterLibraryStore.load(force: true)
        debouncedQuery = query
    }

    private func trackDiscoverImpressionIfNeeded() {
        guard !didTrackDiscoverImpression, phase == .discovering else { return }
        didTrackDiscoverImpression = true
        Telemetry.trackFunnelStep("search_discovery", step: "discover_impression", screen: .search, parameters: [
            "filter_count": filterLibraryStore.filters.count
        ])
    }

    private func rememberSearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 8 {
            recentSearches = Array(recentSearches.prefix(8))
        }
        persistRecentSearches()
    }

    private func removeRecentSearch(_ term: String) {
        recentSearches.removeAll { $0 == term }
        persistRecentSearches()
    }

    private func clearRecentSearches() {
        recentSearches = []
        persistRecentSearches()
    }

    private func refreshPopularMakers(from filters: [Filter]) {
        cachedPopularMakers = Self.computePopularMakers(from: filters)
    }

    private var edgeSwipeDismissGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .global)
            .onEnded { value in
                guard showsBackButton,
                      value.startLocation.x < 24,
                      value.translation.width > 80,
                      abs(value.translation.height) < 80 else {
                    return
                }
                dismiss()
            }
    }

    private func loadRecentSearches() {
        let key = Self.recentSearchesKey()
        recentSearchesStorageKey = key
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            recentSearches = []
            return
        }
        recentSearches = Array(decoded.prefix(8))
    }

    private func persistRecentSearches() {
        let key = recentSearchesStorageKey.isEmpty ? Self.recentSearchesKey() : recentSearchesStorageKey
        guard let data = try? JSONEncoder().encode(Array(recentSearches.prefix(8))) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func recentSearchesKey() -> String {
        guard !isUITesting, FirebaseApp.app() != nil else {
            return "search.recent.guest"
        }
        if let uid = Auth.auth().currentUser?.uid, !uid.isEmpty {
            return "search.recent.\(uid)"
        }
        return "search.recent.guest"
    }
}

// MARK: - FlowLayout

/// 가변 폭 칩들을 줄바꿈하며 배치하는 단순 레이아웃.
private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + lineSpacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview("SearchScreen — Browsing") {
    let store = MooditStore()
    SearchScreen()
        .environmentObject(store.filterLibraryStore)
        .environmentObject(store.sessionStore)
}

#Preview("SearchScreen — Dark") {
    let store = MooditStore()
    SearchScreen()
        .environmentObject(store.filterLibraryStore)
        .environmentObject(store.sessionStore)
        .preferredColorScheme(.dark)
}

#Preview("SearchScreen — XXXLarge") {
    let store = MooditStore()
    SearchScreen()
        .environmentObject(store.filterLibraryStore)
        .environmentObject(store.sessionStore)
        .dynamicTypeSize(.xxxLarge)
}
