import CoreFoundation

// MARK: - R (Radius)

/// 코너 라운드 토큰.
/// JSON v1.2.0 `radius` 와 정합.
public enum R {
    /// 풀스크린 사진, 카메라 프리뷰
    public static let none: CGFloat = 0
    /// 칩, 작은 인디케이터, 배지
    public static let sm: CGFloat = 4
    /// 버튼, 입력 필드, 일반 카드
    public static let md: CGFloat = 8
    /// 필터 타일, 큰 카드, 리스트 그룹
    public static let lg: CGFloat = 12
    /// 모달 / 시트 상단
    public static let xl: CGFloat = 16
    /// 아바타, 토글, FAB
    public static let full: CGFloat = 9999
}
