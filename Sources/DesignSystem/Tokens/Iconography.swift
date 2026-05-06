import CoreFoundation

// MARK: - IconSize

/// 아이콘 사이즈 토큰.
/// JSON v1.2.0 `icon.size` 와 정합.
///
/// SF Symbols wrapper 는 Phase D1 에서 컴포넌트 라이브러리로 추가 예정.
public enum IconSize {
    public static let xs: CGFloat = 14
    public static let sm: CGFloat = 16
    public static let md: CGFloat = 20
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 28
    public static let xxl: CGFloat = 32  // JSON: 2xl
}

// MARK: - IconStroke

public enum IconStroke {
    public static let `default`: CGFloat = 1.5
    public static let bold: CGFloat = 2.0
}
