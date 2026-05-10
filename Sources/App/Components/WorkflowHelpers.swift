import DesignSystem
import SwiftUI

@ViewBuilder
@MainActor
func closedLoopPayoutPlaceholder(title: String) -> some View {
    ScrollView {
        VStack(alignment: .leading, spacing: Sp.lg) {
            HStack(spacing: Sp.md) {
                Image(systemName: "tray.full")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(width: 56, height: 56)
                    .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.md))
                VStack(alignment: .leading, spacing: 4) {
                    Text("출금은 추후 지원 예정이에요")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("적립한 코인은 moodit 안에서 자유롭게 사용할 수 있어요.")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }

            FMCard {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    Text("적립 코인 사용처")
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                    bulletRow(icon: "camera.filters", text: "다른 메이커의 유료 필터 다운로드")
                    bulletRow(icon: "sparkles", text: "Pro 멤버십 결제 (Phase 5+ 예정)")
                    bulletRow(icon: "star.circle", text: "프로필 강조 / 우선 노출 슬롯 (Phase 5+ 예정)")
                }
            }

            Text("원화 출금 기능은 Phase 6에서 메이커 누적 잔액과 운영 환경을 보고 다시 평가합니다. 자세한 정책은 ADR-0006(closed-loop virtual currency)에 기록되어 있어요.")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.tertiary)
                .padding(.horizontal, Sp.xs)
        }
        .padding(Sp.md)
        .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
    }
    .background(FMColors.Background.bg1)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("payout.placeholder.\(title)")
}

@MainActor
func bulletRow(icon: String, text: String) -> some View {
    HStack(alignment: .top, spacing: Sp.sm) {
        Image(systemName: icon)
            .foregroundStyle(FMColors.Accent.primary)
            .frame(width: 20)
        Text(text)
            .fmTypography(.body)
            .foregroundStyle(FMColors.Text.secondary)
        Spacer(minLength: 0)
    }
}

@MainActor
func workflowHeader(title: String, subtitle: String, symbol: String) -> some View {
    VStack(alignment: .leading, spacing: Sp.md) {
        Image(systemName: symbol)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(FMColors.Accent.primary)
            .frame(width: 56, height: 56)
            .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.lg))
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(FMColors.Accent.primary.opacity(0.24), lineWidth: 1)
            }

        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(title)
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)
            Text(subtitle)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

@MainActor
func routeButton(_ title: String, icon: String) -> some View {
    HStack(spacing: Sp.xs) {
        Image(systemName: icon)
        Text(title)
            .fmTypography(.headline)
        Spacer()
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, Sp.md)
    .frame(height: 52)
    .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
}

@MainActor
func workflowRouteRow(_ title: String, icon: String) -> some View {
    HStack(spacing: Sp.sm) {
        Image(systemName: icon)
            .font(.system(size: IconSize.md, weight: .regular))
            .foregroundStyle(FMColors.Accent.primary)
            .frame(width: 28, height: 28)
        Text(title)
            .fmTypography(.body)
            .foregroundStyle(FMColors.Text.primary)
        Spacer()
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FMColors.Text.tertiary)
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.lg))
}

@MainActor
func compactRouteButton(_ title: String, icon: String) -> some View {
    HStack(spacing: Sp.xs) {
        Image(systemName: icon)
        Text(title)
            .fmTypography(.subhead)
            .lineLimit(1)
        Spacer(minLength: 0)
    }
    .foregroundStyle(FMColors.Text.primary)
    .padding(.horizontal, Sp.sm)
    .frame(maxWidth: .infinity)
    .frame(height: 44)
    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
    .overlay {
        RoundedRectangle(cornerRadius: R.md)
            .strokeBorder(FMColors.Border.default, lineWidth: 1)
    }
}

@MainActor
func sectionLabel(_ title: String) -> some View {
    Text(title)
        .fmTypography(.caption)
        .foregroundStyle(FMColors.Text.tertiary)
        .textCase(.uppercase)
}

@MainActor
func workflowDivider() -> some View {
    Rectangle()
        .fill(FMColors.Border.subtle)
        .frame(height: 1)
}

@MainActor
func uploadProgress(active: UploadStep) -> some View {
    HStack(spacing: Sp.xs) {
        ForEach(UploadStep.allCases) { step in
            VStack(spacing: 4) {
                Circle()
                    .fill(uploadStepIndex(step) <= uploadStepIndex(active) ? FMColors.Accent.primary : FMColors.Background.bg3)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Text("\(uploadStepIndex(step) + 1)")
                            .fmTypography(.caption)
                            .foregroundStyle(uploadStepIndex(step) <= uploadStepIndex(active) ? .white : FMColors.Text.tertiary)
                    }
                Text(step.title)
                    .fmTypography(.caption)
                    .foregroundStyle(step == active ? FMColors.Text.primary : FMColors.Text.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }
    .padding(Sp.sm)
    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("업로드 \(UploadStep.allCases.count)단계 중 \(uploadStepIndex(active) + 1)단계")
    .accessibilityValue(active.title)
}

func uploadStepIndex(_ step: UploadStep) -> Int {
    switch step {
    case .cover: 0
    case .tags: 1
    case .submit: 2
    case .pending: 3
    }
}

enum MakerStep: CaseIterable, Sendable {
    case edit
    case lut
    case draft

    var title: String {
        switch self {
        case .edit: "편집"
        case .lut: "LUT"
        case .draft: "초안"
        }
    }
}

func makerStepIndex(_ step: MakerStep) -> Int {
    switch step {
    case .edit: 0
    case .lut: 1
    case .draft: 2
    }
}

@MainActor
func makerProgress(active: MakerStep) -> some View {
    HStack(spacing: Sp.xs) {
        ForEach(MakerStep.allCases, id: \.self) { step in
            VStack(spacing: 4) {
                Circle()
                    .fill(makerStepIndex(step) <= makerStepIndex(active) ? FMColors.Accent.primary : FMColors.Background.bg3)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Text("\(makerStepIndex(step) + 1)")
                            .fmTypography(.caption)
                            .foregroundStyle(makerStepIndex(step) <= makerStepIndex(active) ? .white : FMColors.Text.tertiary)
                    }
                Text(step.title)
                    .fmTypography(.caption)
                    .foregroundStyle(step == active ? FMColors.Text.primary : FMColors.Text.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }
    .padding(Sp.sm)
    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("필터 만들기 \(MakerStep.allCases.count)단계 중 \(makerStepIndex(active) + 1)단계")
    .accessibilityValue(active.title)
    .accessibilityIdentifier("maker.progress")
}
