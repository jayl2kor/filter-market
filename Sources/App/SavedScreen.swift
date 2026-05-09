import DesignSystem
import Models
import SwiftUI

/// 저장됨 탭 — 다운로드한 필터 + 즐겨찾기 목록.
///
/// Phase D2 — 셸 재구성 단계의 placeholder. 기존 `FilterLibraryScreen` 의 후신.
/// Phase D3 (메인 화면 마이그레이션) 에서 본격 구현 예정:
/// - 다운로드 / 좋아요 / 컬렉션 세그먼트 분기
/// - 정렬 (최신/이름/카테고리)
/// - swipe to delete
struct SavedScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @State private var hasAppeared = false
    @State private var query = ""
    @State private var sort: SavedSort = .recent
    @State private var category: SavedCategory = .all
    @State private var isEditing = false
    @State private var selectedFilterIDs: Set<Filter.ID> = []
    @State private var isRefreshing = false
    @State private var showEmptySearch = false

    private let ownsNavigationStack: Bool

    init(ownsNavigationStack: Bool = true) {
        self.ownsNavigationStack = ownsNavigationStack
    }

    private let columns = [
        GridItem(.flexible(), spacing: Sp.sm),
        GridItem(.flexible(), spacing: Sp.sm)
    ]

    private var isLoading: Bool {
        !hasAppeared
    }

    private var visibleFilters: [Filter] {
        let indexed = Dictionary(uniqueKeysWithValues: filterLibraryStore.libraryFilters.enumerated().map { ($0.element.id, $0.offset) })
        let lowerQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var filters = filterLibraryStore.libraryFilters.filter { filter in
            let matchesQuery = lowerQuery.isEmpty
                || filter.title.lowercased().contains(lowerQuery)
                || filter.author.displayName.lowercased().contains(lowerQuery)
            let matchesCategory = category == .all || filter.category == category.filterCategory
            return matchesQuery && matchesCategory
        }
        filters.sort { lhs, rhs in
            switch sort {
            case .recent:
                return (indexed[lhs.id] ?? 0) < (indexed[rhs.id] ?? 0)
            case .popular:
                let lhsCount = lhs.downloadCount > 0 ? lhs.downloadCount : lhs.useCount
                let rhsCount = rhs.downloadCount > 0 ? rhs.downloadCount : rhs.useCount
                if lhsCount == rhsCount { return lhs.title < rhs.title }
                return lhsCount > rhsCount
            case .name:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
        return filters
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
    }

    private var content: some View {
        Group {
            if isLoading {
                skeletonGrid
            } else if filterLibraryStore.libraryFilters.isEmpty {
                emptyDownloadsScroll
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Sp.md) {
                        controls

                        if visibleFilters.isEmpty {
                            filteredEmptyState
                                .accessibilityIdentifier("saved.empty.filtered")
                        } else {
                            LazyVGrid(columns: columns, spacing: Sp.sm) {
                                ForEach(visibleFilters) { filter in
                                    savedTile(filter)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Sp.md)
                    .padding(.top, Sp.sm)
                    .padding(.bottom, FMLayout.tabBarHeight + Sp.xxl)
                }
            }
        }
        .refreshable {
            await refreshSavedFilters()
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("저장됨")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(isEditing ? "완료" : "편집") {
                    isEditing.toggle()
                    if !isEditing {
                        selectedFilterIDs.removeAll()
                    }
                    FMHaptic.selection.play()
                }
                .disabled(filterLibraryStore.libraryFilters.isEmpty)
                .accessibilityIdentifier("saved.edit")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.builtinFilters) {
                    Image(systemName: "camera.filters")
                }
                .accessibilityLabel("기본 필터")
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.fmFast.reducedIfNeeded(reduceMotion)) { hasAppeared = true }
        }
        .onChange(of: visibleFilters.map(\.id)) { _, visibleIDs in
            selectedFilterIDs.formIntersection(Set(visibleIDs))
        }
        .navigationDestination(isPresented: $showEmptySearch) {
            SearchScreen()
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack(spacing: Sp.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(FMColors.Text.tertiary)
                TextField("저장된 필터 검색", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            .padding(.horizontal, Sp.sm)
            .frame(minHeight: 44)
            .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(FMColors.Border.default, lineWidth: 1)
            }
            .accessibilityIdentifier("saved.search")

            HStack(spacing: Sp.sm) {
                Menu {
                    ForEach(SavedSort.allCases) { option in
                        Button {
                            sort = option
                            FMHaptic.selection.play()
                        } label: {
                            if sort == option {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    Label(sort.title, systemImage: "arrow.up.arrow.down")
                        .font(Font.fmSubhead)
                        .foregroundStyle(FMColors.Text.primary)
                        .padding(.horizontal, Sp.sm)
                        .frame(minHeight: 44)
                        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                }
                .accessibilityIdentifier("saved.sort")
                .accessibilityLabel("저장된 필터 정렬")

                if isEditing {
                    Button(role: .destructive) {
                        deleteSelectedFilters()
                    } label: {
                        Label("\(selectedFilterIDs.count)개 삭제", systemImage: "trash")
                            .font(Font.fmSubhead)
                            .padding(.horizontal, Sp.sm)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedFilterIDs.isEmpty)
                    .accessibilityIdentifier("saved.delete.selected")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sp.xs) {
                    ForEach(SavedCategory.allCases) { option in
                        FMChip(option.title, isSelected: category == option, size: .sm) {
                            category = option
                            FMHaptic.selection.play()
                        }
                        .accessibilityIdentifier("saved.category.\(option.rawValue)")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: Sp.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(FMColors.Text.tertiary)
            Text("조건에 맞는 필터가 없어요")
                .font(Font.fmHeadline)
                .foregroundStyle(FMColors.Text.primary)
            Text("검색어나 카테고리 필터를 바꿔보세요.")
                .font(Font.fmBody)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Sp.xxl)
        .frame(maxWidth: .infinity)
    }

    private var emptyDownloadsScroll: some View {
        ScrollView {
            FMEmptyState(.emptyDownloads) {
                showEmptySearch = true
            }
                .frame(maxWidth: .infinity)
                .padding(.top, Sp.xxl)
                .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
    }

    @ViewBuilder
    private func savedTile(_ filter: Filter) -> some View {
        let isSelected = selectedFilterIDs.contains(filter.id)
        if isEditing {
            Button {
                if isSelected {
                    selectedFilterIDs.remove(filter.id)
                } else {
                    selectedFilterIDs.insert(filter.id)
                }
                FMHaptic.selection.play()
            } label: {
                tileView(filter, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saved.tile.\(filter.id.uuidString)")
            .accessibilityLabel("\(filter.title) 선택")
            .accessibilityValue(isSelected ? "선택됨" : "미선택")
        } else {
            NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                tileView(filter, isSelected: false)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saved.tile.\(filter.id.uuidString)")
            .contextMenu {
                Button(role: .destructive) {
                    filterLibraryStore.removeDownloadAndPersist(filter)
                } label: {
                    Label("다운로드 제거", systemImage: "trash")
                }
            }
        }
    }

    private func tileView(_ filter: Filter, isSelected: Bool) -> some View {
        FMFilterTile(data: tileData(for: filter))
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isSelected ? FMColors.Accent.primary : FMColors.Text.inverse)
                        .padding(Sp.xs)
                        .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
                }
            }
    }

    private func deleteSelectedFilters() {
        let targets = filterLibraryStore.libraryFilters.filter { selectedFilterIDs.contains($0.id) }
        targets.forEach { filterLibraryStore.removeDownloadAndPersist($0) }
        selectedFilterIDs.removeAll()
        isEditing = false
        FMHaptic.success.play()
    }

    private func refreshSavedFilters() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await filterLibraryStore.load(force: true)
    }

    private var skeletonGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Sp.sm) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: Sp.xs) {
                        FMSkeleton.rect(height: 200, cornerRadius: R.lg)
                        FMSkeleton.line(width: 80, height: 14)
                        FMSkeleton.line(width: 120, height: 12)
                    }
                }
            }
            .padding(.horizontal, Sp.md)
            .padding(.top, Sp.sm)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxl)
        }
    }

    private func tileData(for filter: Filter) -> FMFilterTileData {
        FMFilterTileData(
            title: filter.title,
            makerName: filter.author.displayName,
            downloadCount: 0,
            priceLabel: nil,
            categoryHint: filter.category.swatch.first,
            categoryKey: filter.category.rawValue
        )
    }
}

private enum SavedSort: String, CaseIterable, Identifiable {
    case recent
    case popular
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "최신순"
        case .popular: "인기순"
        case .name: "이름순"
        }
    }
}

private enum SavedCategory: String, CaseIterable, Identifiable {
    case all
    case cinematic
    case portrait
    case travel
    case vintage
    case bw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "전체"
        case .cinematic: "시네마틱"
        case .portrait: "인물"
        case .travel: "여행"
        case .vintage: "빈티지"
        case .bw: "흑백"
        }
    }

    var filterCategory: FilterCategory? {
        switch self {
        case .all: nil
        case .cinematic: .cinematic
        case .portrait: .portrait
        case .travel: .travel
        case .vintage: .vintage
        case .bw: .bw
        }
    }
}

#Preview("SavedScreen — Light") {
    let store = MooditStore()
    SavedScreen()
        .environmentObject(store)
        .environmentObject(store.filterLibraryStore)
}

#Preview("SavedScreen — Dark") {
    let store = MooditStore()
    SavedScreen()
        .environmentObject(store)
        .environmentObject(store.filterLibraryStore)
        .preferredColorScheme(.dark)
}
