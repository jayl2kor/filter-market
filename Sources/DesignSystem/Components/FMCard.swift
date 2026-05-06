import SwiftUI

// MARK: - FMCard

/// 표준 카드 컨테이너.
///
/// `bg/2` 흰 fill + `R.lg` (12) 라운드 + 1px subtle border + soft shadow.
/// `DESIGN_SYSTEM.md` §8.3 Card 스펙과 정합.
public struct FMCard<Content: View>: View {
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let content: Content

    public init(
        padding: CGFloat = Sp.md,
        cornerRadius: CGFloat = R.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

// MARK: - View modifier

public extension View {
    /// 임의의 뷰를 카드 스타일로 래핑.
    func fmCard(
        padding: CGFloat = Sp.md,
        cornerRadius: CGFloat = R.lg
    ) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview("FMCard — variations") {
    ScrollView {
        VStack(spacing: Sp.md) {
            FMCard {
                VStack(alignment: .leading, spacing: Sp.xs) {
                    Text("심플 카드")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("필터를 만들어 마켓에 등록하세요. 다른 사용자들과 공유할 수 있어요.")
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }

            FMCard(padding: Sp.sm) {
                HStack(spacing: Sp.sm) {
                    RoundedRectangle(cornerRadius: R.md)
                        .fill(FMColors.Accent.bg)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(FMColors.Accent.primary)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("가로 카드")
                            .fmTypography(.headline)
                            .foregroundStyle(FMColors.Text.primary)
                        Text("아이콘 + 텍스트 조합")
                            .fmTypography(.subhead)
                            .foregroundStyle(FMColors.Text.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(FMColors.Text.tertiary)
                }
            }

            // modifier 스타일
            VStack(alignment: .leading, spacing: Sp.xs) {
                Text("modifier 스타일")
                    .fmTypography(.headline)
                Text(".fmCard() 로 직접 적용")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
            }
            .fmCard()
        }
        .padding(Sp.md)
    }
    .background(FMColors.Background.bg1)
}

#Preview("FMCard — Dark") {
    FMCard {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("다크 모드 카드")
                .fmTypography(.headline)
                .foregroundStyle(FMColors.Text.primary)
            Text("배경과 보더가 자동 전환됩니다.")
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
        }
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg1)
    .preferredColorScheme(.dark)
}
