import SwiftUI
import UIKit

// MARK: - FMMotion

/// 모션 토큰 — duration / easing / spring.
/// JSON v1.2.0 `motion` + `MOTION_SPEC.md` §2~6 와 정합.
public enum FMMotion {
    // MARK: Duration (초 단위)

    public enum Duration {
        public static let instant: Double = 0.1   // 100ms
        public static let fast: Double = 0.2      // 200ms
        public static let base: Double = 0.3      // 300ms
        public static let slow: Double = 0.5      // 500ms
    }

    // MARK: Easing (cubic-bezier)

    /// `cubic-bezier(0.2, 0, 0, 1)` — 기본 진입.
    public static let standardCurve = (cx0: 0.2, cy0: 0.0, cx1: 0.0, cy1: 1.0)
    /// `cubic-bezier(0, 0, 0.2, 1)` — 들어옴 (decelerate).
    public static let decelerateCurve = (cx0: 0.0, cy0: 0.0, cx1: 0.2, cy1: 1.0)
    /// `cubic-bezier(0.4, 0, 1, 1)` — 나감 (accelerate).
    public static let accelerateCurve = (cx0: 0.4, cy0: 0.0, cx1: 1.0, cy1: 1.0)
    /// `cubic-bezier(0.34, 1.4, 0.64, 1)` — 탭 응답 (spring).
    public static let springCurve = (cx0: 0.34, cy0: 1.4, cx1: 0.64, cy1: 1.0)

    // MARK: Spring 파라미터

    public enum Spring {
        /// Modal sheet — response 0.4, damping 0.85
        public static let sheet = (response: 0.4, damping: 0.85)
        /// 필터 스와이프 snap — response 0.4, damping 0.80
        public static let swipe = (response: 0.4, damping: 0.80)
        /// 버튼 탭 — response 0.25, damping 0.75
        public static let tap = (response: 0.25, damping: 0.75)
        /// snap back — response 0.35, damping 0.85
        public static let snapBack = (response: 0.35, damping: 0.85)
    }

    // MARK: Shimmer (스켈레톤)

    public enum Shimmer {
        public static let duration: Double = 1.5
        public static let pause: Double = 0.2
        /// 하이라이트 폭 — 전체 요소 폭의 30%
        public static let gradientWidth: Double = 0.30
        /// 5도 기울기
        public static let tiltDegrees: Double = 5
    }

    // MARK: Reduce Motion

    /// 시스템 Reduce Motion 활성 여부.
    /// SwiftUI 에서는 `@Environment(\.accessibilityReduceMotion)` 사용 권장.
    @MainActor
    public static var shouldReduce: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}

// MARK: - Animation extensions

public extension Animation {
    // 기본 ease-out 계열
    static let fmInstant = Animation.easeOut(duration: FMMotion.Duration.instant)
    static let fmFast = Animation.easeOut(duration: FMMotion.Duration.fast)
    static let fmBase = Animation.easeOut(duration: FMMotion.Duration.base)
    static let fmSlow = Animation.easeOut(duration: FMMotion.Duration.slow)

    // Cubic-bezier 토큰
    static let fmStandard = Animation.timingCurve(
        FMMotion.standardCurve.cx0, FMMotion.standardCurve.cy0,
        FMMotion.standardCurve.cx1, FMMotion.standardCurve.cy1,
        duration: FMMotion.Duration.base
    )
    static let fmDecelerate = Animation.timingCurve(
        FMMotion.decelerateCurve.cx0, FMMotion.decelerateCurve.cy0,
        FMMotion.decelerateCurve.cx1, FMMotion.decelerateCurve.cy1,
        duration: FMMotion.Duration.base
    )
    static let fmAccelerate = Animation.timingCurve(
        FMMotion.accelerateCurve.cx0, FMMotion.accelerateCurve.cy0,
        FMMotion.accelerateCurve.cx1, FMMotion.accelerateCurve.cy1,
        duration: FMMotion.Duration.fast
    )
    static let fmEaseOut = Animation.easeOut(duration: FMMotion.Duration.base)
    static let fmEaseIn = Animation.easeIn(duration: FMMotion.Duration.fast)
    static let fmEaseInOut = Animation.easeInOut(duration: FMMotion.Duration.base)

    // Spring — 탭/시트/스와이프
    static let fmSpringSheet = Animation.spring(
        response: FMMotion.Spring.sheet.response,
        dampingFraction: FMMotion.Spring.sheet.damping
    )
    static let fmSpringSwipe = Animation.spring(
        response: FMMotion.Spring.swipe.response,
        dampingFraction: FMMotion.Spring.swipe.damping
    )
    static let fmSpringTap = Animation.spring(
        response: FMMotion.Spring.tap.response,
        dampingFraction: FMMotion.Spring.tap.damping
    )
    static let fmSpringSnapBack = Animation.spring(
        response: FMMotion.Spring.snapBack.response,
        dampingFraction: FMMotion.Spring.snapBack.damping
    )

    /// 일반적으로 권장되는 스프링 (sheet 와 동일).
    static let fmSpring = fmSpringSheet
}
