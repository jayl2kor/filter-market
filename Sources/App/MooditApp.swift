import FirebaseCore
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
        PushRegistration.shared.bootstrap(application: application)
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

        FirebaseApp.configure(options: options)
    }
}

@main
struct MooditApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// 첫 실행 여부. `OnboardingScreen` 종료 시 true 로 갱신.
    /// Phase D5 권한 흐름 통합 시 권한 priming 흐름과 함께 재정비될 수 있다.
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

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
    case camera
    case cameraAspect
    case cameraTimer
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
        case .camera:
            CameraScreen(isPresentedAsCover: false)
        case .cameraAspect:
            CameraAspectPickerScreen()
        case .cameraTimer:
            CameraTimerCountdownScreen()
        case .photoImport:
            PhotoImportScreen()
        case .photoEdit:
            PhotoEditScreen()
        case .builtinFilters:
            BuiltinFilterLibraryScreen()
        case .filterDownload:
            FilterDownloadProgressScreen(filterID: "Sunset 1973")
        case .filterAfterDownload:
            FilterAfterDownloadScreen(filterID: "Sunset 1973")
        case .reviews:
            ReviewsListScreen(filterID: "Sunset 1973")
        case .reviewCompose:
            ReviewComposeScreen(filterID: "Sunset 1973")
        case .rating:
            RatingFormScreen(filterID: "Sunset 1973")
        case .followers:
            FollowersListScreen(userID: "me")
        case .following:
            FollowingListScreen(userID: "me")
        case .forYou:
            ForYouFeedScreen()
        case .followingFeed:
            FollowingFeedScreen()
        }
    }
}
#endif
