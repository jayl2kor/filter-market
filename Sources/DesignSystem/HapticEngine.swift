import UIKit

// MARK: - FMHaptic
//
// Phase D6 — `MOTION_SPEC.md` §7 햅틱 가이드의 코드 정착.
//
// 화면 단의 `UIImpactFeedbackGenerator(style:)` 등 직접 호출을 본 wrapper 로 대체한다.
// 항상 메인 스레드에서 실행한다 (`@MainActor`).

/// filterMarket 앱 전체에서 사용하는 햅틱 종류.
///
/// 의미 단위로 정의되어 있으며 — 어떤 `UIFeedbackGenerator` 를 쓸지는 본 enum 내부에서
/// 결정한다. 호출부는 **무엇이 일어났는지** 만 표현한다.
public enum FMHaptic: Sendable {
    // 일반 임팩트 — 버튼/카드 탭 등 시각 변화 동반
    case light
    case medium
    case heavy
    /// 슬라이더 경계 등 단단한 임팩트.
    case rigid
    /// 풀투리프레시 임계 등 부드러운 임팩트.
    case soft

    // 알림 임팩트 — 시스템 의미 전달
    case success
    case warning
    case error

    /// 칩/세그먼트/Picker 등 선택 변경.
    case selection

    /// 햅틱 재생.
    @MainActor
    public func play() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

/// `FMHaptic.x.play()` 의 함수형 단축. 가독성 위주로 호출되는 곳에서 사용.
@MainActor
@inlinable
public func fmHaptic(_ haptic: FMHaptic) {
    haptic.play()
}
