import DesignSystem
import FirebaseAuth
import FirebaseFirestore
import Models
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
    @StateObject private var profileStore = ProfileSelfStore()

    /// 로그인 여부 — placeholder 인증 상태. 실제 Firebase Auth 통합 전까지 단순 플래그.
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false

    /// 명시적으로 전달된 사용자 (e.g. `.other`). nil이면 본인 — Auth + Firestore에서 동적 조립.
    private let injectedUser: ProfileUser?
    /// 다른 사용자 프로필 진입 시 uid. nil이면 본인 프로필.
    private let otherUid: String?
    @State private var selectedSection: ProfileSection = .myFilters
    @State private var hasAppeared = false
    @State private var navigateToLogin = false
    @State private var shareSheetPayload: SharePayload?
    @State private var fetchedOtherUser: ProfileUser?
    @State private var isOtherProfileLoading = false
    @State private var isOtherProfileNotFound = false
    @State private var otherProfileLoadError: String?

    init(user: ProfileUser? = nil) {
        self.injectedUser = user
        self.otherUid = nil
    }

    init(otherUid: String) {
        self.injectedUser = nil
        self.otherUid = otherUid
    }

    /// 화면에 표시할 사용자 — 우선순위: 외부 주입 > otherUid 로드 결과 > store.currentUserProfile (본인) > placeholder.
    private var user: ProfileUser {
        if let injectedUser { return injectedUser }
        if otherUid != nil, let other = fetchedOtherUser { return other }
        if otherUid == nil, let mine = profileStore.currentUserProfile { return mine }
        // 로드 전 placeholder.
            return ProfileUser(
                displayName: otherUid != nil ? "..." : "사용자",
                handle: otherUid.map { "@" + String($0.prefix(8)) } ?? "@user",
            bio: "",
            avatarInitials: "··",
            filterCount: 0,
            followerCount: 0,
            followingCount: 0,
            isOwnProfile: otherUid == nil
        )
    }

    private func loadOtherProfile() async {
        guard let uid = otherUid else { return }
        isOtherProfileLoading = true
        isOtherProfileNotFound = false
        otherProfileLoadError = nil
        #if DEBUG
        if isUITesting {
            fetchedOtherUser = .other
            isOtherProfileLoading = false
            return
        }
        #endif
        do {
            let snap = try await Firestore.firestore().collection("users").document(uid).getDocument()
            guard snap.exists, let data = snap.data() else {
                fetchedOtherUser = nil
                isOtherProfileNotFound = true
                isOtherProfileLoading = false
                return
            }
            let displayName = (data["displayName"] as? String) ?? "사용자"
            let rawHandle = (data["handle"] as? String) ?? String(uid.prefix(8))
            let handle = ProfileSelfStore.displayHandle(from: rawHandle)
            let bio = (data["bio"] as? String) ?? ""
            let initials = String(displayName.prefix(2)).uppercased()
            let followerCount = (data["followerCount"] as? Int) ?? 0
            let followingCount = (data["followingCount"] as? Int) ?? 0
            let filterCount = (data["filterCount"] as? Int) ?? 0
            fetchedOtherUser = ProfileUser(
                displayName: displayName,
                handle: handle,
                bio: bio,
                avatarInitials: initials,
                filterCount: filterCount,
                followerCount: followerCount,
                followingCount: followingCount,
                isOwnProfile: false
            )
            isOtherProfileLoading = false
        } catch {
            fetchedOtherUser = nil
            otherProfileLoadError = error.localizedDescription
            isOtherProfileLoading = false
        }
    }

    /// 시뮬레이션: 첫 진입 시 짧은 로딩 후 그리드 표시.
    private var isLoading: Bool {
        if otherUid != nil {
            return isOtherProfileLoading && fetchedOtherUser == nil && !isOtherProfileNotFound && otherProfileLoadError == nil
        }
        return !hasAppeared
    }

    var body: some View {
        if isAuthenticated {
            authenticatedBody
        } else {
            guestBody
        }
    }

    // MARK: - Guest (비로그인)

    private var guestBody: some View {
        NavigationStack {
            VStack(spacing: Sp.lg) {
                Spacer()

                // 아바타 placeholder
                ZStack {
                    Circle()
                        .fill(FMColors.Background.bg2)
                        .frame(width: 96, height: 96)
                    Image(systemName: "person.fill")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(FMColors.Text.tertiary)
                }

                VStack(spacing: Sp.xs) {
                    Text("로그인이 필요해요")
                        .fmTypography(.title)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("필터를 저장하고 나만의 프로필을 만들어보세요")
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Sp.xl)
                }

                FMButton("로그인하기", variant: .primary, size: .lg) {
                    navigateToLogin = true
                }
                .accessibilityIdentifier("profile.login")
                .padding(.horizontal, Sp.xl)
                .padding(.top, Sp.md)

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FMColors.Background.bg0)
            .padding(.bottom, FMLayout.tabBarHeight)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("프로필")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                }
            }
            .toolbarBackground(FMColors.Background.bg0, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToLogin) {
                LoginScreen(onAuthenticated: {
                    isAuthenticated = true
                    navigateToLogin = false
                })
            }
            .appRouteDestinations()
        }
    }

    // MARK: - Authenticated (로그인 후)

    private var authenticatedBody: some View {
        NavigationStack {
            ScrollView {
                if shouldShowOtherProfileError {
                    otherProfileErrorState
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.xxxl)
                        .frame(maxWidth: .infinity)
                } else {
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

                        if user.isOwnProfile {
                            profileShortcuts
                                .padding(.horizontal, Sp.md)
                                .padding(.top, Sp.sm)
                        }

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
            }
            .background(FMColors.Background.bg0)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(shouldShowOtherProfileError ? "프로필" : user.handle)
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
                }
            }
            .toolbarBackground(FMColors.Background.bg0, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .appRouteDestinations()
        }
        .task {
            if otherUid == nil {
                profileStore.start()
            } else {
                await loadOtherProfile()
            }
            // hasAppeared 즉시 true — 데이터 listener가 도착하면 자동 갱신. (#18 hardcoded 250ms sleep 제거)
            hasAppeared = true
        }
        .onDisappear {
            if otherUid == nil {
                profileStore.stop()
            }
        }
        .sheet(item: $shareSheetPayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
    }

    private func profileShareURL() -> URL {
        let handle = user.handle.replacingOccurrences(of: "@", with: "")
        return URL(string: "https://moodit.app/u/\(handle)") ?? URL(string: "https://moodit.app")!
    }

    private var shouldShowOtherProfileError: Bool {
        otherUid != nil && (isOtherProfileNotFound || otherProfileLoadError != nil)
    }

    private var otherProfileErrorState: some View {
        VStack(spacing: Sp.md) {
            Image(systemName: isOtherProfileNotFound ? "person.crop.circle.badge.questionmark" : "wifi.exclamationmark")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(FMColors.Text.tertiary)
                .frame(width: 96, height: 96)
                .background(FMColors.Background.bg2, in: Circle())

            VStack(spacing: Sp.xs) {
                Text(isOtherProfileNotFound ? "사용자를 찾을 수 없어요" : "프로필을 불러오지 못했어요")
                    .fmTypography(.title)
                    .foregroundStyle(FMColors.Text.primary)
                Text(otherProfileLoadError ?? "삭제되었거나 접근할 수 없는 프로필입니다.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
                    .multilineTextAlignment(.center)
            }

            if !isOtherProfileNotFound {
                FMButton("다시 시도", variant: .primary, size: .md) {
                    Task { await loadOtherProfile() }
                }
                .accessibilityIdentifier("profile.other.retry")
            }
        }
        .frame(maxWidth: .infinity)
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
            NavigationLink(value: AppRoute.myFilters) {
                statContent(value: user.filterCount, label: "필터")
            }
            .buttonStyle(.plain)
            statDivider
            NavigationLink(value: AppRoute.followers(uid: followListUserID)) {
                statContent(value: user.followerCount, label: "팔로워")
            }
            .buttonStyle(.plain)
            statDivider
            NavigationLink(value: AppRoute.following(uid: followListUserID)) {
                statContent(value: user.followingCount, label: "팔로잉")
            }
            .buttonStyle(.plain)
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

    private var followListUserID: String {
        if let otherUid { return otherUid }
        if let uid = Auth.auth().currentUser?.uid { return uid }
        return user.handle.replacingOccurrences(of: "@", with: "")
    }

    @ViewBuilder
    private func statContent(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(formattedCount(value))
                .fmTypography(.title)
                .foregroundStyle(FMColors.Text.primary)
                .monospacedDigit()
            Text(label)
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statItem(value: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(formattedCount(value))
                    .fmTypography(.title)
                    .foregroundStyle(FMColors.Text.primary)
                    .monospacedDigit()
                Text(label.uppercased())
                    .fmTypography(.caption)
                    .fontWeight(.medium)
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
            if user.isOwnProfile {
                NavigationLink(value: AppRoute.editProfile) {
                    Text("프로필 편집")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                        .overlay {
                            RoundedRectangle(cornerRadius: R.md)
                                .strokeBorder(FMColors.Border.default, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.edit.open")
            } else {
                FMButton("팔로우", variant: .primary, size: .md) {
                    FMHaptic.light.play()
                }
            }

            Button {
                FMHaptic.light.play()
                shareSheetPayload = SharePayload(items: [profileShareURL()])
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

    private var profileShortcuts: some View {
        HStack(spacing: Sp.xs) {
            shortcutLink("새 필터", icon: "plus.app", route: .editor)
            shortcutLink("지갑", icon: "creditcard", route: .wallet)
            shortcutLink("내 필터", icon: "rectangle.stack", route: .myFilters)
            shortcutLink("대시보드", icon: "chart.bar", route: .makerDashboard)
        }
    }

    private func shortcutLink(_ title: String, icon: String, route: AppRoute) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Sp.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .fmTypography(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .foregroundStyle(FMColors.Text.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(FMColors.Border.default, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("profile.shortcut.\(shortcutIdentifier(for: route))")
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
                NavigationLink(value: route(for: item)) {
                    gridTile(item: item)
                }
                .buttonStyle(.plain)
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
                    .fmTypography(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.Text.inverse)
                    .lineLimit(1)
                if item.downloadCount > 0 {
                    Text(formattedCount(item.downloadCount))
                        .fmTypography(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(FMColors.Text.inverse.opacity(0.78))
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
        NavigationLink(value: AppRoute.settings) {
            Image(systemName: "gearshape")
                .font(.system(size: IconSize.lg - 4, weight: .regular))
                .foregroundStyle(FMColors.Text.primary)
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel("설정 열기")
        .accessibilityIdentifier("profile.settings")
    }

    // MARK: - Helpers

    private var currentItems: [ProfileGridItem] {
        switch selectedSection {
        case .myFilters:
            return profileStore.myFilters.map { f in
                ProfileGridItem(
                    id: f.id.uuidString,
                    title: f.title,
                    routeId: f.id.uuidString,
                    kind: .filter,
                    downloadCount: f.downloadCount > 0 ? f.downloadCount : f.useCount,
                    categoryHint: f.category.hintColor
                )
            }
        case .saved:
            return profileStore.savedFilterIDs.map { id in
                ProfileGridItem(
                    id: id,
                    title: savedTitle(for: id),
                    routeId: id,
                    kind: .filter,
                    downloadCount: 0,
                    categoryHint: FMColors.Category.cinematic
                )
            }
        case .captures:
            return profileStore.captureIDs.map { id in
                ProfileGridItem(
                    id: id,
                    title: "촬영 \(String(id.prefix(6)))",
                    routeId: id,
                    kind: .capture,
                    downloadCount: 0,
                    categoryHint: FMColors.Category.cinematic
                )
            }
        }
    }

    private func route(for item: ProfileGridItem) -> AppRoute {
        switch item.kind {
        case .filter:
            return .filterDetail(id: item.routeId)
        case .capture:
            return .captureDetail(id: item.routeId)
        }
    }

    private func savedTitle(for id: String) -> String {
        if let uuid = UUID(uuidString: id),
           let filter = store.filters.first(where: { $0.id == uuid }) ?? profileStore.myFilters.first(where: { $0.id == uuid }) {
            return filter.title
        }
        return "저장된 필터"
    }

    private func formattedCount(_ count: Int) -> String {
        switch count {
        case ..<1_000: "\(count)"
        case 1_000..<10_000: String(format: "%.1fK", Double(count) / 1_000)
        default: "\(count / 1_000)K"
        }
    }

    private func shortcutIdentifier(for route: AppRoute) -> String {
        switch route {
        case .editor:
            return "create"
        case .wallet:
            return "wallet"
        case .myFilters:
            return "myFilters"
        case .makerDashboard:
            return "dashboard"
        default:
            return route.title
        }
    }
}

struct CaptureDetailScreen: View {
    let captureID: String

    var body: some View {
        VStack(spacing: Sp.lg) {
            ZStack {
                LinearGradient(
                    colors: [FMColors.Category.cinematic.opacity(0.75), FMColors.Category.mood.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "photo")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
            .accessibilityIdentifier("capture.detail.preview")

            VStack(alignment: .leading, spacing: Sp.xs) {
                Text("촬영 상세")
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
                Text(captureID)
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("촬영 상세")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfileHandleResolverScreen: View {
    let handle: String

    @State private var resolvedUID: String?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let resolvedUID {
                ProfileScreen(otherUid: resolvedUID)
            } else {
                VStack(spacing: Sp.md) {
                    if isLoading {
                        ProgressView()
                            .tint(FMColors.Accent.primary)
                        Text("@\(normalizedHandle)")
                            .font(Font.fmCaption)
                            .foregroundStyle(FMColors.Text.tertiary)
                    } else {
                        FMEmptyState(.emptyProfile(isOwnProfile: false, makerName: displayHandle))
                        if let errorMessage {
                            Text(errorMessage)
                                .font(Font.fmCaption)
                                .foregroundStyle(FMColors.Text.tertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(Sp.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FMColors.Background.bg1.ignoresSafeArea())
            }
        }
        .navigationTitle("메이커 프로필")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: normalizedHandle) { await resolve() }
    }

    private var normalizedHandle: String {
        handle
            .trimmingCharacters(in: CharacterSet(charactersIn: "@").union(.whitespacesAndNewlines))
            .lowercased()
    }

    private var displayHandle: String? {
        normalizedHandle.isEmpty ? nil : "@\(normalizedHandle)"
    }

    @MainActor
    private func resolve() async {
        guard !normalizedHandle.isEmpty else {
            isLoading = false
            errorMessage = "유효하지 않은 프로필 링크입니다."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await Firestore.firestore()
                .collection("handles").document(normalizedHandle)
                .getDocument()
            guard let uid = snapshot.data()?["uid"] as? String, !uid.isEmpty else {
                isLoading = false
                errorMessage = "해당 유저네임의 프로필을 찾을 수 없어요."
                return
            }
            resolvedUID = uid
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "프로필 링크를 확인하지 못했어요: \(error.localizedDescription)"
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
