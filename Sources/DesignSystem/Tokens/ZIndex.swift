import CoreFoundation

// MARK: - Z

/// `.zIndex()` 인자로 사용할 레이어 토큰.
/// JSON v1.2.0 `z` 와 정합.
///
/// 주의: SwiftUI `.zIndex()` 는 `Double`. 같은 부모 내에서만 비교 의미가 있음.
public enum Z {
    public static let base: Double = 0
    public static let dropdown: Double = 10
    public static let sticky: Double = 50
    public static let modal: Double = 1000
    public static let popover: Double = 1100
    public static let tooltip: Double = 1200
    public static let toast: Double = 1500
}
