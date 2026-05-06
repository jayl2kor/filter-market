import SwiftUI
import UIKit

// MARK: - FMButton

/// 디자인 시스템 표준 버튼.
///
/// 변형 4 × 사이즈 3 + loading/disabled 상태.
/// `DESIGN_SYSTEM.md` §8.1 Button 스펙과 정합.
public struct FMButton: View {
    public enum Variant: Sendable {
        case primary
        case secondary
        case ghost
        case destructive
    }

    public enum Size: Sendable {
        case sm  // 36
        case md  // 44 (default)
        case lg  // 52

        var height: CGFloat {
            switch self {
            case .sm: 36
            case .md: 44
            case .lg: 52
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .sm: Sp.sm
            case .md: Sp.md
            case .lg: Sp.lg
            }
        }

        var typography: FMTypography.Style {
            switch self {
            case .sm: FMTypography.subhead
            case .md: FMTypography.callout
            case .lg: FMTypography.headline
            }
        }
    }

    private let title: String
    private let icon: String?
    private let variant: Variant
    private let size: Size
    private let isLoading: Bool
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false

    public init(
        _ title: String,
        icon: String? = nil,
        variant: Variant = .primary,
        size: Size = .md,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.size = size
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: handleTap) {
            HStack(spacing: Sp.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.85)
                        .tint(foregroundColor)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: size.typography.size, weight: .semibold))
                }

                Text(title)
                    .fmTypography(size.typography)
                    .lineLimit(1)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundShape)
            .overlay(borderShape)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isEnabled && !isLoading ? 1.0 : Opacity.textDisabled)
            .animation(.fmSpringTap, value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .disabled(isLoading || !isEnabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Style helpers

    @ViewBuilder
    private var backgroundShape: some View {
        switch variant {
        case .primary:
            RoundedRectangle(cornerRadius: R.md)
                .fill(isPressed ? FMColors.Accent.pressed : FMColors.Accent.primary)
        case .secondary:
            RoundedRectangle(cornerRadius: R.md)
                .fill(isPressed ? FMColors.Background.bg1 : FMColors.Background.bg2)
        case .ghost:
            RoundedRectangle(cornerRadius: R.md)
                .fill(isPressed ? FMColors.Background.bg1 : .clear)
        case .destructive:
            RoundedRectangle(cornerRadius: R.md)
                .fill(isPressed ? FMColors.Semantic.errorBg : .clear)
        }
    }

    @ViewBuilder
    private var borderShape: some View {
        switch variant {
        case .primary:
            EmptyView()
        case .secondary:
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(FMColors.Border.default, lineWidth: 1)
        case .ghost:
            EmptyView()
        case .destructive:
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(FMColors.Semantic.error.opacity(0.35), lineWidth: 1)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: FMColors.Text.inverse
        case .secondary: FMColors.Text.primary
        case .ghost: FMColors.Accent.primary
        case .destructive: FMColors.Semantic.error
        }
    }

    private func handleTap() {
        guard !isLoading, isEnabled else { return }
        // Light impact 햅틱 — Phase D6 에서 `FMHaptic` wrapper 로 통일.
        FMHaptic.light.play()
        action()
    }
}

// MARK: - Pressable button style

private struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Preview

#Preview("FMButton — variants & sizes") {
    ScrollView {
        VStack(alignment: .leading, spacing: Sp.lg) {
            Group {
                Text("Primary").fmTypography(.subhead)
                FMButton("로그인", variant: .primary, size: .lg) {}
                FMButton("로그인", variant: .primary, size: .md) {}
                FMButton("로그인", variant: .primary, size: .sm) {}
            }
            Group {
                Text("Secondary").fmTypography(.subhead)
                FMButton("취소", variant: .secondary, size: .md) {}
                FMButton("나중에", variant: .secondary, size: .sm) {}
            }
            Group {
                Text("Ghost").fmTypography(.subhead)
                FMButton("건너뛰기", variant: .ghost, size: .md) {}
            }
            Group {
                Text("Destructive").fmTypography(.subhead)
                FMButton("삭제", icon: "trash", variant: .destructive, size: .md) {}
            }
            Group {
                Text("States").fmTypography(.subhead)
                FMButton("비활성", variant: .primary, size: .md) {}
                    .disabled(true)
                FMButton("로딩 중", variant: .primary, size: .md, isLoading: true) {}
            }
        }
        .padding(Sp.md)
    }
    .background(FMColors.Background.bg1)
}

#Preview("FMButton — Dark") {
    ScrollView {
        VStack(spacing: Sp.md) {
            FMButton("저장", variant: .primary, size: .lg) {}
            FMButton("취소", variant: .secondary, size: .md) {}
            FMButton("건너뛰기", variant: .ghost, size: .md) {}
            FMButton("삭제", variant: .destructive, size: .md) {}
        }
        .padding(Sp.md)
    }
    .background(FMColors.Background.bg1)
    .preferredColorScheme(.dark)
}

#Preview("FMButton — XXXLarge") {
    VStack(spacing: Sp.md) {
        FMButton("로그인", variant: .primary, size: .lg) {}
        FMButton("취소", variant: .secondary, size: .md) {}
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg1)
    .dynamicTypeSize(.xxxLarge)
}
