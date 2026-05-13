import DesignSystem
import SwiftUI

/// 깊은 NavigationStack에서 탭 루트로 돌아가거나 다른 탭으로 전환할 수 있는 환경 클로저.
///
/// `RootShell`이 탭별 path Binding을 소유하므로, 하위 화면들은
/// `@Environment(\.popToTabRoot)` / `@Environment(\.switchTabAndClear)`로 접근한다.
///
/// 사용 예:
/// ```swift
/// @Environment(\.popToTabRoot) private var popToTabRoot
///
/// Button("Market으로 돌아가기") { popToTabRoot(.market) }
/// ```
enum TabNavigationEnvironment {
    static let defaultPop: @MainActor @Sendable (FMTab) -> Void = { _ in }
    static let defaultSwitch: @MainActor @Sendable (FMTab) -> Void = { _ in }
}

private struct PopToTabRootKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable (FMTab) -> Void = TabNavigationEnvironment.defaultPop
}

private struct SwitchTabAndClearKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable (FMTab) -> Void = TabNavigationEnvironment.defaultSwitch
}

extension EnvironmentValues {
    /// 지정한 탭의 NavigationStack path를 비워 루트로 되돌린다.
    /// 현재 선택된 탭은 바뀌지 않는다.
    var popToTabRoot: @MainActor @Sendable (FMTab) -> Void {
        get { self[PopToTabRootKey.self] }
        set { self[PopToTabRootKey.self] = newValue }
    }

    /// 지정한 탭으로 전환하고 해당 탭의 path를 비운다.
    /// 카메라(`.shutter`)는 탭 전환 대신 fullScreenCover로 처리된다.
    var switchTabAndClear: @MainActor @Sendable (FMTab) -> Void {
        get { self[SwitchTabAndClearKey.self] }
        set { self[SwitchTabAndClearKey.self] = newValue }
    }
}

// MARK: - RouteRouter

/// 화면의 navigation 호출을 한 곳으로 모아 depth budget(<= 4)을 강제하는 라우터.
///
/// 호출 측은 `NavigationLink(value:)` / `path.append` 를 직접 쓰는 대신
/// `router.navigate(to:)` 를 사용한다. 라우터는 route 의 `preferredPresentation` 과
/// 현재 stack depth 를 보고 push / sheet / fullScreenCover 중 하나로 라우팅한다.
///
/// `RootShell` 이 탭별로 인스턴스를 만들어 환경에 주입한다.
struct RouteRouter {
    /// 모든 탭 NavigationStack 의 path 길이가 넘으면 안 되는 한도.
    static let maxStackDepth = 4

    let currentDepth: Int
    let push: @MainActor (AppRoute) -> Void
    let presentSheet: @MainActor (AppRoute) -> Void
    let presentCover: @MainActor (AppRoute) -> Void

    /// route 의 선호 표시 방식과 현재 depth 에 따라 알맞은 표시 채널을 고른다.
    /// `hardGuard` 가 true 이고 push 가 depth budget 을 초과하면 sheet 로 격리한다.
    /// 기본값 true — depth 4 한도를 hard 강제.
    @MainActor
    func navigate(to route: AppRoute, hardGuard: Bool = true) {
        switch route.preferredPresentation {
        case .push:
            if hardGuard, currentDepth >= Self.maxStackDepth - 1 {
                presentSheet(route)
            } else {
                push(route)
            }
        case .sheet:
            presentSheet(route)
        case .fullScreenCover:
            presentCover(route)
        }
    }
}

private struct RouteRouterKey: EnvironmentKey {
    static let defaultValue = RouteRouter(
        currentDepth: 0,
        push: { _ in },
        presentSheet: { _ in },
        presentCover: { _ in }
    )
}

extension EnvironmentValues {
    /// 현재 탭의 navigation 라우터.
    /// 하위 뷰는 `@Environment(\.routeRouter)` 로 받아 `router.navigate(to: ...)` 호출.
    var routeRouter: RouteRouter {
        get { self[RouteRouterKey.self] }
        set { self[RouteRouterKey.self] = newValue }
    }
}
