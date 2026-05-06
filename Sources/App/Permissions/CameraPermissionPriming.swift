import DesignSystem
import SwiftUI

// MARK: - CameraPermissionPriming
//
// Phase D5 — `mockups/screens/permissions/camera-priming.html` 와 정합.
// 시스템 다이얼로그 직전 사용자 맥락 화면.
public struct CameraPermissionPriming: View {
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
            illustrationSymbol: "camera.fill",
            illustrationVariant: .priming,
            title: "필터를 입혀 촬영하기",
            body: "라이브 프리뷰에서 필터를 적용해 사진을 찍으려면 카메라 접근이 필요해요. 촬영한 사진은 언제든 저장 또는 삭제할 수 있어요.",
            onClose: onClose,
            closeAccessibilityLabel: "닫기"
        ) {
            FMButton("허용", variant: .primary, size: .lg, action: onAllow)
                .accessibilityIdentifier("permission.camera.priming.allow")
            FMButton("나중에", variant: .ghost, size: .md, action: onSkip)
                .accessibilityIdentifier("permission.camera.priming.skip")
            PermissionHint(text: "설정에서 언제든 변경할 수 있어요.")
        }
    }
}

// MARK: - Preview

#Preview("Camera Priming — Light") {
    CameraPermissionPriming(
        onAllow: {},
        onSkip: {},
        onClose: {}
    )
}

#Preview("Camera Priming — XXXLarge") {
    CameraPermissionPriming(
        onAllow: {},
        onSkip: {}
    )
    .dynamicTypeSize(.xxxLarge)
}

#Preview("Camera Priming — Dark system") {
    // 권한 화면은 라이트 강제 — 시스템이 다크여도 라이트로 노출되어야 함.
    CameraPermissionPriming(
        onAllow: {},
        onSkip: {}
    )
    .preferredColorScheme(.dark)
}
