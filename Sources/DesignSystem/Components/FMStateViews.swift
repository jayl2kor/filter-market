import SwiftUI

/// 일관된 로딩 상태 — 가운데 정렬 프로그레스 + 선택적 보조 텍스트.
public struct FMLoadingState: View {
    private let caption: String?

    public init(caption: String? = nil) {
        self.caption = caption
    }

    public var body: some View {
        VStack(spacing: Sp.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(FMColors.Text.secondary)
            if let caption {
                Text(caption)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption ?? "로딩 중")
    }
}

/// 일관된 오류 상태 — 아이콘 + 메시지 + 재시도 CTA.
public struct FMErrorState: View {
    private let title: String
    private let detail: String?
    private let retryTitle: String
    private let retry: (() -> Void)?

    public init(
        title: String = "문제가 생겼어요",
        detail: String? = nil,
        retryTitle: String = "다시 시도",
        retry: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.retryTitle = retryTitle
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: Sp.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(FMColors.Semantic.error)
                .accessibilityHidden(true)

            VStack(spacing: Sp.xs) {
                Text(title)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                    .multilineTextAlignment(.center)

                if let detail {
                    Text(detail)
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                }
            }

            if let retry {
                FMButton(retryTitle, variant: .primary, size: .md, action: retry)
                    .frame(maxWidth: 240)
            }
        }
        .padding(.horizontal, Sp.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail ?? "")")
    }
}

#Preview("Loading") {
    FMLoadingState(caption: "필터를 불러오는 중")
        .background(FMColors.Background.bg1)
}

#Preview("Error with retry") {
    FMErrorState(
        title: "필터를 불러올 수 없어요",
        detail: "네트워크 연결을 확인하고 다시 시도해주세요.",
        retry: {}
    )
    .background(FMColors.Background.bg1)
}

#Preview("Error without retry") {
    FMErrorState(
        title: "권한이 부족해요",
        detail: "이 작업을 수행하려면 모더레이터 권한이 필요합니다."
    )
    .background(FMColors.Background.bg1)
}
