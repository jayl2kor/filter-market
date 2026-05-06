import SwiftUI

// MARK: - FMSwipeIndicator

/// `DESIGN_SYSTEM.md` §8.14 SwipeIndicator.
///
/// 7-dot 가로 페이지 인디케이터. 활성 페이지는 16×4 막대, 비활성은 4×4 점.
/// 카메라 흐름(다크 토큰)과 일반 라이트 화면 모두에서 사용 가능.
public struct FMSwipeIndicator: View {
    public enum Mode: Sendable {
        case light
        case dark
    }

    private let count: Int
    private let activeIndex: Int
    private let mode: Mode

    public init(count: Int = 7, activeIndex: Int = 0, mode: Mode = .light) {
        self.count = max(1, count)
        self.activeIndex = max(0, min(count - 1, activeIndex))
        self.mode = mode
    }

    private var indices: [Int] {
        (0..<count).map { $0 }
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(indices, id: \.self) { index in
                let isActive = index == activeIndex
                Capsule()
                    .fill(isActive ? activeColor : inactiveColor)
                    .frame(width: isActive ? 16 : 4, height: 4)
                    .animation(.fmFast, value: activeIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("페이지 \(activeIndex + 1) / \(count)")
    }

    private var activeColor: Color {
        switch mode {
        case .light: FMColors.Accent.primary
        case .dark: FMColors.Accent.primary
        }
    }

    private var inactiveColor: Color {
        switch mode {
        case .light: FMColors.Text.tertiary.opacity(0.4)
        case .dark: Color.white.opacity(0.4)
        }
    }
}

// MARK: - Preview

#Preview("FMSwipeIndicator — Light") {
    VStack(spacing: Sp.lg) {
        FMSwipeIndicator(count: 7, activeIndex: 0)
        FMSwipeIndicator(count: 7, activeIndex: 3)
        FMSwipeIndicator(count: 7, activeIndex: 6)
        FMSwipeIndicator(count: 4, activeIndex: 1)
    }
    .padding(Sp.xl)
    .frame(maxWidth: .infinity)
    .background(FMColors.Background.bg1)
}

#Preview("FMSwipeIndicator — Dark on photo") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: 0x594878), Color(hex: 0x1F1832)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        FMSwipeIndicator(count: 7, activeIndex: 3, mode: .dark)
            .padding(Sp.md)
            .background(.ultraThinMaterial, in: Capsule())
    }
    .frame(height: 200)
}
