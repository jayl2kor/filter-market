import DesignSystem
import SwiftUI

// MARK: - PhotosPermissionDenied
//
// Phase D5 — `mockups/screens/permissions/photos-denied.html` 와 정합.
public struct PhotosPermissionDenied: View {
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
            illustrationSymbol: "photo.on.rectangle",
            illustrationVariant: .denied,
            title: "사진 접근이 꺼져 있어요",
            body: "저장 또는 사진 선택을 위해 설정에서 접근을 허용해주세요.",
            onClose: onDismiss,
            closeAccessibilityLabel: "뒤로",
            topExtras: {
                PermissionStepsCard(
                    steps: [
                        .init(text: .permissionStep("설정 앱 열기", emphasised: ["설정"])),
                        .init(text: .permissionStep("filterMarket 선택", emphasised: ["filterMarket"])),
                        .init(text: .permissionStep("사진 → \"전체 사진\" 또는 \"선택된 사진\"", emphasised: ["사진"]))
                    ]
                )
            },
            bottom: {
                FMButton("설정 열기", variant: .primary, size: .lg, action: onOpenSettings)
                    .accessibilityIdentifier("permission.photos.denied.openSettings")
                FMButton("계속 촬영만 하기", variant: .ghost, size: .md, action: onDismiss)
                    .accessibilityIdentifier("permission.photos.denied.dismiss")
            }
        )
    }
}

// MARK: - Preview

#Preview("Photos Denied — Light") {
    PhotosPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
}

#Preview("Photos Denied — XXXLarge") {
    PhotosPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
    .dynamicTypeSize(.xxxLarge)
}

#Preview("Photos Denied — Dark system") {
    PhotosPermissionDenied(
        onOpenSettings: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
