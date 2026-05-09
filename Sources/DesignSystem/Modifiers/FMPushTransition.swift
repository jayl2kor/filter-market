import SwiftUI

// MARK: - FMPushTransition

/// `MOTION_SPEC.md` §2.1 Push 정합 modal-style 전환.
///
/// SwiftUI 의 기본 `NavigationStack` push 는 부모 화면을 그대로 두지만, 명세는
/// 부모 화면이 `translateX(-30%) + opacity 0.7` 로 살짝 밀리는 효과를 정의한다.
/// `NavigationStack` 자체의 전환은 시스템 제어 영역이므로, 여기서는 시트 / 풀스크린
/// 컨테이너 또는 커스텀 router 에 적용 가능한 전환 modifier 만 제공한다.
public extension AnyTransition {
    /// 새 화면이 오른쪽에서 들어오고, 사라질 때 오른쪽으로 다시 나가는 push 전환.
    /// `MOTION_SPEC` 의 `decelerate` 이징 + 300ms duration.
    static var fmPush: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    /// Reduce Motion 시 fade 로 자동 대체. 호출처에서
    /// `@Environment(\.accessibilityReduceMotion)` 받은 값을 전달.
    static func fmPushReducible(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .fmPush
    }

    /// 부모 화면이 살짝 뒤로 밀리는 fade-back 전환 — 모달/sheet 진입 부모 layer 에 사용.
    /// `MOTION_SPEC.md` §2.1 의 부모 화면 `translateX(-30%) + opacity 0.7` 정합.
    static var fmFadeBack: AnyTransition {
        .modifier(
            active: FMFadeBackModifier(progress: 1),
            identity: FMFadeBackModifier(progress: 0)
        )
    }
}

private struct FMFadeBackModifier: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(1.0 - 0.06 * progress, anchor: .center)
            .opacity(1.0 - 0.30 * progress)
            .offset(x: -32 * progress)
    }
}

// MARK: - View extensions

public extension View {
    /// `MOTION_SPEC.md` §2 정합 push 전환 + Reduce Motion 분기 적용.
    ///
    /// 사용 예:
    /// ```swift
    /// if showDetail {
    ///     DetailView()
    ///         .fmPushTransition()
    /// }
    /// ```
    func fmPushTransition() -> some View {
        modifier(FMPushTransitionModifier())
    }

    /// 부모 layer 가 modal 진입 시 살짝 뒤로 빠지는 효과.
    /// modal/sheet 가 위로 올라올 때 부모에 적용.
    func fmFadeBack(when: Bool) -> some View {
        modifier(FMFadeBackReduceMotionModifier(when: when))
    }
}

private struct FMFadeBackReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let when: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (when ? 0.94 : 1.0), anchor: .center)
            .opacity(when ? 0.70 : 1.0)
            .animation(.fmBase.reducedIfNeeded(reduceMotion), value: when)
    }
}

private struct FMPushTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(.fmPushReducible(reduceMotion: reduceMotion))
    }
}

// MARK: - Preview

private struct FMPushTransitionPreview: View {
    @State private var showSecond = false

    var body: some View {
        ZStack {
            // 부모 화면
            VStack {
                Text("부모 화면")
                    .fmTypography(.titleLarge)
                    .foregroundStyle(FMColors.Text.primary)
                Button("Push 전환 토글") {
                    withAnimation(.fmBase) { showSecond.toggle() }
                }
                .padding()
                .background(FMColors.Accent.primary.opacity(0.15))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FMColors.Background.bg1)
            .fmFadeBack(when: showSecond)

            // 자식 화면 (push)
            if showSecond {
                VStack {
                    Text("자식 화면")
                        .fmTypography(.titleLarge)
                        .foregroundStyle(FMColors.Text.primary)
                    Button("닫기") {
                        withAnimation(.fmBase) { showSecond = false }
                    }
                    .padding()
                    .background(FMColors.Background.bg2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FMColors.Background.bg2)
                .fmPushTransition()
            }
        }
    }
}

#Preview("FMPushTransition — Light") {
    FMPushTransitionPreview()
}

#Preview("FMPushTransition — Dark") {
    FMPushTransitionPreview()
        .preferredColorScheme(.dark)
}
