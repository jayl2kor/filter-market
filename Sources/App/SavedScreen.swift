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
    @EnvironmentObject private var store: MooditStore

    private let columns = [
        GridItem(.flexible(), spacing: Sp.sm),
        GridItem(.flexible(), spacing: Sp.sm)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.libraryFilters.isEmpty {
                    FMEmptyState(.emptyDownloads)
                        .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: Sp.sm) {
                            ForEach(store.libraryFilters) { filter in
                                NavigationLink {
                                    FilterDetailScreen(filter: filter)
                                } label: {
                                    FMFilterTile(data: tileData(for: filter))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("saved.tile.\(filter.id.uuidString)")
                            }
                        }
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.sm)
                        .padding(.bottom, FMLayout.tabBarHeight + Sp.xxl)
                    }
                }
            }
            .background(FMColors.Background.bg1)
            .navigationTitle("저장됨")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func tileData(for filter: Filter) -> FMFilterTileData {
        FMFilterTileData(
            title: filter.title,
            makerName: filter.author.displayName,
            downloadCount: 0,
            priceLabel: nil,
            categoryHint: filter.category.swatch.first
        )
    }
}

#Preview("SavedScreen — Light") {
    SavedScreen()
        .environmentObject(MooditStore())
}

#Preview("SavedScreen — Dark") {
    SavedScreen()
        .environmentObject(MooditStore())
        .preferredColorScheme(.dark)
}
