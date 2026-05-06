import DesignSystem
import SwiftUI

/// 검색 탭 placeholder.
///
/// Phase D2 — 셸 재구성 단계에서 임시로 추가된 화면.
/// Phase D3 (메인 화면 마이그레이션) 에서 본격 구현 예정:
/// - 실제 검색 API 연결
/// - 카테고리/메이커/태그 필터
/// - 최근 검색어 + 추천 키워드
struct SearchScreen: View {
    @State private var query: String = ""

    private let suggestedKeywords = ["야경", "필름", "빈티지", "흑백", "포트레이트", "여행", "음식"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Sp.lg) {
                    FMTextField.search(
                        text: $query,
                        placeholder: "필터, 메이커 검색"
                    )
                    .padding(.horizontal, Sp.md)
                    .padding(.top, Sp.sm)

                    if query.isEmpty {
                        recommendedSection
                    } else {
                        FMEmptyState(.noSearchResults(query: query))
                            .padding(.top, Sp.xxl)
                    }
                }
                .padding(.bottom, Sp.xxxl)
            }
            .background(FMColors.Background.bg1)
            .navigationTitle("검색")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("추천 키워드")
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)
                .padding(.horizontal, Sp.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sp.xs) {
                    ForEach(suggestedKeywords, id: \.self) { keyword in
                        Button {
                            query = keyword
                        } label: {
                            Text(keyword)
                                .fmTypography(.subhead)
                                .padding(.horizontal, Sp.md)
                                .padding(.vertical, Sp.xs)
                                .background(FMColors.Background.bg2, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                                }
                                .foregroundStyle(FMColors.Text.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search.suggested.\(keyword)")
                    }
                }
                .padding(.horizontal, Sp.md)
            }
        }
    }
}

#Preview("SearchScreen — Light") {
    SearchScreen()
        .environmentObject(FilterMarketStore())
}

#Preview("SearchScreen — Dark") {
    SearchScreen()
        .environmentObject(FilterMarketStore())
        .preferredColorScheme(.dark)
}
