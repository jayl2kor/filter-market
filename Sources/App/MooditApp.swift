import FirebaseAnalytics
import FirebaseAppCheck
import FirebaseCore
import FirebaseCrashlytics
import GoogleSignIn
import OSLog
import SwiftUI
import UIKit

/// Surfaces App Check provider lifecycle in both Debug and Release builds.
/// Filter in Console.app: subsystem:com.jayl2kor.moodit.app category:AppCheck
private let appCheckLog = Logger(subsystem: "com.jayl2kor.moodit.app", category: "AppCheck")

/// Firebase 부트스트랩. 앱 첫 진입에서 한 번만 구성하고, 로컬 plist 누락 시 즉시 크래시하지 않는다.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureFirebaseIfAvailable()
        #if DEBUG
        if !isUITesting {
            PushRegistration.shared.bootstrap(application: application)
        }
        #else
        PushRegistration.shared.bootstrap(application: application)
        #endif
        return true
    }

    /// APNs hands the device token here; forward it to FirebaseMessaging via PushRegistration.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushRegistration.shared.handleAPNsToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[Push] APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    /// OAuth callback handler. Google Sign-In gets first crack at the URL;
    /// if it doesn't recognize the URL, returns `false` and SwiftUI's
    /// `.onOpenURL` modifier downstream will route as a universal link.
    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        return false
    }

    private func configureFirebaseIfAvailable() {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard FirebaseApp.app() == nil else { return }
        guard
            let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let options = FirebaseOptions(contentsOfFile: path)
        else {
            #if DEBUG
            print("Missing GoogleService-Info.plist. Firebase-backed features are disabled.")
            #endif
            return
        }

        configureAppCheckForCurrentProcess()
        FirebaseApp.configure(options: options)
        configureTelemetryForCurrentProcess()
    }

    private func configureAppCheckForCurrentProcess() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MOODIT_USE_APP_CHECK_DEBUG_PROVIDER"] == "1" {
            appCheckLog.notice("Using debug provider (forced via MOODIT_USE_APP_CHECK_DEBUG_PROVIDER)")
            AppCheck.setAppCheckProviderFactory(MooditDebugAppCheckProviderFactory())
        } else {
            #if targetEnvironment(simulator)
            appCheckLog.notice("Using debug provider (Debug + simulator)")
            AppCheck.setAppCheckProviderFactory(MooditDebugAppCheckProviderFactory())
            #else
            appCheckLog.notice("Using AppAttest/DeviceCheck provider (Debug + device)")
            AppCheck.setAppCheckProviderFactory(MooditAppCheckProviderFactory())
            #endif
        }
        #else
        appCheckLog.notice("Using AppAttest/DeviceCheck provider (Release)")
        AppCheck.setAppCheckProviderFactory(MooditAppCheckProviderFactory())
        #endif
    }

    private func configureTelemetryForCurrentProcess() {
        #if DEBUG
        if isUITesting {
            Analytics.setAnalyticsCollectionEnabled(false)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        }
        #endif
    }
}

#if DEBUG
final class MooditDebugAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        guard let provider = AppCheckDebugProvider(app: app) else { return nil }
        print("[Moodit/AppCheck] Firebase App Check debug token: \(provider.localDebugToken())")
        return provider
    }
}
#endif

final class MooditAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *), let provider = AppAttestProvider(app: app) {
            appCheckLog.notice("AppAttestProvider initialized")
            return provider
        }
        appCheckLog.error("AppAttestProvider unavailable — falling back to DeviceCheck. Likely cause: simulator, missing com.apple.developer.devicecheck.appattest-environment entitlement, or mismatched signing/entitlement environment.")
        return DeviceCheckProvider(app: app)
    }
}

@main
struct MooditApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// 첫 실행 여부. `OnboardingScreen` 종료 시 true 로 갱신.
    /// Phase D5 권한 흐름 통합 시 권한 priming 흐름과 함께 재정비될 수 있다.
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    init() {
        #if DEBUG
        UITestingLaunchOverrides.applyIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let route = UITestLaunchRoute.current {
                UITestLaunchHost(route: route)
            } else if let route = UITestDeepLinkLaunchRoute.current {
                UITestDeepLinkLaunchHost(route: route)
            } else {
                rootContent
            }
            #else
            rootContent
            #endif
        }
    }

    private var rootContent: some View {
        RootShell()
            .fullScreenCover(isPresented: Binding(
                get: { !hasOnboarded && !ProcessInfo.processInfo.arguments.contains("-ui-testing") },
                set: { newValue in hasOnboarded = !newValue }
            )) {
                OnboardingScreen {
                    hasOnboarded = true
                }
            }
    }
}

#if DEBUG
private enum UITestDeepLinkLaunchRoute {
    static var current: AppRoute? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ui-testing"),
              let deepLinkFlagIndex = arguments.firstIndex(of: "-deepLink"),
              arguments.indices.contains(deepLinkFlagIndex + 1),
              let url = URL(string: arguments[deepLinkFlagIndex + 1])
        else {
            return nil
        }
        return UniversalLinkParser.route(for: url)
    }
}

