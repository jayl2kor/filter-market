import SwiftUI

// MARK: - FMTypography.Style shorthand

/// `FMTypography.Style` 에 정적 alias 추가.
///
/// Tokens 파일에서는 `FMTypography.body` 처럼 enum 자체에 정의되어 있어
/// `view.fmTypography(.body)` 같은 도트 단축 표기가 동작하지 않는다.
/// 본 확장은 `Style` 타입 자체에 단축 alias 를 노출해 컴포넌트와 화면에서
/// `.body`, `.headline` 등을 그대로 사용할 수 있게 한다.
public extension FMTypography.Style {
    static let display: FMTypography.Style = FMTypography.display
    static let titleLarge: FMTypography.Style = FMTypography.titleLarge
    static let title: FMTypography.Style = FMTypography.title
    static let headline: FMTypography.Style = FMTypography.headline
    static let body: FMTypography.Style = FMTypography.body
    static let callout: FMTypography.Style = FMTypography.callout
    static let subhead: FMTypography.Style = FMTypography.subhead
    static let footnote: FMTypography.Style = FMTypography.footnote
    static let caption: FMTypography.Style = FMTypography.caption
}
