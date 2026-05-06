import SwiftUI

// MARK: - Reduce Motion
//
// Phase D6 — `MOTION_SPEC.md` §8 Reduce Motion 대응.
//
// 시스템 설정(손쉬운 사용 › 모션 줄이기)이 켜진 사용자는 변환(translate/scale/spring)
// 애니메이션에 민감할 수 있다. duration 은 유지하면서 easing 만 단순 ease-out 으로 대체한다.

public extension Animation {
    /// Reduce Motion 이 켜져 있으면 `replacement`, 아니면 `self` 를 반환.
    ///
    /// 호출부:
    /// ```swift
    /// @Environment(\.accessibilityReduceMotion) var reduceMotion
    /// withAnimation(.fmSpringSwipe.reducedIfNeeded(reduceMotion)) { ... }
    /// ```
    func reducedIfNeeded(
        _ reduceMotion: Bool,
        replacement: Animation = .easeOut(duration: FMMotion.Duration.fast)
    ) -> Animation {
        reduceMotion ? replacement : self
    }
}

// MARK: - FMAnimationModifier

/// Reduce Motion 환경값을 자동으로 반영하는 ViewModifier.
///
/// ```swift
/// myView
///     .fmAnimation(.fmSpringSwipe, value: selectedID)
/// ```
public struct FMAnimationModifier<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    let reducedReplacement: Animation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        animation: Animation,
        value: Value,
        reducedReplacement: Animation = .easeOut(duration: FMMotion.Duration.fast)
    ) {
        self.animation = animation
        self.value = value
        self.reducedReplacement = reducedReplacement
    }

    public func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? reducedReplacement : animation,
            value: value
        )
    }
}

public extension View {
    /// Reduce Motion 자동 분기 애니메이션 modifier.
    ///
    /// 변환(spring/scale/translate) 애니메이션은 Reduce Motion 시 단순 ease-out fade 로 대체된다.
    func fmAnimation<V: Equatable>(
        _ animation: Animation,
        value: V,
        reducedReplacement: Animation = .easeOut(duration: FMMotion.Duration.fast)
    ) -> some View {
        modifier(FMAnimationModifier(animation: animation, value: value, reducedReplacement: reducedReplacement))
    }
}

// MARK: - Reduced transitions

public extension AnyTransition {
    /// Reduce Motion 환경에서는 fade, 아니면 `regular` 를 사용.
    ///
    /// SwiftUI 의 `.transition` 은 환경값을 받지 못하므로 호출부에서 분기.
    static func fmReducible(_ regular: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : regular
    }
}
