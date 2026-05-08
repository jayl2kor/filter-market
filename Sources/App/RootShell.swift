import DesignSystem
import SwiftUI

/// 5탭 + 중앙 셔터 셸.
///
/// Phase D2 — `docs/DESIGN_INTEGRATION_PLAN.md` §3.
/// 마켓 / 검색 / 셔터(카메라) / 저장됨 / 프로필 5개 탭.
/// 셔터 탭은 selection 으로 사용되지 않고 `.fullScreenCover` 로 카메라를 띄움.
struct RootShell: View {
    @StateObject private var store = MooditStore()
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false

    @State private var selectedTab: FMTab = .market
    @State private var isCameraPresented = false
    @State private var showHandleOnboarding = false
    /// 신규 사용자 첫 로그인 후 listener가 도착할 시간을 약간 둔 뒤 핸들 검사.
    /// (#32) 너무 일찍 검사하면 .empty 초기값을 보고 잘못 trigger.
    @State private var didCheckHandle = false

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
                Telemetry.log(.deepLinkReceived, parameters: ["route_kind": route.telemetryKind])
                store.pendingDeepLinkRoute = route
            }
        }
        .sheet(isPresented: $showHandleOnboarding) {
            NavigationStack {
                EditProfileScreen()
            }
            .environmentObject(store)
            .interactiveDismissDisabled(false) // 사용자가 나중에 설정할 수 있도록 dismiss 허용 (#32 tradeoff)
        }
        .onReceive(store.$editableProfile) { profile in
            // (#32) 핸들 미설정 + 인증 + listener 첫 도착 후에만 sheet trigger.
            guard isAuthenticated, store.hasLoadedProfile else { return }
            if profile.handle.isEmpty {
                showHandleOnboarding = true
            } else {
                showHandleOnboarding = false
            }
        }
        .onReceive(store.$hasLoadedProfile) { loaded in
            // (#47) hardcoded sleep 제거 — store가 첫 listener snapshot을 받으면 검사 트리거.
            guard loaded, isAuthenticated else { return }
            if store.editableProfile.handle.isEmpty {
                showHandleOnboarding = true
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .market:
            MarketplaceScreen()
        case .search:
            NavigationStack {
                SearchScreen()
                    .appRouteDestinations()
            }
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
