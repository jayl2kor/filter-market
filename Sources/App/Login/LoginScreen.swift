import DesignSystem
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI

// MARK: - LoginScreen

/// 로그인 진입 화면.
///
/// Phase D3 — `mockups/screens/02-login.html` 와 정합.
/// 라이트 모드 풀스크린, 상단 60% 스페이서 + 중앙 로고 + 하단 인증 버튼 그룹.
/// 실제 인증 흐름은 후속 Phase 에서 연결되며, 본 화면은 시각만 제공한다.
struct LoginScreen: View {
    @State private var loadingProvider: LoginProvider? = nil
    @State private var externalURL: ExternalURL?
    @State private var navigateToEmailLogin = false
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: MooditStore

    /// 인증 성공 콜백. 현재는 호출되지 않으나 향후 `AuthState` 변경 트리거로 연결 예정.
    var onAuthenticated: (() -> Void)?
    var onContinueAsGuest: (() -> Void)?
    var onContinueWithEmail: (() -> Void)?

    init(
        onAuthenticated: (() -> Void)? = nil,
        onContinueAsGuest: (() -> Void)? = nil,
        onContinueWithEmail: (() -> Void)? = nil
    ) {
        self.onAuthenticated = onAuthenticated
        self.onContinueAsGuest = onContinueAsGuest
        self.onContinueWithEmail = onContinueWithEmail
    }

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                brandSection

                Spacer(minLength: Sp.xxxl)

