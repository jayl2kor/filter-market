import DesignSystem
import SwiftUI

/// 백엔드 read 실패 상태를 그리는 공용 화면. 한 화면 전체가 로드 결과에
/// 의존하는 흐름에서 `LoadState.failed` 또는 `notFound` 케이스를 표시한다.
///
/// 모양/접근성은 `ProfileScreen` 의 기존 "프로필을 불러오지 못했어요" UI 와 1:1.
struct BackendErrorView: View {
    let title: String
    let message: String?
    let iconSystemName: String
    let retry: (() async -> Void)?
    let retryAccessibilityIdentifier: String?

    init(
        title: String,
        message: String? = nil,
        iconSystemName: String = "wifi.exclamationmark",
        retryAccessibilityIdentifier: String? = nil,
        retry: (() async -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.iconSystemName = iconSystemName
        self.retry = retry
        self.retryAccessibilityIdentifier = retryAccessibilityIdentifier
    }

    var body: some View {
        VStack(spacing: Sp.md) {
            Image(systemName: iconSystemName)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(FMColors.Text.tertiary)
                .frame(width: 96, height: 96)
                .background(FMColors.Background.bg2, in: Circle())

            VStack(spacing: Sp.xs) {
                Text(title)
                    .fmTypography(.title)
                    .foregroundStyle(FMColors.Text.primary)
                if let message {
                    Text(message)
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let retry {
                FMButton("다시 시도", variant: .primary, size: .md) {
                    Task { await retry() }
                }
                .accessibilityIdentifier(retryAccessibilityIdentifier ?? "backendErrorView.retry")
            }
        }
        .frame(maxWidth: .infinity)
    }
}
