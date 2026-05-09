import DesignSystem
import SwiftUI
import UIKit

// MARK: - LocationPermissionDenied
//
// Phase D5 — `mockups/screens/permissions/location-denied.html` 와 정합.
// 위치는 선택 권한이므로 primary 톤은 secondary 처럼 톤다운된 느낌으로 처리하나,
// FMButton 의 secondary 변형이 가장 가까운 매핑이다.
public struct LocationPermissionDenied: View {
    @StateObject private var permissionCoordinator = PermissionCoordinator()
    public var onOpenSettings: () -> Void
    public var onDismiss: () -> Void
    public var onPermissionGranted: () -> Void

    public init(
        onOpenSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onPermissionGranted: @escaping () -> Void = {}
    ) {
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
        self.onPermissionGranted = onPermissionGranted
    }

    public var body: some View {
        PermissionScaffold(
            illustrationSymbol: "location.slash.fill",
            illustrationVariant: .denied,
            title: "위치 없이도 촬영할 수 있어요",
            body: "위치 권한은 선택 사항입니다. 사진의 EXIF 에 위치를 추가하려면 설정에서 켤 수 있어요.",
            onClose: onDismiss,
            closeAccessibilityLabel: "뒤로",
            topExtras: {
                PermissionStepsCard(
                    steps: [
                        .init(text: .permissionStep("설정 → moodit", emphasised: ["설정", "moodit"])),
                        .init(text: .permissionStep("위치 선택", emphasised: ["위치"])),
                        .init(text: .permissionStep("\"앱을 사용하는 동안\" 선택", emphasised: ["\"앱을 사용하는 동안\""]))
                    ]
                )
            },
            bottom: {
                // mockup 에서 secondary 톤 — 위치는 강요하지 않는 선택 권한.
                FMButton("설정 열기", variant: .secondary, size: .lg, action: onOpenSettings)
                    .accessibilityIdentifier("permission.location.denied.openSettings")
                FMButton("계속 사용", variant: .ghost, size: .md, action: onDismiss)
                    .accessibilityIdentifier("permission.location.denied.dismiss")
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            reevaluatePermission()
        }
    }

    private func reevaluatePermission() {
        guard permissionCoordinator.currentStatus(.location) == .authorized else { return }
        FMHaptic.success.play()
        onPermissionGranted()
    }
}

// MARK: - Preview

#Preview("Location Denied — Light") {
    LocationPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
}

#Preview("Location Denied — XXXLarge") {
    LocationPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
    .dynamicTypeSize(.xxxLarge)
}

#Preview("Location Denied — Dark system") {
    LocationPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
