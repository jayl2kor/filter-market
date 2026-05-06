import SwiftUI

// MARK: - FMTab

public enum FMTab: Hashable, CaseIterable, Sendable {
    case market
    case search
    case shutter   // 중앙 셔터 — selection 으로 사용 X (onShutter 콜백 트리거)
    case saved
    case profile

    var systemImage: String {
        switch self {
        case .market: "bag"
        case .search: "magnifyingglass"
        case .shutter: "camera.fill"
        case .saved: "bookmark"
        case .profile: "person.crop.circle"
        }
    }

    var systemImageFilled: String {
        switch self {
        case .market: "bag.fill"
        case .search: "magnifyingglass"
        case .shutter: "camera.fill"
        case .saved: "bookmark.fill"
        case .profile: "person.crop.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .market: "마켓"
        case .search: "검색"
        case .shutter: "촬영"
        case .saved: "저장됨"
        case .profile: "프로필"
        }
    }

    /// VoiceOver 시 사용할 풀 라벨.
    var accessibilityLabel: String {
        switch self {
        case .market: "마켓 탭"
        case .search: "검색 탭"
        case .shutter: "카메라 열기"
        case .saved: "저장된 필터 탭"
        case .profile: "프로필 탭"
        }
    }
}

// MARK: - FMTabBar

/// 5탭 + 중앙 셔터 탭바.
///
/// `DESIGN_SYSTEM.md` §8.5 — 49 + 16 padding-bottom = 65pt.
/// 중앙 셔터는 56pt 원형, lift -12px, 골드 fill.
public struct FMTabBar: View {
    @Binding private var selection: FMTab
    private let onShutter: () -> Void

    public init(selection: Binding<FMTab>, onShutter: @escaping () -> Void) {
        self._selection = selection
        self.onShutter = onShutter
    }

    public var body: some View {
        HStack(spacing: 0) {
            tabButton(.market)
            tabButton(.search)
            shutterButton
            tabButton(.saved)
            tabButton(.profile)
        }
        .frame(height: FMLayout.tabBarHeight)
        .padding(.bottom, Sp.md)
        .background(FMColors.Background.bg2.opacity(0.85))
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: FMTab) -> some View {
        let isActive = selection == tab
        Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isActive ? tab.systemImageFilled : tab.systemImage)
                    .font(.system(size: IconSize.lg, weight: .regular))
                    .frame(width: IconSize.lg, height: IconSize.lg)
                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.2)
            }
            .foregroundStyle(isActive ? FMColors.Accent.primary : FMColors.Text.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: FMLayout.tabBarHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private var shutterButton: some View {
        Button(action: onShutter) {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(FMColors.Text.inverse)
                .frame(width: 56, height: 56)
                .background(FMColors.Accent.primary, in: Circle())
                .shadow(
                    color: FMColors.Accent.primary.opacity(0.34),
                    radius: 16,
                    x: 0,
                    y: 6
                )
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 3,
                    x: 0,
                    y: 1
                )
                .offset(y: -12)
        }
        .buttonStyle(ShutterPressStyle())
        .frame(maxWidth: .infinity)
        .accessibilityLabel(FMTab.shutter.accessibilityLabel)
    }
}

// MARK: - Shutter press style

private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.fmSpringTap, value: configuration.isPressed)
    }
}

// MARK: - Preview

private struct FMTabBarPreview: View {
    @State private var selection: FMTab = .market
    @State private var shutterCount = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text("선택됨: \(selection.label)")
                    .fmTypography(.headline)
                Text("셔터 탭: \(shutterCount) 회")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FMColors.Background.bg1)

            FMTabBar(selection: $selection) {
                shutterCount += 1
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview("FMTabBar — Light") {
    FMTabBarPreview()
}

#Preview("FMTabBar — Dark") {
    FMTabBarPreview()
        .preferredColorScheme(.dark)
}
