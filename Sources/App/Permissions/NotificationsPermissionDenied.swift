import DesignSystem
import SwiftUI

// MARK: - NotificationsPermissionDenied
//
// Phase D5 — `mockups/screens/permissions/notifications-denied.html` 와 정합.
// 알림은 강요하지 않으므로 secondary 톤 처리 (Ghost CTA 우세).
public struct NotificationsPermissionDenied: View {
    public var onOpenSettings: () -> Void
    public var onDismiss: () -> Void

    public init(
        onOpenSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
    }

    public var body: some View {
        PermissionScaffold(
            illustrationSymbol: "bell.slash.fill",
            illustrationVariant: .denied,
            title: "알림이 꺼져 있어요",
            body: "새 필터, 댓글, 다운로드 완료 알림을 받으려면 설정에서 켜주세요.",
            onClose: onDismiss,
            closeAccessibilityLabel: "뒤로",
            topExtras: {
                PermissionStepsCard(
                    steps: [
                        .init(text: .permissionStep("설정 → 알림", emphasised: ["설정", "알림"])),
                        .init(text: .permissionStep("moodit 선택", emphasised: ["moodit"])),
                        .init(text: .permissionStep("알림 허용 켜기", emphasised: ["알림 허용"]))
                    ]
                )
            },
            bottom: {
                FMButton("설정 열기", variant: .primary, size: .lg, action: onOpenSettings)
                    .accessibilityIdentifier("permission.notifications.denied.openSettings")
                FMButton("알림 없이 사용", variant: .ghost, size: .md, action: onDismiss)
                    .accessibilityIdentifier("permission.notifications.denied.dismiss")
            }
        )
    }
}

// MARK: - Preview

#Preview("Notifications Denied — Light") {
    NotificationsPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
}

#Preview("Notifications Denied — XXXLarge") {
    NotificationsPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
    .dynamicTypeSize(.xxxLarge)
}

#Preview("Notifications Denied — Dark system") {
    NotificationsPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
