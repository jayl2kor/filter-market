import DesignSystem
import SwiftUI

// MARK: - NotificationsPermissionPriming
//
// Phase D5 — `mockups/screens/permissions/notifications-priming.html` 와 정합.
public struct NotificationsPermissionPriming: View {
    public var onAllow: () -> Void
    public var onSkip: () -> Void
    public var onClose: (() -> Void)?

    public init(
        onAllow: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.onAllow = onAllow
        self.onSkip = onSkip
        self.onClose = onClose
    }

    public var body: some View {
        PermissionScaffold(
            illustrationSymbol: "bell.badge.fill",
            illustrationVariant: .priming,
            title: "놓치고 싶지 않은 순간",
            body: "메이커가 새 필터를 올리거나 내 필터에 댓글이 달렸을 때 알림을 보내드려요. 마케팅 알림은 보내지 않아요.",
            onClose: onClose,
            closeAccessibilityLabel: "닫기"
        ) {
            FMButton("알림 받기", variant: .primary, size: .lg, action: onAllow)
                .accessibilityIdentifier("permission.notifications.priming.allow")
            FMButton("건너뛰기", variant: .ghost, size: .md, action: onSkip)
                .accessibilityIdentifier("permission.notifications.priming.skip")
            PermissionHint(text: "설정에서 종류별로 끌 수 있어요.")
        }
    }
}

// MARK: - Preview

#Preview("Notifications Priming — Light") {
    NotificationsPermissionPriming(
        onAllow: {},
        onSkip: {},
        onClose: {}
    )
}

#Preview("Notifications Priming — XXXLarge") {
    NotificationsPermissionPriming(
        onAllow: {},
        onSkip: {}
    )
    .dynamicTypeSize(.xxxLarge)
}

#Preview("Notifications Priming — Dark system") {
    NotificationsPermissionPriming(
        onAllow: {},
        onSkip: {}
    )
    .preferredColorScheme(.dark)
}
