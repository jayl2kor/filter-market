import SwiftUI

@main
struct FilterMarketApp: App {
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
