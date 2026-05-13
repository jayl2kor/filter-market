import SwiftUI

/// Tab-stack 외부에서 sheet / fullScreenCover 를 표시하기 위한 코디네이터.
///
/// `RouteRouter` 가 `preferredPresentation` 에 따라 push 대신 이 코디네이터로
/// 라우트를 흘려보내, NavigationStack 의 path 깊이가 4 단계를 넘지 않도록 한다.
///
/// 사용 예:
/// ```swift
/// @EnvironmentObject private var sheetCoordinator: SheetCoordinator
/// sheetCoordinator.present(.reviews(filterId: id))
/// ```
@MainActor
final class SheetCoordinator: ObservableObject {
    /// 현재 표시 중인 sheet 라우트. nil 이면 sheet 가 닫혀 있다.
    @Published var sheetRoute: AppRoute?

    /// 현재 표시 중인 fullScreenCover 라우트. nil 이면 cover 가 닫혀 있다.
    @Published var coverRoute: AppRoute?

    func present(_ route: AppRoute) {
        sheetRoute = route
    }

    func presentCover(_ route: AppRoute) {
        coverRoute = route
    }

    func dismissSheet() {
        sheetRoute = nil
    }

    func dismissCover() {
        coverRoute = nil
    }
}

extension AppRoute {
    /// `preferredPresentation` 이 `.sheet` 일 때 사용할 detents.
    /// 기본값은 `.large` 단일.
    var sheetDetents: Set<PresentationDetent> {
        if case .sheet(let detents) = preferredPresentation {
            return detents
        }
        return [.large]
    }
}

// MARK: - Sheet hosting

/// SheetCoordinator 가 띄우는 sheet 의 내부 컨테이너.
///
/// 자체적인 `[AppRoute]` path 를 가진 NavigationStack 을 운영해
/// sheet 내부에서의 navigation 이 탭 stack 깊이를 늘리지 않게 한다.
/// `RouteRouter` 는 sheet 내부 라우트(`.sheet` / `.push`)를 모두
/// 이 path 에 push 한다. `.fullScreenCover` 만 외부 SheetCoordinator 로 위임.
struct SheetHostingView: View {
    let initialRoute: AppRoute
    @State private var path: [AppRoute] = []
    @EnvironmentObject private var sheetCoordinator: SheetCoordinator

    var body: some View {
        NavigationStack(path: $path) {
            DeepLinkDestination(route: initialRoute)
                .appRouteDestinations()
        }
        .presentationDetents(initialRoute.sheetDetents)
        .environment(\.routeRouter, RouteRouter(
            currentDepth: path.count,
            push: { route in path.append(route) },
            presentSheet: { route in path.append(route) },
            presentCover: { route in sheetCoordinator.presentCover(route) }
        ))
    }
}

/// SheetCoordinator 가 띄우는 fullScreenCover 의 내부 컨테이너.
///
/// Maker 워크플로우(editor → uploadPending 9 step)나 기타 워크플로우가
/// 탭 stack 과 분리된 채 자체 path 안에서 자유롭게 push 할 수 있게 한다.
struct CoverHostingView: View {
    let initialRoute: AppRoute
    @State private var path: [AppRoute] = []
    @EnvironmentObject private var sheetCoordinator: SheetCoordinator

    var body: some View {
        NavigationStack(path: $path) {
            DeepLinkDestination(route: initialRoute)
                .appRouteDestinations()
        }
        .environment(\.routeRouter, RouteRouter(
            currentDepth: path.count,
            push: { route in path.append(route) },
            presentSheet: { route in path.append(route) },
            presentCover: { route in sheetCoordinator.presentCover(route) }
        ))
    }
}
