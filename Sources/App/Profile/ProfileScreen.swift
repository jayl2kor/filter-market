import DesignSystem
import SwiftUI

// MARK: - ProfileSection

/// 프로필 그리드 세그먼트.
enum ProfileSection: Hashable, CaseIterable {
    case myFilters
    case saved
    case captures

    var title: String {
        switch self {
        case .myFilters: "내 필터"
        case .saved: "저장됨"
        case .captures: "촬영함"
        }
    }
}

// MARK: - ProfileScreen

/// 프로필 — 9번 화면.
///
/// Phase D3 — `mockups/screens/09-profile.html` 와 정합.
/// 헤더 + 아바타/닉네임/소개 + 통계 3분할 + 액션 + 세그먼트 + 3열 그리드.
struct ProfileScreen: View {
    @EnvironmentObject private var store: MooditStore

    private let user: ProfileUser
    @State private var selectedSection: ProfileSection = .myFilters
    @State private var hasAppeared = false
    @State private var navigateToSettings = false

    init(user: ProfileUser? = nil) {
        self.user = user ?? .preview
    }

    /// 시뮬레이션: 첫 진입 시 짧은 로딩 후 그리드 표시.
    private var isLoading: Bool {
        !hasAppeared
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileHead
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.md)

                    statsRow
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.md)

                    actionsRow
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.md)

                    segmentedRow
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.lg)
                        .padding(.bottom, Sp.md)

                    if isLoading {
                        loadingGrid
                            .padding(.horizontal, Sp.md)
                    } else if currentItems.isEmpty {
                        emptyState
                            .padding(.top, Sp.xxl)
                    } else {
                        contentGrid
                            .padding(.horizontal, Sp.md)
                    }
                }
                .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
            }
            .background(FMColors.Background.bg0)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 28, height: 28)
                }
                ToolbarItem(placement: .principal) {
                    Text(user.handle)
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
                }
            }
            .toolbarBackground(FMColors.Background.bg0, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsScreen()
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            hasAppeared = true
        }
    }

    // MARK: - Head

    private var profileHead: some View {
        VStack(spacing: Sp.sm) {
            FMAvatar(initials: user.avatarInitials, size: .xl)

            Text(user.displayName)
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)
                .multilineTextAlignment(.center)

            Text(user.handle)
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)

            Text(user.bio)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .lineLimit(3)
                .padding(.top, Sp.xxs)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: Sp.md) {
            statItem(value: user.filterCount, label: "필터") {}
            statDivider
            statItem(value: user.followerCount, label: "팔로워") {}
            statDivider
            statItem(value: user.followingCount, label: "팔로잉") {}
        }
        .padding(.vertical, Sp.md)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
    }

    private func statItem(value: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(formattedCount(value))
                    .fmTypography(.title)
                    .foregroundStyle(FMColors.Text.primary)
                    .monospacedDigit()
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(value)")
    }

    private var statDivider: some View {
        Rectangle()
            .fill(FMColors.Border.subtle)
            .frame(width: 1, height: 28)
    }

    // MARK: - Actions

    private var actionsRow: some View {
        HStack(spacing: Sp.xs) {
            FMButton(
                user.isOwnProfile ? "프로필 편집" : "팔로우",
                variant: user.isOwnProfile ? .secondary : .primary,
                size: .md
            ) {
                // 후속 Phase 에서 편집/팔로우 흐름 연결.
            }

            Button {
                // 공유 — 후속 Phase.
                FMHaptic.light.play()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FMColors.Text.primary)
                    .frame(width: 44, height: 44)
                    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(FMColors.Border.default, lineWidth: 1)
                    }
            }
            .accessibilityLabel("프로필 공유")
        }
    }

    // MARK: - Segmented

    private var segmentedRow: some View {
        FMSegmentedControl(
            selection: $selectedSection,
            options: ProfileSection.allCases,
            title: \.title
        )
    }

    // MARK: - Grid

    private var contentGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ],
            spacing: 4
        ) {
            ForEach(Array(currentItems.enumerated()), id: \.element.id) { index, item in
                gridTile(item: item)
                    .accessibilityIdentifier("profile.tile.\(selectedSection).\(index)")
            }
        }
    }

    private func gridTile(item: ProfileGridItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    item.categoryHint.opacity(0.55),
                    Color.black.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.45),
                    .init(color: Color.black.opacity(0.7), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if item.downloadCount > 0 {
                    Text(formattedCount(item.downloadCount))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, Sp.xs)
            .padding(.bottom, Sp.xs)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: R.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            item.downloadCount > 0
                ? "\(item.title), 다운로드 \(item.downloadCount)"
                : item.title
        )
    }

    // MARK: - Empty / Loading

    private var emptyState: some View {
        FMEmptyState(
            .emptyProfile(
                isOwnProfile: user.isOwnProfile,
                makerName: user.isOwnProfile ? nil : user.displayName
            )
        )
        .padding(.vertical, Sp.xxl)
    }

    private var loadingGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ],
            spacing: 4
        ) {
            ForEach(0..<9, id: \.self) { _ in
                FMSkeleton.rect(height: 110, cornerRadius: R.sm)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    // MARK: - Toolbar

    private var settingsButton: some View {
        Button {
            navigateToSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: IconSize.lg - 4, weight: .regular))
                .foregroundStyle(FMColors.Text.primary)
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel("설정 열기")
    }

    // MARK: - Helpers

    private var currentItems: [ProfileGridItem] {
        // 빈 메이커 (필터 0개) 일 때는 myFilters 섹션이 비어있다.
        if user.filterCount == 0, selectedSection == .myFilters {
            return []
        }
        switch selectedSection {
        case .myFilters: return ProfileMockData.myFilters
        case .saved: return ProfileMockData.saved
        case .captures: return ProfileMockData.captures
        }
    }

    private func formattedCount(_ count: Int) -> String {
        switch count {
        case ..<1_000: "\(count)"
        case 1_000..<10_000: String(format: "%.1fK", Double(count) / 1_000)
        default: "\(count / 1_000)K"
        }
    }
}

// MARK: - Preview

#Preview("ProfileScreen — Light") {
    ProfileScreen()
        .environmentObject(MooditStore())
}

#Preview("ProfileScreen — Empty myFilters") {
    ProfileScreen(user: .empty)
        .environmentObject(MooditStore())
}

#Preview("ProfileScreen — Other user") {
    ProfileScreen(user: .other)
        .environmentObject(MooditStore())
}

#Preview("ProfileScreen — Dark") {
    ProfileScreen()
        .environmentObject(MooditStore())
        .preferredColorScheme(.dark)
}

#Preview("ProfileScreen — XXXLarge") {
    ProfileScreen()
        .environmentObject(MooditStore())
        .dynamicTypeSize(.xxxLarge)
}
