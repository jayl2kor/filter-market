import FirebaseCore
import SwiftUI
import UIKit

/// Firebase 부트스트랩 — `FirebaseApp.configure()`는 SDK 가이드대로 앱 첫 진입에서 한 번만 호출.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
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
