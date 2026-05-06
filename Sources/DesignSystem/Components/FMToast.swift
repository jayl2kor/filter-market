import SwiftUI

// MARK: - FMToastVariant

public enum FMToastVariant: Sendable {
    case success
    case warning
    case error
    case info

    var iconName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .info: "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .success: FMColors.Semantic.success
        case .warning: FMColors.Semantic.warning
        case .error: FMColors.Semantic.error
        case .info: FMColors.Semantic.info
        }
    }

    var backgroundColor: Color {
        switch self {
        case .success: FMColors.Semantic.successBg
        case .warning: FMColors.Semantic.warningBg
        case .error: FMColors.Semantic.errorBg
        case .info: FMColors.Semantic.infoBg
        }
    }
}

// MARK: - FMToastMessage

public struct FMToastMessage: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let variant: FMToastVariant
    public let title: String
    public let detail: String?
    public let duration: TimeInterval

    public init(
        _ variant: FMToastVariant,
        _ title: String,
        detail: String? = nil,
        duration: TimeInterval = 4.0
    ) {
        self.variant = variant
        self.title = title
        self.detail = detail
        self.duration = duration
    }

    public static func == (lhs: FMToastMessage, rhs: FMToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FMToast

/// 화면 하단 floating toast — auto-dismiss.
/// `MOTION_SPEC.md` §6 토스트 모션 정합 (하단 +20pt → 0, 4초 후 dismiss).
public struct FMToast: View {
    private let message: FMToastMessage

    public init(_ message: FMToastMessage) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Image(systemName: message.variant.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(message.variant.iconColor)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .fmTypography(.callout)
                    .foregroundStyle(FMColors.Text.primary)
                    .lineLimit(2)
                if let detail = message.detail {
                    Text(detail)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.sm)
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(FMColors.Border.default, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - FMBanner

/// 화면 상단 sticky banner — 명시적 close.
public struct FMBanner: View {
    private let variant: FMToastVariant
    private let title: String
    private let detail: String?
    private let onDismiss: (() -> Void)?

    public init(
        _ variant: FMToastVariant,
        title: String,
        detail: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.variant = variant
        self.title = title
        self.detail = detail
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Image(systemName: variant.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(variant.iconColor)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fmTypography(.callout)
                    .foregroundStyle(FMColors.Text.primary)
                if let detail {
                    Text(detail)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                .accessibilityLabel("닫기")
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.sm)
        .background(variant.backgroundColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
    }
}

// MARK: - Toast overlay modifier

public extension View {
    /// 화면 하단 floating toast 표시 + 자동 dismiss.
    func fmToastOverlay(toast: Binding<FMToastMessage?>) -> some View {
        modifier(FMToastOverlayModifier(toast: toast))
    }
}

private struct FMToastOverlayModifier: ViewModifier {
    @Binding var toast: FMToastMessage?
    @State private var dismissTask: Task<Void, Never>? = nil

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message = toast {
                    FMToast(message)
                        .padding(.horizontal, Sp.md)
                        .padding(.bottom, FMLayout.tabBarHeight + Sp.md)
                        .transition(
                            .move(edge: .bottom).combined(with: .opacity)
                        )
                        .zIndex(Z.toast)
                        .onAppear { scheduleDismiss(for: message) }
                }
            }
            .animation(.fmSpringSheet, value: toast?.id)
            .onChange(of: toast?.id) { _, newId in
                if newId == nil {
                    dismissTask?.cancel()
                    dismissTask = nil
                }
            }
    }

    private func scheduleDismiss(for message: FMToastMessage) {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(message.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.fmSpringSheet) {
                toast = nil
            }
        }
    }
}

// MARK: - Preview

private struct FMToastPreview: View {
    @State private var current: FMToastMessage? = nil

    var body: some View {
        VStack(spacing: Sp.md) {
            FMButton("Success", variant: .primary) {
                current = FMToastMessage(.success, "저장됐어요", detail: "내 라이브러리에 추가됨")
            }
            FMButton("Warning", variant: .secondary) {
                current = FMToastMessage(.warning, "용량이 거의 찼어요")
            }
            FMButton("Error", variant: .destructive) {
                current = FMToastMessage(.error, "업로드 실패", detail: "네트워크를 확인하세요")
            }
            FMButton("Info", variant: .ghost) {
                current = FMToastMessage(.info, "새 버전 사용 가능")
            }
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.Background.bg1)
        .fmToastOverlay(toast: $current)
    }
}

#Preview("FMToast — interactive") {
    FMToastPreview()
}

#Preview("FMBanner — variants") {
    VStack(spacing: 0) {
        FMBanner(.info, title: "오프라인 모드", detail: "최근 다운로드 콘텐츠만 보여요", onDismiss: {})
        FMBanner(.warning, title: "저장공간 부족", onDismiss: {})
        FMBanner(.error, title: "업로드 중단됨", detail: "다시 시도하려면 탭하세요")
        FMBanner(.success, title: "동기화 완료")
        Spacer()
    }
    .background(FMColors.Background.bg1)
}

#Preview("FMToast — Dark") {
    VStack {
        FMToast(FMToastMessage(.success, "다크 모드 토스트"))
            .padding(Sp.md)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FMColors.Background.bg1)
    .preferredColorScheme(.dark)
}
