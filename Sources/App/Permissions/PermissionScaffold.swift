import DesignSystem
import SwiftUI
import UIKit

// MARK: - PermissionScaffold
//
// Phase D5 — `mockups/screens/permissions/_shared.css` 와 정합.
// priming / denied 화면이 공유하는 풀스크린 라이트 모드 레이아웃.
//
// 구조:
//   1. 상단 닫기 버튼 (선택)
//   2. 일러스트 (96pt 원형 — 골드 배경 또는 denied 변형)
//   3. 헤드라인 + 본문
//   4. (선택) 1·2·3 단계 안내 (`PermissionStepsCard`)
//   5. 하단 풀폭 CTA 스택 + 옵션 힌트
//
// 모든 사이즈/패딩/색은 D0 토큰을 통한다. 외부 의존성 X.
struct PermissionScaffold<TopExtras: View, Bottom: View>: View {
    let illustrationSymbol: String
    let illustrationVariant: PermissionIllustrationVariant
    let title: String
    let message: String
    let topExtras: TopExtras
    let bottomActions: Bottom
    let onClose: (() -> Void)?
    let closeAccessibilityLabel: String

    init(
        illustrationSymbol: String,
        illustrationVariant: PermissionIllustrationVariant,
        title: String,
        body: String,
        onClose: (() -> Void)? = nil,
        closeAccessibilityLabel: String = "닫기",
        @ViewBuilder topExtras: () -> TopExtras = { EmptyView() },
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.illustrationSymbol = illustrationSymbol
        self.illustrationVariant = illustrationVariant
        self.title = title
        self.message = body
        self.onClose = onClose
        self.closeAccessibilityLabel = closeAccessibilityLabel
        self.topExtras = topExtras()
        self.bottomActions = bottom()
    }

    var body: some View {
        ZStack {
            FMColors.Background.bg0
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Sp.md)
                    .padding(.top, Sp.xs)
                    .frame(height: 44)

                ScrollView {
                    VStack(spacing: Sp.lg) {
                        Spacer(minLength: Sp.xl)

                        PermissionIllustration(
                            symbol: illustrationSymbol,
                            variant: illustrationVariant
                        )

                        VStack(spacing: Sp.sm) {
                            Text(title)
                                .fmTypography(.titleLarge)
                                .foregroundStyle(FMColors.Text.primary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(message)
                                .fmTypography(.body)
                                .foregroundStyle(FMColors.Text.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: 320)

                        topExtras

                        Spacer(minLength: Sp.lg)
                    }
                    .padding(.horizontal, FMLayout.screenPadding)
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: Sp.xs) {
                    bottomActions
                }
                .padding(.horizontal, FMLayout.screenPadding)
                .padding(.bottom, Sp.lg)
            }
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var topBar: some View {
        HStack {
            if let onClose {
                Button {
                    FMHaptic.light.play()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FMColors.Text.primary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(closeAccessibilityLabel)
            }
            Spacer()
        }
    }
}

// MARK: - PermissionIllustration

enum PermissionIllustrationVariant {
    /// 골드 배경 (priming).
    case priming
    /// bg3 배경 + 빨간 lock 배지 (denied).
    case denied
}

struct PermissionIllustration: View {
    let symbol: String
    let variant: PermissionIllustrationVariant

    private let size: CGFloat = 96
    private let symbolSize: CGFloat = 44

    var body: some View {
        ZStack {
            background

            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .light))
                .foregroundStyle(symbolForeground)

            if variant == .denied {
                lockBadge
                    .offset(x: size / 2 - 6, y: size / 2 - 6)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .priming:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            FMColors.Accent.bg,
                            FMColors.Background.bg0
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .strokeBorder(FMColors.Accent.soft.opacity(0.6), lineWidth: 1)
                }
                .shadow(color: FMColors.Accent.primary.opacity(0.18), radius: 18, x: 0, y: 6)
        case .denied:
            Circle()
                .fill(FMColors.Background.bg3)
                .overlay {
                    Circle()
                        .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                }
        }
    }

    private var symbolForeground: Color {
        switch variant {
        case .priming: FMColors.Accent.primary
        case .denied: FMColors.Text.tertiary
        }
    }

    private var lockBadge: some View {
        ZStack {
            Circle()
                .fill(FMColors.Semantic.error)
                .frame(width: 22, height: 22)
                .overlay {
                    Circle()
                        .strokeBorder(FMColors.Background.bg0, lineWidth: 2)
                }
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
        }
    }
}

// MARK: - PermissionStepsCard

/// 1·2·3 단계 안내 카드. denied 화면 공통.
struct PermissionStepsCard: View {
    struct Step: Identifiable {
        let id = UUID()
        /// AttributedString 으로 일부 단어 강조 가능.
        let text: AttributedString
    }

    let steps: [Step]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: Sp.sm) {
                    StepNumberBadge(number: index + 1)
                    Text(step.text)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, Sp.xs)

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(FMColors.Border.subtle)
                        .frame(height: 1)
                }
            }
        }
        .padding(Sp.md)
        .frame(maxWidth: 320)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StepNumberBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(FMColors.Accent.primary)
            .frame(width: 22, height: 22)
            .background(FMColors.Accent.bg, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - PermissionHint

/// 본문 아래 또는 CTA 아래 힌트 텍스트.
struct PermissionHint: View {
    let text: String

    var body: some View {
        Text(text)
            .fmTypography(.footnote)
            .foregroundStyle(FMColors.Text.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, Sp.xxs)
    }
}

// MARK: - AttributedString helper

extension AttributedString {
    /// 기본 텍스트 + `[k: v]` 매핑으로 일부 단어를 굵게 강조.
    /// 예: `permissionSteps("설정 앱 열기", emphasised: ["설정"])`.
    static func permissionStep(
        _ template: String,
        emphasised: [String]
    ) -> AttributedString {
        var attributed = AttributedString(template)
        for token in emphasised {
            if let range = attributed.range(of: token) {
                attributed[range].font = .system(size: 13, weight: .semibold)
                attributed[range].foregroundColor = FMColors.Text.primary
            }
        }
        return attributed
    }
}
