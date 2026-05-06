import CoreFoundation

// MARK: - Opacity

/// 인터랙션·비활성 알파 토큰.
/// JSON v1.2.0 `interaction` / `disabled` 와 정합.
public enum Opacity {
    // Interaction overlays (라이트 기준 — 다크는 컬러 토큰에서 별도 처리)
    /// 호버 알파 오버레이
    public static let hover: CGFloat = 0.04
    /// 탭 다운 알파 오버레이
    public static let pressed: CGFloat = 0.08
    /// 선택된 항목 옅은 골드 오버레이
    public static let selected: CGFloat = 0.12

    // Disabled
    /// 비활성 텍스트 opacity
    public static let textDisabled: CGFloat = 0.4
    /// 비활성 배경 opacity
    public static let fillDisabled: CGFloat = 0.3
    /// 비활성 보더 opacity
    public static let borderDisabled: CGFloat = 0.5
}

// MARK: - FocusRing

/// 키보드 포커스 링 — 외곽 2px + 2px offset.
public enum FocusRing {
    public static let width: CGFloat = 2
    public static let offset: CGFloat = 2
}