private enum UITestLaunchRoute: String {
    case login
    case emailLogin
    case search
    case filterDetail
    case profile
    case otherProfile
    case settings
    case editProfile
    case savedFilters
    case wallet
    case walletTopup
    case walletTransactions
    case insufficientBalance
    case paymentFailed
    case refundRequest
    case ordersHistory
    case proSubscription
    case proStatus
    case dataExport
    case helpCenter
    case camera
    case capturePreview
    case cameraAspect
    case cameraTimer
    case cameraPermissionPriming
    case cameraPermissionDenied
    case photosPermissionPriming
    case photosPermissionDenied
    case notificationsPermissionPriming
    case notificationsPermissionDenied
    case locationPermissionPriming
    case locationPermissionDenied
    case photoImport
    case photoEdit
    case builtinFilters
    case filterDownload
    case filterAfterDownload
    case reviews
    case reviewCompose
    case rating
    case followers
    case following
    case forYou
    case followingFeed
    case notifications
    case notificationSettings
    case editor
    case editorParameters
    case editorLUT
    case editorDraft
    case uploadCover
    case uploadTags
    case uploadSubmit
    case uploadPending
    case accountDeletion
    case universalLinkLanding
    case makerDashboard
    case reportForm
    case favoritesCollection
    case modQueue
    case modDetail
    case blockList
    case remixFlow
    case paywallSingle
    case payoutOnboarding
    case payoutTaxInfo
    case payoutHistory
    case earningsWithdraw
    case filterRejected
    case myFilters

    static var current: UITestLaunchRoute? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ui-testing"),
              let routeFlagIndex = arguments.firstIndex(of: "-ui-route"),
              arguments.indices.contains(routeFlagIndex + 1)
        else {
            return nil
        }
        return UITestLaunchRoute(rawValue: arguments[routeFlagIndex + 1])
    }
}

private struct UITestDeepLinkLaunchHost: View {
    @StateObject private var store = MooditStore()
    let route: AppRoute

    var body: some View {
        NavigationStack {
            DeepLinkDestination(route: route)
                .appRouteDestinations()
        }
        .environmentObject(store)
        .environmentObject(store.filterLibraryStore)
        .environmentObject(store.walletStore)
        .environmentObject(store.editorDraftStore)
        .environmentObject(store.sessionStore)
        .environmentObject(store.cameraStateStore)
        .task {
            store.subscribeToWallet()
            await store.load()
        }
    }
}

private struct UITestLaunchHost: View {
    @StateObject private var store = MooditStore()
    let route: UITestLaunchRoute

