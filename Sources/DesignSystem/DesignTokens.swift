import SwiftUI

// MARK: - Legacy v1.0 토큰 (deprecated)
//
// 이 파일은 Phase D0 이전의 다크-only 초안 토큰을 보존한다.
// 새 토큰은 `Sources/DesignSystem/Tokens/*.swift` (`FMColors`, `FMTypography`, `Sp`, `R`, `Animation.fmEaseOut` …)
// 에서 정의되며, JSON v1.2.0 라이트/다크 듀얼 모드와 정합한다.
//
// 기존 `FMColor.*` / `FMSpacing.*` 사용처는 점진적으로 새 API로 마이그레이션 예정.
// Phase D1 (컴포넌트 라이브러리) 이후 본 파일은 삭제된다.

@available(*, deprecated, message: "Use FMColors.Background.bg0 / Accent.primary etc. (see Sources/DesignSystem/Tokens/Colors.swift)")
public enum FMColor {
    /// 기존 다크 캔버스 — 새 토큰 `FMColors.Background.bg0` (라이트/다크 듀얼) 사용 권장.
    public static let background = FMColors.Background.bg0
    /// 기존 다크 카드 표면 — 새 토큰 `FMColors.Background.bg2` 사용 권장.
    public static let surface = FMColors.Background.bg2
    /// 기존 청록 악센트 — 새 토큰 `FMColors.Accent.primary` (라이트 #B8853A / 다크 #E8B86D 골드) 사용 권장.
    /// 주의: v1.0 청록(#29BA9E)에서 v1.2 골드로 변경됨. 색상 자체가 다름.
    public static let accent = FMColors.Accent.primary
}

@available(*, deprecated, message: "Use Sp.xxs / xs / sm / md / lg / xl / xxl (see Sources/DesignSystem/Tokens/Spacing.swift)")
public enum FMSpacing {
    public static let xSmall: CGFloat = Sp.xxs   // 4
    public static let small: CGFloat = Sp.xs     // 8
    public static let medium: CGFloat = Sp.sm    // 12
    public static let large: CGFloat = Sp.lg     // 20
    public static let xLarge: CGFloat = Sp.xxl   // 32
}
