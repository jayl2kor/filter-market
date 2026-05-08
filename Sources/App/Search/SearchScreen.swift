import DesignSystem
import Models
import SwiftUI

// MARK: - SearchPhase

enum SearchPhase: Hashable {
    case browsing       // 빈 query — 추천/최근/인기
    case typing         // 입력 중 — 자동완성/실시간 결과
    case results        // submit 후 — 그리드 결과 + 결과 없음 빈 상태
}

// MARK: - PopularMaker

/// 검색 화면용 인기 메이커 표시 모델.
struct PopularMaker: Identifiable, Sendable {
    let id: String
    let initials: String
    let handle: String
    let filterCount: Int
}

// MARK: - SearchScreen

/// 검색 — 8번 화면.
///
/// Phase D3 — `mockups/screens/08-search.html` 와 정합.
/// 헤더 + 입력 + 취소 / browsing(최근/추천/메이커) / typing(필터 + 메이커) / results(그리드 + 빈상태).
struct SearchScreen: View {
    @EnvironmentObject private var store: MooditStore
    @State private var query: String = ""
    // (#39) 사용자별 최근 검색어 — UserDefaults 영속화. 신규 사용자는 빈 배열에서 시작.
    @State private var recentSearches: [String] = []
    @State private var phase: SearchPhase = .browsing
    @FocusState private var isFieldFocused: Bool

    private let initialCategory: String?

    private let suggestedKeywords = [
        "#골든아워", "#필름룩", "#씨네마틱", "#카페",
        "#포트레이트", "#모노톤", "#비비드", "#무드"
    ]

    init(initialQuery: String? = nil, initialCategory: String? = nil) {
        let query = initialQuery ?? initialCategory ?? ""
        self._query = State(initialValue: query)
        self._phase = State(initialValue: query.isEmpty ? .browsing : .results)
        self.initialCategory = initialCategory
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchTopBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch phase {
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
            }
            .background(FMColors.Background.bg0)
            .appRouteDestinations()
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            // 첫 진입 시 자연스러운 focus.
            try? await Task.sleep(nanoseconds: 200_000_000)
            isFieldFocused = true
        }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty {
                phase = .browsing
            } else if phase != .results {
                phase = .typing
            }
        }
    }

    // MARK: - Top bar

    private var searchTopBar: some View {
        HStack(spacing: Sp.xs) {
            FMTextField.search(
                text: $query,
                placeholder: "필터, 메이커, 분위기"
            )
            .focused($isFieldFocused)
            .onSubmit {
                guard !query.isEmpty else { return }
                phase = .results
                rememberSearch(query)
            }
            .frame(maxWidth: .infinity)

            if !query.isEmpty || phase == .results {
                Button {
                    cancelSearch()
                } label: {
                    Text("취소")
                        .fmTypography(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Accent.primary)
                        .padding(.horizontal, Sp.xxs)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색 취소")
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.sm)
        .padding(.bottom, Sp.sm)
        .background(FMColors.Background.bg0)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
        .animation(.fmFast, value: phase)
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

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Text("최근 검색")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Spacer()
                if !recentSearches.isEmpty {
                    Button {
                        recentSearches = []
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
                query = term
                phase = .results
                rememberSearch(term)
            } label: {
                Text(term)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                recentSearches.removeAll { $0 == term }
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
                        query = stripped
                        phase = .results
                        rememberSearch(stripped)
                    }
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
                NavigationLink(value: AppRoute.forYou) {
                    Text("전체 →")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Accent.primary)
                }
                .buttonStyle(.plain)
            }

            if popularMakers.isEmpty {
                Text("아직 인기 메이커 데이터가 없어요.")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .padding(.vertical, Sp.xs)
                    .accessibilityIdentifier("search.makers.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Sp.md) {
                        ForEach(popularMakers) { maker in
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
        NavigationLink(value: AppRoute.otherProfile(uid: maker.id)) {
            VStack(spacing: Sp.xs) {
                FMAvatar(initials: maker.initials, size: .lg)
                    .overlay {
                        Circle()
                            .strokeBorder(FMColors.Accent.soft, lineWidth: 2)
                    }
                Text(maker.handle)
                    .fmTypography(.subhead)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.Text.primary)
                    .lineLimit(1)
                Text("필터 \(maker.filterCount)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            .frame(width: 96)
        }
        .buttonStyle(.plain)
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
                            NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                                FMFilterTile(data: filter.toTileData())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("search.typing.tile.\(index)")
                        }
                    }
                }
            }
            .padding(.horizontal, Sp.md)
            .padding(.vertical, Sp.md)
        }
    }

    private func makerRow(_ maker: PopularMaker) -> some View {
        NavigationLink(value: AppRoute.otherProfile(uid: maker.id)) {
            HStack(spacing: Sp.sm) {
                FMAvatar(initials: maker.initials, size: .sm)
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
    }

    // MARK: - Results

    private var resultsContent: some View {
        Group {
            if filteredFilters.isEmpty {
                FMEmptyState(.noSearchResults(query: query)) {
                    cancelSearch()
                }
                .padding(.top, Sp.xxl)
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
                            NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                                FMFilterTile(data: filter.toTileData())
                            }
                            .buttonStyle(.plain)
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
        guard !query.isEmpty else { return [] }
        let lower = query.lowercased()
        // 컬렉션 분기는 카테고리 필터로만 — 결과 비어있으면 FMEmptyState(.noSearchResults).
        if let initialCategory, initialCategory == "컬렉션" {
            return store.newFiltersList
        }
        return store.filters.filter { f in
            guard f.status == .approved else { return false }
            return f.title.lowercased().contains(lower)
                || f.author.displayName.lowercased().contains(lower)
        }
    }

    private var filteredMakers: [PopularMaker] {
        guard !query.isEmpty else { return [] }
        let lower = query.lowercased()
        return popularMakers.filter { $0.handle.lowercased().contains(lower) }
    }

    private var popularMakers: [PopularMaker] {
        let approved = store.filters.filter { $0.status == .approved }
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

    private func cancelSearch() {
        withAnimation(.fmFast) {
            query = ""
            phase = .browsing
        }
    }

    private func rememberSearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 8 {
            recentSearches = Array(recentSearches.prefix(8))
        }
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
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var currentLineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentLineWidth + size.width > maxWidth, currentLineWidth > 0 {
                totalHeight += currentLineHeight + lineSpacing
                currentLineWidth = size.width + spacing
                currentLineHeight = size.height
            } else {
                currentLineWidth += size.width + spacing
                currentLineHeight = max(currentLineHeight, size.height)
            }
        }
        totalHeight += currentLineHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : currentLineWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var currentLineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += currentLineHeight + lineSpacing
                currentLineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            currentLineHeight = max(currentLineHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview("SearchScreen — Browsing") {
    SearchScreen()
        .environmentObject(MooditStore())
}

#Preview("SearchScreen — Dark") {
    SearchScreen()
        .environmentObject(MooditStore())
        .preferredColorScheme(.dark)
}

#Preview("SearchScreen — XXXLarge") {
    SearchScreen()
        .environmentObject(MooditStore())
        .dynamicTypeSize(.xxxLarge)
}
