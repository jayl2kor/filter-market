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
        case .search: "safari"
        case .shutter: "camera.fill"
        case .saved: "bookmark"
        case .profile: "person.crop.circle"
        }
    }

    var systemImageFilled: String {
        switch self {
        case .market: "bag.fill"
        case .search: "safari.fill"
        case .shutter: "camera.fill"
        case .saved: "bookmark.fill"
        case .profile: "person.crop.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .market: "마켓"
        case .search: "발견"
        case .shutter: "촬영"
        case .saved: "저장됨"
        case .profile: "프로필"
        }
    }

    /// VoiceOver 시 사용할 풀 라벨.
    var accessibilityLabel: String {
        switch self {
        case .market: "마켓 탭"
        case .search: "발견 탭"
        case .shutter: "카메라 열기"
        case .saved: "저장된 필터 탭"
        case .profile: "프로필 탭"
        }
    }
}

// MARK: - FMTabBadge

public enum FMTabBadge: Sendable {
    case dot(label: String)
    case number(Int, label: String)

    var accessibilityText: String {
        switch self {
        case .dot(let label):
            return label
        case .number(let count, let label):
            return "\(label) \(count)건"
        }
    }

    var displayText: String? {
        switch self {
        case .dot:
            return nil
        case .number(let count, _):
            if count <= 0 { return nil }
            if count <= 9 { return "\(count)" }
            if count < 100 { return "9+" }
            return "99+"
        }
    }
}

// MARK: - FMTabBar

/// 5탭 + 중앙 셔터 탭바.
///
/// `DESIGN_SYSTEM.md` §8.5 — 49 + 16 padding-bottom = 65pt.
/// 중앙 셔터는 56pt 원형, lift -12px, 골드 fill.
public struct FMTabBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding private var selection: FMTab
    private let badges: [FMTab: FMTabBadge]
    private let onShutter: () -> Void

    public init(
        selection: Binding<FMTab>,
        badges: [FMTab: FMTabBadge] = [:],
        onShutter: @escaping () -> Void
    ) {
        self._selection = selection
        self.badges = badges
        self.onShutter = onShutter
    }

    private var usesIconOnlyLayout: Bool {
        dynamicTypeSize >= .xxxLarge
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
        .padding(.top, 4)
        .padding(.bottom, 2)
        .background(FMColors.Background.bg2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: FMTab) -> some View {
        let isActive = selection == tab
        let badge = badges[tab]
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isActive ? tab.systemImageFilled : tab.systemImage)
                        .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                        .frame(width: 24, height: 24)

                    if let badge {
                        tabBadge(badge)
                            .offset(x: 12, y: -8)
                    }
                }
                .frame(width: 32, height: 24)

                if !usesIconOnlyLayout {
                    Text(tab.label)
                        .font(.caption2.weight(isActive ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .foregroundStyle(isActive ? FMColors.Accent.primary : FMColors.Text.tertiary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: tab, badge: badge))
        .accessibilityIdentifier("tab.\(tab.identifier)")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func tabBadge(_ badge: FMTabBadge) -> some View {
        if let text = badge.displayText {
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(FMColors.Text.inverse)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 4)
                .frame(minWidth: 17, minHeight: 17)
                .background(FMColors.Semantic.error, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(FMColors.Background.bg2, lineWidth: 1.5)
                }
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(FMColors.Semantic.error)
                .frame(width: 9, height: 9)
                .overlay {
                    Circle()
                        .strokeBorder(FMColors.Background.bg2, lineWidth: 1.5)
                }
                .accessibilityHidden(true)
        }
    }

    private func accessibilityLabel(for tab: FMTab, badge: FMTabBadge?) -> String {
        guard let badge else { return tab.accessibilityLabel }
        return "\(tab.accessibilityLabel), \(badge.accessibilityText)"
    }

    private var shutterButton: some View {
        Button(action: onShutter) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(FMColors.Accent.primary)
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(FMColors.Text.inverse)
                }
                .shadow(
                    color: FMColors.Accent.primary.opacity(0.18),
                    radius: 6,
                    x: 0,
                    y: 2
                )
                if !usesIconOnlyLayout {
                    Text(FMTab.shutter.label)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(ShutterPressStyle())
        .accessibilityLabel(FMTab.shutter.accessibilityLabel)
        .accessibilityIdentifier("tab.\(FMTab.shutter.identifier)")
    }
}

private extension FMTab {
    var identifier: String {
        switch self {
        case .market: "market"
        case .search: "search"
        case .shutter: "shutter"
        case .saved: "saved"
        case .profile: "profile"
        }
    }
}

// MARK: - Shutter press style

private struct ShutterPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.fmSpringTap.reducedIfNeeded(reduceMotion), value: configuration.isPressed)
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

            FMTabBar(
                selection: $selection,
                badges: [
                    .saved: .dot(label: "새 다운로드 있음"),
                    .profile: .number(12, label: "미확인 알림")
                ]
            ) {
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
