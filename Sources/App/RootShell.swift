import DesignSystem
import SwiftUI

/// 5탭 + 중앙 셔터 셸.
///
/// Phase D2 — `docs/DESIGN_INTEGRATION_PLAN.md` §3.
/// 마켓 / 검색 / 셔터(카메라) / 저장됨 / 프로필 5개 탭.
/// 셔터 탭은 selection 으로 사용되지 않고 `.fullScreenCover` 로 카메라를 띄움.
struct RootShell: View {
    @StateObject private var store = MooditStore()

    @State private var selectedTab: FMTab = .market
    @State private var isCameraPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FMColors.Background.bg1)

            FMTabBar(
                selection: Binding(
                    get: { selectedTab },
                    set: { newValue in
                        // 셔터는 selection 으로 들어오지 않지만 방어적으로 처리.
                        guard newValue != .shutter else { return }
                        selectedTab = newValue
                    }
                ),
                onShutter: {
                    FMHaptic.medium.play()
                    isCameraPresented = true
                }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(FMColors.Background.bg1)
        .environmentObject(store)
        .task {
            await store.load()
            PushRegistration.shared.deepLinkHandler = { [weak store] route in
                store?.pendingDeepLinkRoute = route
            }
            #if DEBUG
            // UI test launch arg: `-deepLink <url>` simulates the URL arriving
            // through `.onOpenURL` so PhaseAE2ETests can exercise the deep-link
            // path without Springboard/Safari indirection.
            if let url = uiTestingDeepLinkURL(),
               let route = UniversalLinkParser.route(for: url) {
                store.pendingDeepLinkRoute = route
            }
            #endif
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraScreen(isPresentedAsCover: true)
                .environmentObject(store)
        }
        .sheet(item: $store.pendingDeepLinkRoute) { route in
            NavigationStack {
                DeepLinkDestination(route: route)
                    .appRouteDestinations()
            }
            .environmentObject(store)
        }
        .onOpenURL { url in
            if let route = UniversalLinkParser.route(for: url) {
                store.pendingDeepLinkRoute = route
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .market:
            MarketplaceScreen()
        case .search:
            SearchScreen()
        case .shutter:
            // 도달하지 않음 — fullScreenCover 로 처리.
            MarketplaceScreen()
        case .saved:
            SavedScreen()
        case .profile:
            ProfileScreen()
        }
    }

    #if DEBUG
    /// Reads the `-deepLink <url>` launch argument from `ProcessInfo`.
    /// Returns nil if the flag is missing, malformed, or the value is empty.
    private func uiTestingDeepLinkURL() -> URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let flagIndex = args.firstIndex(of: "-deepLink"),
              args.indices.contains(flagIndex + 1) else { return nil }
        return URL(string: args[flagIndex + 1])
    }
    #endif
}
