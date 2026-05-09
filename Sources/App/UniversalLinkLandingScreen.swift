import DesignSystem
import SwiftUI

struct UniversalLinkLandingScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "공유 링크",
                    subtitle: "링크를 열 수 없을 때 다음 이동 경로를 안내합니다.",
                    symbol: "link.badge.plus"
                )

                FMCard {
                    VStack(alignment: .center, spacing: Sp.md) {
                        FMEmptyStateIllustration(.search, size: 96)
                            .frame(width: 96, height: 96)

                        VStack(spacing: Sp.xs) {
                            Text("이 링크는 더 이상 사용할 수 없어요")
                                .fmTypography(.headline)
                                .foregroundStyle(FMColors.Text.primary)
                                .multilineTextAlignment(.center)
                            Text("잘못된 주소이거나 만료된 초대, 삭제된 필터 링크일 수 있어요. 마켓에서 필터를 다시 찾아보세요.")
                                .fmTypography(.body)
                                .foregroundStyle(FMColors.Text.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("app.deeplink.fallback")
                }

                FMButton("마켓으로 이동", icon: "storefront", variant: .primary, size: .lg) {
                    dismiss()
                }
                .accessibilityIdentifier("app.deeplink.confirm")

                NavigationLink(value: AppRoute.search()) {
                    HStack(spacing: Sp.xs) {
                        Image(systemName: "magnifyingglass")
                        Text("검색으로 찾기")
                            .fmTypography(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(FMColors.Text.primary)
                    .padding(.horizontal, Sp.md)
                    .frame(height: 52)
                    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(FMColors.Border.default, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("app.deeplink.detail")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("공유 링크")
        .navigationBarTitleDisplayMode(.inline)
    }
}
