import DesignSystem
import SwiftUI

// MARK: - PhotosPermissionPriming
//
// Phase D5 — `mockups/screens/permissions/photos-priming.html` 와 정합.
// 사진 라이브러리 (add-only) 권한 priming.
public struct PhotosPermissionPriming: View {
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
            illustrationSymbol: "photo.on.rectangle",
            illustrationVariant: .priming,
            title: "사진을 저장하고 불러오기",
            body: "촬영한 사진을 라이브러리에 저장하거나 기존 사진에 필터를 적용하려면 사진 접근이 필요해요. 선택한 사진만 공유할 수 있어요.",
            onClose: onClose,
            closeAccessibilityLabel: "닫기"
        ) {
            FMButton("사진 선택 또는 모두 허용", variant: .primary, size: .lg, action: onAllow)
                .accessibilityIdentifier("permission.photos.priming.allow")
            FMButton("나중에", variant: .ghost, size: .md, action: onSkip)
                .accessibilityIdentifier("permission.photos.priming.skip")
            PermissionHint(text: "iOS 14+ 에서는 일부 사진만 선택해 공유할 수 있어요.")
        }
    }
}

// MARK: - Preview

#Preview("Photos Priming — Light") {
    PhotosPermissionPriming(
        onAllow: {},
        onSkip: {},
        onClose: {}
    )
}

#Preview("Photos Priming — XXXLarge") {
    PhotosPermissionPriming(
        onAllow: {},
        onSkip: {}
    )
    .dynamicTypeSize(.xxxLarge)
}

#Preview("Photos Priming — Dark system") {
    PhotosPermissionPriming(
        onAllow: {},
        onSkip: {}
    )
    .preferredColorScheme(.dark)
}