    var body: some View {
        NavigationStack {
            content
                .appRouteDestinations()
        }
        .environment(\.dynamicTypeSize, launchDynamicTypeSize)
        .environmentObject(store)
        .environmentObject(store.filterLibraryStore)
        .environmentObject(store.walletStore)
        .environmentObject(store.editorDraftStore)
        .environmentObject(store.sessionStore)
        .environmentObject(store.cameraStateStore)
        .task {
            store.subscribeToWallet()
            seedUITestFixturesIfNeeded()
            await store.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .login:
            LoginScreen()
        case .emailLogin:
            EmailLoginScreen()
        case .search:
            SearchScreen(initialQuery: nil, initialCategory: nil)
        case .filterDetail:
            FilterDetailScreen(mock: FilterDetailMock.mock(forRouteID: "sample-filter"))
        case .profile:
            ProfileScreen()
        case .otherProfile:
            ProfileScreen(otherUid: "review-author")
        case .settings:
            SettingsScreen()
        case .editProfile:
            EditProfileScreen()
        case .savedFilters:
            SavedScreen()
        case .wallet:
            WalletScreen()
        case .walletTopup:
            WalletTopupScreen()
        case .walletTransactions:
            WalletTransactionsScreen()
        case .insufficientBalance:
            InsufficientBalanceScreen(filterID: "sample-filter")
        case .paymentFailed:
            PaymentFailedScreen()
        case .refundRequest:
            RefundRequestScreen()
        case .ordersHistory:
            OrdersHistoryScreen()
        case .proSubscription:
            ProSubscriptionScreen()
        case .proStatus:
            ProStatusScreen()
        case .dataExport:
            DataExportScreen()
        case .helpCenter:
            HelpCenterScreen()
        case .camera:
            CameraScreen(isPresentedAsCover: false)
        case .capturePreview:
            CapturePreviewScreen(
                filterName: "테스트 필터",
                aspectRatio: "4:3",
                intensityPercent: 72
            )
        case .cameraAspect:
            CameraAspectPickerScreen()
        case .cameraTimer:
            CameraTimerCountdownScreen()
        case .cameraPermissionPriming:
            CameraPermissionPriming(onAllow: {}, onSkip: {}, onClose: {})
        case .cameraPermissionDenied:
            CameraPermissionDenied(onOpenSettings: openAppSettings, onDismiss: {})
        case .photosPermissionPriming:
            PhotosPermissionPriming(onAllow: {}, onSkip: {}, onClose: {})
        case .photosPermissionDenied:
            PhotosPermissionDenied(onOpenSettings: openAppSettings, onDismiss: {})
        case .notificationsPermissionPriming:
            NotificationsPermissionPriming(onAllow: {}, onSkip: {}, onClose: {})
        case .notificationsPermissionDenied:
            NotificationsPermissionDenied(onOpenSettings: openAppSettings, onDismiss: {})
        case .locationPermissionPriming:
            LocationPermissionPriming(onAllow: {}, onSkip: {}, onClose: {})
        case .locationPermissionDenied:
            LocationPermissionDenied(onOpenSettings: openAppSettings, onDismiss: {})
        case .photoImport:
            PhotoImportScreen()
        case .photoEdit:
            PhotoEditScreen()
        case .builtinFilters:
            BuiltinFilterLibraryScreen()
        case .filterDownload:
            FilterDownloadProgressScreen(filterID: "sample-filter")
        case .filterAfterDownload:
            FilterAfterDownloadScreen(filterID: "sample-filter")
        case .reviews:
            ReviewsListScreen(filterID: "sample-filter")
        case .reviewCompose:
            ReviewComposeScreen(filterID: "sample-filter")
        case .rating:
            RatingFormScreen(filterID: "sample-filter")
        case .followers:
            FollowersListScreen(userID: "me")
        case .following:
            FollowingListScreen(userID: "me")
        case .forYou:
            DiscoveryScreen(initialTab: .forYou)
        case .followingFeed:
            DiscoveryScreen(initialTab: .following)
        case .notifications:
            NotificationsInboxScreen()
        case .notificationSettings:
            NotificationSettingsScreen()
        case .editor:
            FilterEditorScreen()
        case .editorParameters:
            EditorParametersScreen()
        case .editorLUT:
            EditorLUTImportScreen()
        case .editorDraft:
            EditorDraftSaveScreen()
        case .uploadCover:
            UploadCoverScreen()
        case .uploadTags:
            UploadTagsCategoryScreen()
        case .uploadSubmit:
            UploadTOSSubmitScreen()
        case .uploadPending:
            UploadPendingReviewScreen()
        case .accountDeletion:
            AccountDeletionScreen()
        case .universalLinkLanding:
            UniversalLinkLandingScreen()
        case .makerDashboard:
            MakerDashboardScreen()
        case .reportForm:
            ReportFormScreen(target: .filter(id: "ui-test-filter"))
        case .favoritesCollection:
            FavoritesCollectionScreen()
        case .modQueue:
            ModerationQueueScreen()
        case .modDetail:
            ModerationDetailScreen(itemID: "pending-filter")
        case .blockList:
            BlockListScreen()
        case .remixFlow:
            RemixFlowScreen()
        case .paywallSingle:
            PaywallSingleScreen(filterID: "sample-filter")
        case .payoutOnboarding:
            PayoutOnboardingScreen()
        case .payoutTaxInfo:
            PayoutTaxInfoScreen()
        case .payoutHistory:
            PayoutHistoryScreen()
        case .earningsWithdraw:
            EarningsWithdrawScreen()
        case .filterRejected:
            FilterRejectedScreen(filterID: "sample-filter")
        case .myFilters:
            MyFiltersScreen()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func seedUITestFixturesIfNeeded() {
        guard route == .filterRejected else { return }
        var draft = MakerFilterDraft.empty
        draft.id = UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E3D48")!
        draft.name = "검수 반려 샘플"
        draft.summary = "UI 테스트용 반려 초안"
        draft.status = .rejected
        draft.firestoreFilterId = "sample-filter"
        draft.tags = ["portrait", "warm"]
        draft.category = .portrait
        draft.rejectionReasons = [
            RejectionReason(title: "커버 이미지 보완 필요", body: "필터 적용 전후를 명확히 비교할 수 있는 커버를 추가해 주세요."),
            RejectionReason(title: "태그 정리 필요", body: "검색 품질을 위해 중복 태그를 제거해 주세요.")
        ]
        draft.moderatorNote = "수정 후 다시 제출하면 우선 검토하겠습니다."
        draft.rejectedAt = Date(timeIntervalSince1970: 1_700_000_000)
        store.editorDraftStore.setMakerFilters([draft])
    }

    private var launchDynamicTypeSize: DynamicTypeSize {
        guard let rawValue = launchArgumentValue("-ui-dynamic-type") else { return .large }
        switch rawValue {
        case "xLarge": return .xLarge
        case "xxLarge": return .xxLarge
        case "xxxLarge": return .xxxLarge
        case "accessibility1": return .accessibility1
        case "accessibility2": return .accessibility2
        case "accessibility3": return .accessibility3
        case "accessibility4": return .accessibility4
        case "accessibility5": return .accessibility5
        default: return .large
        }
    }

    private func launchArgumentValue(_ flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif
