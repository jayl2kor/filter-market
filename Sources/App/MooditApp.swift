import FirebaseAnalytics
import FirebaseAppCheck
import FirebaseCore
import FirebaseCrashlytics
import GoogleSignIn
import SwiftUI
import UIKit

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
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
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

private struct UITestLaunchHost: View {
    @StateObject private var store = MooditStore()
    let route: UITestLaunchRoute

    var body: some View {
        NavigationStack {
            content
                .appRouteDestinations()
        }
        .environmentObject(store)
        .task {
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
            CameraPermissionDenied(onOpenSettings: {}, onDismiss: {})
        case .photosPermissionPriming:
            PhotosPermissionPriming(onAllow: {}, onSkip: {}, onClose: {})
        case .photosPermissionDenied:
            PhotosPermissionDenied(onOpenSettings: {}, onDismiss: {})
        case .notificationsPermissionPriming:
            NotificationsPermissionPriming(onAllow: {}, onSkip: {}, onClose: {})
        case .notificationsPermissionDenied:
            NotificationsPermissionDenied(onOpenSettings: {}, onDismiss: {})
        case .locationPermissionPriming:
            LocationPermissionPriming(onAllow: {}, onSkip: {}, onClose: {})
        case .locationPermissionDenied:
            LocationPermissionDenied(onOpenSettings: {}, onDismiss: {})
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
            ForYouFeedScreen()
        case .followingFeed:
            FollowingFeedScreen()
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
            ReportFormScreen()
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
}
#endif
