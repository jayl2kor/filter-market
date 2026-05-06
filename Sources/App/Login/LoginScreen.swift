import DesignSystem
import SwiftUI

// MARK: - LoginScreen

/// 로그인 진입 화면.
///
/// Phase D3 — `mockups/screens/02-login.html` 와 정합.
/// 라이트 모드 풀스크린, 상단 60% 스페이서 + 중앙 로고 + 하단 인증 버튼 그룹.
/// 실제 인증 흐름은 후속 Phase 에서 연결되며, 본 화면은 시각만 제공한다.
struct LoginScreen: View {
    @State private var loadingProvider: LoginProvider? = nil
    @Environment(\.colorScheme) private var colorScheme

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
    }

    // MARK: - Sections

    private var brandSection: some View {
        VStack(spacing: Sp.md) {
            logo
                .accessibilityHidden(true)

            Text("filterMarket")
                .fmTypography(.display)
                .foregroundStyle(FMColors.Text.primary)
                .multilineTextAlignment(.center)

            Text("모두의 필터, 단 하나의 마켓.\n촬영하고, 만들고, 거래하세요.")
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.top, Sp.xxxxl)
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: R.lg)
                .fill(FMColors.Background.bg2)
                .overlay {
                    RoundedRectangle(cornerRadius: R.lg)
                        .strokeBorder(FMColors.Border.default, lineWidth: 1)
                }
                .shadow(
                    color: FMColors.Accent.primary.opacity(0.12),
                    radius: 24,
                    x: 0,
                    y: 8
                )

            Image(systemName: "camera.aperture")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(FMColors.Accent.primary)
        }
        .frame(width: 64, height: 64)
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
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: R.md)
                    .fill(FMColors.Text.primary)
            )
        }
        .disabled(loadingProvider != nil)
        .accessibilityLabel("Apple로 계속하기")
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
                Text("Google로 계속하기")
                    .fmTypography(.headline)
            }
            .foregroundStyle(FMColors.Text.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: R.md)
                    .fill(FMColors.Background.bg2)
            )
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(FMColors.Border.default, lineWidth: 1)
            }
        }
        .disabled(loadingProvider != nil)
        .accessibilityLabel("Google로 계속하기")
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
        FMButton(
            "이메일로 계속",
            icon: "envelope",
            variant: .secondary,
            size: .lg
        ) {
            onContinueWithEmail?()
        }
        .disabled(loadingProvider != nil)
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
    }

    private var termsText: some View {
        // 외부 링크는 후속 Phase 에서 SafariViewController 로 연결.
        let highlight = FMColors.Text.secondary
        return (
            Text("계속을 누르면 ")
                .foregroundStyle(FMColors.Text.tertiary)
            + Text("이용약관")
                .foregroundStyle(highlight)
                .underline()
            + Text(" 과 ")
                .foregroundStyle(FMColors.Text.tertiary)
            + Text("개인정보처리방침")
                .foregroundStyle(highlight)
                .underline()
            + Text(" 에 동의하는 것으로 간주됩니다.")
                .foregroundStyle(FMColors.Text.tertiary)
        )
        .fmTypography(.footnote)
        .multilineTextAlignment(.center)
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
        // 실제 인증 흐름은 후속 Phase. 시각적 로딩 상태만 약 1.2초 시뮬레이션.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            loadingProvider = nil
            onAuthenticated?()
        }
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
