import SwiftUI

// MARK: - FMTypography

/// 9단계 타입 스케일.
/// JSON v1.2.0 — `docs/DESIGN_TOKENS.json` `typography.scale` 와 정합.
///
/// 각 스타일은 `Font` (시스템 폰트) + 권장 lineHeight + tracking 값 보유.
/// 한글 letter-spacing 은 `.tracking()` modifier 로 적용한다.
public enum FMTypography {
    /// (size, lineHeight, weight, letterSpacing) — 토큰 spec.
    public struct Style: Sendable {
        public let size: CGFloat
        public let lineHeight: CGFloat
        public let weight: Font.Weight
        public let letterSpacing: CGFloat

        public var font: Font {
            Font.system(size: size, weight: weight, design: .default)
        }

        /// `lineHeight - size` — `.lineSpacing()` modifier 인자.
        public var lineSpacing: CGFloat {
            max(0, lineHeight - size)
        }
    }

    // 9단계 — DESIGN_TOKENS.json 값 그대로
    public static let display = Style(size: 34, lineHeight: 41, weight: .bold, letterSpacing: -0.4)
    public static let titleLarge = Style(size: 28, lineHeight: 34, weight: .bold, letterSpacing: -0.3)
    public static let title = Style(size: 22, lineHeight: 28, weight: .semibold, letterSpacing: -0.2)
    public static let headline = Style(size: 17, lineHeight: 22, weight: .semibold, letterSpacing: -0.1)
    public static let body = Style(size: 15, lineHeight: 20, weight: .regular, letterSpacing: 0)
    public static let callout = Style(size: 14, lineHeight: 19, weight: .medium, letterSpacing: 0)
    public static let subhead = Style(size: 13, lineHeight: 18, weight: .medium, letterSpacing: 0)
    public static let footnote = Style(size: 12, lineHeight: 16, weight: .regular, letterSpacing: 0)
    public static let caption = Style(size: 11, lineHeight: 13, weight: .medium, letterSpacing: 0.2)
}

// MARK: - Font extensions

public extension Font {
    static let fmDisplay = FMTypography.display.font
    static let fmTitleLarge = FMTypography.titleLarge.font
    static let fmTitle = FMTypography.title.font
    static let fmHeadline = FMTypography.headline.font
    static let fmBody = FMTypography.body.font
    static let fmCallout = FMTypography.callout.font
    static let fmSubhead = FMTypography.subhead.font
    static let fmFootnote = FMTypography.footnote.font
    static let fmCaption = FMTypography.caption.font
}

// MARK: - View modifier

public extension View {
    /// 토큰 스타일을 한 번에 적용 (font + tracking + lineSpacing).
    func fmTypography(_ style: FMTypography.Style) -> some View {
        self
            .font(style.font)
            .tracking(style.letterSpacing)
            .lineSpacing(style.lineSpacing)
    }
}
