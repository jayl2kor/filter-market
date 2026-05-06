import DesignSystem
import SwiftUI

// MARK: - LocationPermissionPriming
//
// Phase D5 — `mockups/screens/permissions/location-priming.html` 와 정합.
// EXIF 태그 전용 — `WhenInUse` 만 요청한다.
public struct LocationPermissionPriming: View {
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
            illustrationSymbol: "location.fill",
            illustrationVariant: .priming,
            title: "사진에 위치 정보 추가 (선택)",
            body: "촬영한 사진의 EXIF 에 위치를 기록할 수 있어요. 마켓에 업로드하는 사진의 위치는 자동으로 제거돼요.",
            onClose: onClose,
            closeAccessibilityLabel: "닫기"
        ) {
            FMButton("사용하는 동안 허용", variant: .primary, size: .lg, action: onAllow)
                .accessibilityIdentifier("permission.location.priming.allow")
            FMButton("위치 없이 촬영", variant: .ghost, size: .md, action: onSkip)
                .accessibilityIdentifier("permission.location.priming.skip")
            PermissionHint(text: "백그라운드에서 위치를 추적하지 않아요.")
        }
    }
}

// MARK: - Preview

#Preview("Location Priming — Light") {
    LocationPermissionPriming(
        onAllow: {},
        onSkip: {},
        onClose: {}
    )
}

#Preview("Location Priming — XXXLarge") {
    LocationPermissionPriming(
        onAllow: {},
        onSkip: {}
    )
    .dynamicTypeSize(.xxxLarge)
}

#Preview("Location Priming — Dark system") {
    LocationPermissionPriming(
        onAllow: {},
        onSkip: {}
    )
    .preferredColorScheme(.dark)
}
