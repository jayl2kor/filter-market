import DesignSystem
import SwiftUI
import UIKit

// MARK: - OnboardingScreen

/// 첫 실행 시 보여주는 진입 화면 (4 페이지 swipe 캐러셀).
///
/// Phase D3 — `mockups/screens/01-onboarding.html` 와 정합 (mockup 의 카드-스택 모티브를
/// 페이지별 일러스트로 확장). 라이트 모드 풀스크린, 상단 60% 일러스트 + 헤드라인 + 서브텍스트
/// + 하단 인디케이터/스킵/넥스트.
///
/// 실제 통합은 `FilterMarketApp` 의 `@AppStorage("hasOnboarded")` 분기와 연결되며,
/// 본 화면은 시각·내비게이션만 제공한다.
struct OnboardingScreen: View {
    @State private var currentPage: Int = 0

    /// 모든 페이지 완료 또는 건너뛰기 시 호출.
    var onComplete: (() -> Void)?

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    private let pages: [OnboardingPage] = OnboardingPage.all

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Sp.md)
                    .padding(.top, Sp.sm)

                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                            .padding(.horizontal, Sp.lg)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.fmEaseOut, value: currentPage)

                pageIndicator
                    .padding(.bottom, Sp.lg)

                bottomActions
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, Sp.xxl)
            }
        }
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            Spacer()
            if !isLastPage {
                Button {
                    finish()
                } label: {
                    Text("건너뛰기")
                        .fmTypography(.callout)
                        .foregroundStyle(FMColors.Text.secondary)
                        .padding(.horizontal, Sp.sm + 2)
                        .padding(.vertical, Sp.xs - 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                        }
                }
                .accessibilityLabel("온보딩 건너뛰기")
            }
        }
        .frame(height: 32)
        .animation(.fmFast, value: isLastPage)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(
                        index == currentPage
                            ? FMColors.Accent.primary
                            : FMColors.Border.default
                    )
                    .frame(width: index == currentPage ? 20 : 6, height: 6)
                    .animation(.fmEaseOut, value: currentPage)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("페이지 \(currentPage + 1) / \(pages.count)")
    }

    private var bottomActions: some View {
        FMButton(
            isLastPage ? "시작하기" : "다음",
            icon: isLastPage ? "sparkles" : "arrow.right",
            variant: .primary,
            size: .lg
        ) {
            advance()
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            FMColors.Background.bg0

            // mockup: radial-gradient(110% 70% at 50% 0%, accent-bg → transparent)
            RadialGradient(
                gradient: Gradient(colors: [
                    FMColors.Accent.bg,
                    Color.clear
                ]),
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 460
            )
            .opacity(0.85)
        }
    }

    // MARK: - Helpers

    private var isLastPage: Bool {
        currentPage >= pages.count - 1
    }

    @MainActor
    private func advance() {
        UISelectionFeedbackGenerator().selectionChanged()
        if isLastPage {
            finish()
        } else {
            withAnimation(.fmSpringSwipe) {
                currentPage += 1
            }
        }
    }

    @MainActor
    private func finish() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onComplete?()
    }
}

// MARK: - OnboardingPage model

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let eyebrow: String
    let symbol: String
    let symbolAccent: String?
    let titlePrimary: String
    let titleAccent: String
    let subtitle: String
    let tint: Color

    static let all: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "filterMarket · 01",
            symbol: "camera.aperture",
            symbolAccent: "sparkles",
            titlePrimary: "카메라에 필터를 입혀",
            titleAccent: "순간을 작품으로",
            subtitle: "라이브 프리뷰로 효과를 미리 확인하고\n그대로 셔터를 눌러보세요.",
            tint: FMColors.Category.cinematic
        ),
        OnboardingPage(
            eyebrow: "filterMarket · 02",
            symbol: "square.grid.3x3.fill",
            symbolAccent: "magnifyingglass",
            titlePrimary: "수천 개의 필터,",
            titleAccent: "취향에 맞게 골라보세요",
            subtitle: "크리에이터가 만든 다양한 필터를\n무료로 받아 바로 적용할 수 있어요.",
            tint: FMColors.Category.travel
        ),
        OnboardingPage(
            eyebrow: "filterMarket · 03",
            symbol: "slider.horizontal.below.square.filled.and.square",
            symbolAccent: "paintpalette.fill",
            titlePrimary: "직접 만든 필터로",
            titleAccent: "나만의 색을 정의",
            subtitle: "LUT 과 파라미터를 조합해\n시그니처 색감을 만들어 공유해보세요.",
            tint: FMColors.Category.pastel
        ),
        OnboardingPage(
            eyebrow: "filterMarket · 04",
            symbol: "sparkles",
            symbolAccent: "star.fill",
            titlePrimary: "준비가 끝났어요",
            titleAccent: "지금 시작해볼까요",
            subtitle: "첫 사진을 찍거나\n마켓을 둘러보며 영감을 얻어보세요.",
            tint: FMColors.Accent.soft
        )
    ]
}

// MARK: - OnboardingPageView

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Sp.lg) {
            illustration
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .padding(.top, Sp.lg)

            VStack(spacing: Sp.sm) {
                Text(page.eyebrow)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Accent.primary)
                    .textCase(.uppercase)

                titleText
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Sp.sm)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.titlePrimary) \(page.titleAccent). \(page.subtitle)")
    }

    /// 카드 스택 모티브 + 큰 SF Symbol + 보조 심볼.
    private var illustration: some View {
        ZStack {
            // 뒤쪽 카드들 (좌·우 기울임)
            illustrationCard(symbol: page.symbol, scale: 0.86, rotation: -8, offset: CGSize(width: -56, height: 14), tintAlpha: 0.55)
            illustrationCard(symbol: page.symbolAccent ?? page.symbol, scale: 0.86, rotation: 8, offset: CGSize(width: 56, height: 14), tintAlpha: 0.55)

            // 메인 카드
            illustrationCard(symbol: page.symbol, scale: 1.0, rotation: 0, offset: .zero, tintAlpha: 1.0)
        }
    }

    private func illustrationCard(
        symbol: String,
        scale: CGFloat,
        rotation: Double,
        offset: CGSize,
        tintAlpha: Double
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: R.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            page.tint.opacity(tintAlpha * 0.5),
                            FMColors.Background.bg2
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: R.lg)
                        .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                }
                .shadow(
                    color: Color.black.opacity(0.10 * tintAlpha),
                    radius: 18,
                    x: 0,
                    y: 8
                )

            Image(systemName: symbol)
                .font(.system(size: 64 * scale, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            FMColors.Accent.primary.opacity(tintAlpha),
                            page.tint.opacity(tintAlpha * 0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: 168 * scale, height: 210 * scale)
        .rotationEffect(.degrees(rotation))
        .offset(offset)
    }

    private var titleText: some View {
        VStack(spacing: 0) {
            Text(page.titlePrimary)
                .foregroundStyle(FMColors.Text.primary)
            Text(page.titleAccent)
                .foregroundStyle(FMColors.Accent.primary)
        }
        .fmTypography(.titleLarge)
    }
}

// MARK: - Preview

#Preview("OnboardingScreen — Light") {
    OnboardingScreen()
}

#Preview("OnboardingScreen — XXXLarge") {
    OnboardingScreen()
        .dynamicTypeSize(.xxxLarge)
}

#Preview("OnboardingScreen — Dark system") {
    // 본 화면은 라이트 강제이지만, 시스템이 다크여도 안전하게 유지되는지 확인.
    OnboardingScreen()
        .preferredColorScheme(.dark)
}
