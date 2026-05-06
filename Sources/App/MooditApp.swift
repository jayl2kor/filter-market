import FirebaseCore
import SwiftUI
import UIKit

/// Firebase 부트스트랩. 앱 첫 진입에서 한 번만 구성하고, 로컬 plist 누락 시 즉시 크래시하지 않는다.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureFirebaseIfAvailable()
        return true
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
            RootShell()
                .fullScreenCover(isPresented: Binding(
                    get: { !hasOnboarded },
                    set: { newValue in hasOnboarded = !newValue }
                )) {
                    OnboardingScreen {
                        hasOnboarded = true
                    }
                }
        }
    }
}