                buttonsSection
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, Sp.xxl)
            }
        }
        .accessibilityElement(children: .contain)
        .sheet(item: $externalURL) { external in
            SafariView(url: external.value)
        }
        .environment(\.openURL, OpenURLAction { url in
            externalURL = ExternalURL(value: url)
            return .handled
        })
        .navigationDestination(isPresented: $navigateToEmailLogin) {
            EmailLoginScreen()
        }
    }

    // MARK: - Sections

    private var brandSection: some View {
        VStack(spacing: Sp.md) {
            // Phase Brand: 'Twin Lens' 심볼 + "moodit" 워드마크 세로 락업.
            // SVG 벡터 자산 — Asset Catalog 의 preserves-vector-representation 으로 다이내믹 타입과
            // 모든 해상도에서 선명. 다크 모드 분기는 별도 자산 없이 라이트 워드마크 그대로 노출
            // (요구되면 후속 변형 자산 추가 가능 — 현재는 라이트 컨텍스트 기준).
            Image("MooditLockupVertical")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 160)
                .accessibilityHidden(true)

            Text("모두의 필터, 단 하나의 마켓.\n촬영하고, 만들고, 거래하세요.")
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.top, Sp.xxxxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("moodit. 모두의 필터, 단 하나의 마켓. 촬영하고, 만들고, 거래하세요.")
    }

    private var buttonsSection: some View {
        VStack(spacing: Sp.sm) {
            appleButton
            googleButton
            emailButton

            divider

            guestLink
                .padding(.top, Sp.xxs)

            termsText
                .padding(.top, Sp.xs)
        }
    }

    // MARK: - Buttons

    private var appleButton: some View {
        Button(action: { triggerLogin(.apple) }) {
            HStack(spacing: Sp.xs) {
                if loadingProvider == .apple {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.85)
                        .tint(.white)
                } else {
                    Image(systemName: "applelogo")
                        .font(.system(size: 18, weight: .medium))
                }
                Text("Apple로 계속하기")
                    .fmTypography(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(colorScheme == .dark ? FMColors.Text.primary : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? .white : .black)
            )
        }
        .disabled(loadingProvider != nil)
        .accessibilityLabel("Apple로 계속하기")
        .accessibilityIdentifier("auth.apple")
        .accessibilityAddTraits(.isButton)
    }

    private var googleButton: some View {
        Button(action: { triggerLogin(.google) }) {
            HStack(spacing: Sp.xs) {
                if loadingProvider == .google {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.85)
                        .tint(FMColors.Text.primary)
                } else {
                    googleIconMark
                }
                Text("Google 계정으로 계속")
                    .fmTypography(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(FMColors.Text.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(FMColors.Background.bg2)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(FMColors.Border.default, lineWidth: 1)
            }
        }
        .disabled(loadingProvider != nil)
        .accessibilityLabel("Google로 계속하기")
        .accessibilityIdentifier("auth.google")
        .accessibilityAddTraits(.isButton)
    }

    /// Google 4색 마크 placeholder — 라이선스 이슈로 정확한 G 마크 대신 4색 도트 그리드.
    private var googleIconMark: some View {
        ZStack {
            // Google official assets 가 추가되기 전 시각 placeholder.
            Image(systemName: "g.circle.fill")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 66/255, green: 133/255, blue: 244/255),
                            Color(red: 234/255, green: 67/255, blue: 53/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: 18, height: 18)
    }

    private var emailButton: some View {
        Button {
            onContinueWithEmail?()
            navigateToEmailLogin = true
        } label: {
            Label("이메일로 계속", systemImage: "envelope")
                .fmTypography(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(FMColors.Text.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(FMColors.Background.bg0, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(FMColors.Border.default, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(loadingProvider != nil)
        .accessibilityLabel("이메일로 계속")
        .accessibilityIdentifier("auth.email.continue")
    }

    private var divider: some View {
        HStack(spacing: Sp.md) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
            Text("또는")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.tertiary)
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
        .padding(.vertical, Sp.xs)
    }

    private var guestLink: some View {
        Button {
            onContinueAsGuest?()
        } label: {
            Text("로그인 없이 둘러보기 →")
                .fmTypography(.callout)
                .foregroundStyle(FMColors.Accent.primary)
        }
        .accessibilityLabel("로그인 없이 둘러보기")
        .accessibilityIdentifier("auth.guest.continue")
    }

    private var termsText: some View {
        Text(termsAttributed)
            .fmTypography(.footnote)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("auth.terms")
    }

    /// AttributedString with `.link` attributes — taps are intercepted by the
    /// `openURL` environment override on `body` and presented via `SafariView`.
    private var termsAttributed: AttributedString {
        let tertiary = FMColors.Text.tertiary
        let highlight = FMColors.Text.secondary

        var prefix = AttributedString("계속을 누르면 ")
        prefix.foregroundColor = tertiary

        var terms = AttributedString("이용약관")
        terms.foregroundColor = highlight
        terms.underlineStyle = .single
        terms.link = MooditPolicyURL.terms

        var middle = AttributedString(" 과 ")
        middle.foregroundColor = tertiary

        var privacy = AttributedString("개인정보처리방침")
        privacy.foregroundColor = highlight
        privacy.underlineStyle = .single
        privacy.link = MooditPolicyURL.privacy

        var suffix = AttributedString(" 에 동의하는 것으로 간주됩니다.")
        suffix.foregroundColor = tertiary

        return prefix + terms + middle + privacy + suffix
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            FMColors.Background.bg0

            // mockup: radial-gradient(80% 60% at 50% 20%, accent-bg → transparent)
            RadialGradient(
                gradient: Gradient(colors: [
                    FMColors.Accent.bg,
                    Color.clear
                ]),
                center: UnitPoint(x: 0.5, y: 0.2),
                startRadius: 0,
                endRadius: 380
            )
            .opacity(colorScheme == .dark ? 0.6 : 1.0)
        }
    }

    // MARK: - Helpers

    private enum LoginProvider: Equatable {
        case apple
        case google
    }

    @MainActor
    private func triggerLogin(_ provider: LoginProvider) {
        guard loadingProvider == nil else { return }
        loadingProvider = provider

        switch provider {
        case .apple:
            // Apple Sign-In은 별도 SDK 흐름이 차후 추가 — 현재는 시뮬레이션.
            simulateAuth(provider: provider)
        case .google:
            performGoogleSignIn()
        }
    }

    /// Loading 상태만 잠시 표시한 뒤 onAuthenticated 호출 — Apple Sign-In 미연결 시 폴백.
    @MainActor
    private func simulateAuth(provider: LoginProvider) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            completeAuthentication()
        }
    }

    /// Google Sign-In 흐름:
    /// 1. `GIDSignIn` 시트 표시 → ID token + access token 획득
    /// 2. Firebase `GoogleAuthProvider` 자격증명 생성
    /// 3. `Auth.auth().signIn(with:)` 으로 Firebase 세션 시작
    /// 4. Firebase Auth listener updates MooditStore auth state + onAuthenticated 콜백
    @MainActor
    private func performGoogleSignIn() {
        guard let presenter = topViewController() else {
            loadingProvider = nil
            return
        }
        guard FirebaseApp.app() != nil else {
            // Firebase 미설정 — GoogleService-Info.plist 누락. 시뮬레이션으로 폴백.
            #if DEBUG
            print("[Login] Firebase not configured; falling back to simulated auth.")
            #endif
            simulateAuth(provider: .google)
            return
        }

        Task { @MainActor in
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
                guard let idToken = result.user.idToken?.tokenString else {
                    throw NSError(
                        domain: "moodit.LoginScreen",
                        code: -10,
                        userInfo: [NSLocalizedDescriptionKey: "Google ID token missing"]
                    )
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                _ = try await Auth.auth().signIn(with: credential)
                completeAuthentication()
            } catch {
                loadingProvider = nil
                #if DEBUG
                print("[Login] Google sign-in failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    @MainActor
    private func completeAuthentication() {
        if Auth.auth().currentUser == nil {
            store.setLocalAuthenticationFallback(true)
        }
        loadingProvider = nil
        FMHaptic.success.play()
        onAuthenticated?()
    }

    /// 현재 키 윈도우의 root view controller — `GIDSignIn`은 presenting controller가 필요.
    private func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

// MARK: - Preview

#Preview("LoginScreen — Light") {
    LoginScreen()
}

#Preview("LoginScreen — Dark") {
    LoginScreen()
        .preferredColorScheme(.dark)
}

#Preview("LoginScreen — XXXLarge") {
    LoginScreen()
        .dynamicTypeSize(.xxxLarge)
}
