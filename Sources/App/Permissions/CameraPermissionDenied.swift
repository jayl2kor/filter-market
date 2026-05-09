import DesignSystem
import SwiftUI
import UIKit

// MARK: - CameraPermissionDenied
//
// Phase D5 — `mockups/screens/permissions/camera-denied.html` 와 정합.
// 시스템 다이얼로그 거부 후 설정 앱으로 안내하는 fallback 화면.
public struct CameraPermissionDenied: View {
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
            illustrationSymbol: "camera.fill",
            illustrationVariant: .denied,
            title: "카메라 접근이 꺼져 있어요",
            body: "설정 앱에서 moodit 의 카메라 접근을 켜주세요.",
            onClose: onDismiss,
            closeAccessibilityLabel: "뒤로",
            topExtras: {
                PermissionStepsCard(
                    steps: [
                        .init(text: .permissionStep("설정 앱 열기", emphasised: ["설정"])),
                        .init(text: .permissionStep("moodit 항목으로 이동", emphasised: ["moodit"])),
                        .init(text: .permissionStep("카메라 토글 켜기", emphasised: ["카메라"]))
                    ]
                )
            },
            bottom: {
                FMButton("설정 열기", variant: .primary, size: .lg, action: onOpenSettings)
                    .accessibilityIdentifier("permission.camera.denied.openSettings")
                FMButton("마켓 둘러보기", variant: .ghost, size: .md, action: onDismiss)
                    .accessibilityIdentifier("permission.camera.denied.dismiss")
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            reevaluatePermission()
        }
    }

    private func reevaluatePermission() {
        guard permissionCoordinator.currentStatus(.camera) == .authorized else { return }
        FMHaptic.success.play()
        onPermissionGranted()
    }
}

// MARK: - Preview

#Preview("Camera Denied — Light") {
    CameraPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
}

#Preview("Camera Denied — XXXLarge") {
    CameraPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
    .dynamicTypeSize(.xxxLarge)
}

#Preview("Camera Denied — Dark system") {
    CameraPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
