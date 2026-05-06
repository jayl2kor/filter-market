import CoreFoundation

// MARK: - Sp

/// 4pt 베이스 스페이싱 토큰.
/// JSON v1.2.0 `spacing` 과 정합.
public enum Sp {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32  // JSON: 2xl
    public static let xxxl: CGFloat = 48 // JSON: 3xl
    public static let xxxxl: CGFloat = 64 // JSON: 4xl
}

// MARK: - Layout constants

/// 레이아웃 상수 — JSON v1.2.0 `layout` 과 정합.
public enum FMLayout {
    /// 화면 좌우 기본 패딩
    public static let screenPadding: CGFloat = 16
    /// 탭바 높이 (안전영역 제외)
    public static let tabBarHeight: CGFloat = 49
    /// 탑바 높이
    public static let topBarHeight: CGFloat = 44
    /// 최소 탭 영역 (HIG)
    public static let minTapTarget: CGFloat = 44
    /// 다이내믹 아일랜드 영역
    public static let safeAreaTop: CGFloat = 59
    /// 홈 인디케이터 영역
    public static let safeAreaBottom: CGFloat = 34
}
