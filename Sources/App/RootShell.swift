import DesignSystem
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import SwiftUI

/// 5탭 + 중앙 셔터 셸.
///
/// Phase D2 — `docs/DESIGN_INTEGRATION_PLAN.md` §3.
/// 마켓 / 검색 / 셔터(카메라) / 저장됨 / 프로필 5개 탭.
/// 셔터 탭은 selection 으로 사용되지 않고 `.fullScreenCover` 로 카메라를 띄움.
struct RootShell: View {
    @StateObject private var store = MooditStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    @State private var selectedTab: FMTab = .market
    @State private var isCameraPresented = false
    @State private var showHandleOnboarding = false
    @State private var deferredDeepLinkRoute: AppRoute?
    @State private var notificationBadgeListener: ListenerRegistration?
    @State private var unreadNotificationCount = 0
    @State private var didPrimeNotificationBadge = false
    /// 신규 사용자 첫 로그인 후 listener가 도착할 시간을 약간 둔 뒤 핸들 검사.
    /// (#32) 너무 일찍 검사하면 .empty 초기값을 보고 잘못 trigger.
    @State private var didCheckHandle = false
    @State private var checkedHandleOnboardingUID: String?

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
                badges: tabBadges,
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
            store.subscribeToWallet()
            syncNotificationBadgeListener()
            PushRegistration.shared.deepLinkHandler = { route in
                Task { @MainActor in
                    handleIncomingDeepLink(route)
                }
            }
            #if DEBUG
            // UI test launch arg: `-deepLink <url>` simulates the URL arriving
            // through `.onOpenURL` so PhaseAE2ETests can exercise the deep-link
            // path without Springboard/Safari indirection.
            if let url = uiTestingDeepLinkURL(),
               let route = UniversalLinkParser.route(for: url) {
                handleIncomingDeepLink(route)
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
                handleIncomingDeepLink(route)
            }
        }
        .sheet(isPresented: $showHandleOnboarding, onDismiss: markHandleOnboardingDismissed) {
            NavigationStack {
                EditProfileScreen()
            }
            .environmentObject(store)
            .interactiveDismissDisabled(false) // 사용자가 나중에 설정할 수 있도록 dismiss 허용 (#32 tradeoff)
        }
        .onReceive(store.$editableProfile) { profile in
            // (#32) 핸들 미설정 + 인증 + listener 첫 도착 후에만 sheet trigger.
            syncHandleOnboarding(profile: profile)
        }
        .onReceive(store.$hasLoadedProfile) { loaded in
            // (#47) hardcoded sleep 제거 — store가 첫 listener snapshot을 받으면 검사 트리거.
            guard loaded, store.isAuthenticated else { return }
            syncHandleOnboarding(profile: store.editableProfile)
        }
        .onChange(of: store.isAuthenticated) { _, authenticated in
            if authenticated {
                syncNotificationBadgeListener()
                syncHandleOnboarding(profile: store.editableProfile)
                flushDeferredDeepLinkIfReady()
            } else {
                detachNotificationBadgeListener()
                resetHandleOnboardingGate()
            }
        }
        .onChange(of: hasOnboarded) { _, _ in
            flushDeferredDeepLinkIfReady()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Telemetry.log(.appResumed)
            Task {
                await store.refreshOnForeground()
                syncNotificationBadgeListener()
                syncHandleOnboarding(profile: store.editableProfile)
                flushDeferredDeepLinkIfReady()
            }
        }
        .onDisappear {
            detachNotificationBadgeListener()
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

    private var handleOnboardingUID: String {
        Auth.auth().currentUser?.uid ?? "__authenticated__"
    }

    private var tabBadges: [FMTab: FMTabBadge] {
        var result: [FMTab: FMTabBadge] = [:]
        if unreadNotificationCount > 0 {
            result[.profile] = .number(unreadNotificationCount, label: "미확인 알림")
        } else if store.uploadStep == .pending {
            result[.profile] = .dot(label: "업로드 검수 대기")
        }
        return result
    }

    private func handleIncomingDeepLink(_ route: AppRoute) {
        Telemetry.log(.deepLinkReceived, parameters: ["route_kind": route.telemetryKind])
        guard canPresentDeepLink(route) else {
            deferredDeepLinkRoute = route
            Telemetry.log(.deepLinkDeferred, parameters: [
                "route_kind": route.telemetryKind,
                "has_onboarded": hasOnboarded,
                "is_authenticated": store.isAuthenticated
            ])
            return
        }
        store.pendingDeepLinkRoute = route
    }

    private func flushDeferredDeepLinkIfReady() {
        guard let route = deferredDeepLinkRoute, canPresentDeepLink(route) else { return }
        deferredDeepLinkRoute = nil
        Telemetry.log(.deepLinkFlushed, parameters: ["route_kind": route.telemetryKind])
        store.pendingDeepLinkRoute = route
    }

    private func canPresentDeepLink(_ route: AppRoute) -> Bool {
        guard hasOnboarded else { return false }
        guard !route.requiresAuthentication || store.isAuthenticated else { return false }
        return true
    }

    private func syncHandleOnboarding(profile: EditableProfile) {
        guard store.isAuthenticated, store.hasLoadedProfile else { return }

        let uid = handleOnboardingUID
        if let checkedHandleOnboardingUID, checkedHandleOnboardingUID != uid {
            resetHandleOnboardingGate()
        }

        let hasHandle = !profile.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasHandle {
            checkedHandleOnboardingUID = uid
            didCheckHandle = true
            showHandleOnboarding = false
            return
        }

        guard checkedHandleOnboardingUID != uid,
              !didCheckHandle,
              !showHandleOnboarding else { return }

        checkedHandleOnboardingUID = uid
        didCheckHandle = true
        showHandleOnboarding = true
    }

    private func markHandleOnboardingDismissed() {
        guard store.isAuthenticated else { return }
        checkedHandleOnboardingUID = handleOnboardingUID
        didCheckHandle = true
    }

    private func resetHandleOnboardingGate() {
        showHandleOnboarding = false
        didCheckHandle = false
        checkedHandleOnboardingUID = nil
    }

    private func syncNotificationBadgeListener() {
        guard store.isAuthenticated,
              FirebaseApp.app() != nil,
              let uid = Auth.auth().currentUser?.uid else {
            detachNotificationBadgeListener()
            return
        }

        notificationBadgeListener?.remove()
        notificationBadgeListener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, _ in
                let count = snapshot?.documents.filter { doc in
                    let data = doc.data()
                    return data["readAt"] == nil || data["readAt"] is NSNull
                }.count ?? 0

                Task { @MainActor in
                    let previous = unreadNotificationCount
                    unreadNotificationCount = count
                    if didPrimeNotificationBadge, previous == 0, count > 0 {
                        FMHaptic.light.play()
                    }
                    didPrimeNotificationBadge = true
                }
            }
    }

    private func detachNotificationBadgeListener() {
        notificationBadgeListener?.remove()
        notificationBadgeListener = nil
        unreadNotificationCount = 0
        didPrimeNotificationBadge = false
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
