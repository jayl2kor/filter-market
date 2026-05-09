import DesignSystem
import SwiftUI
import UIKit

// MARK: - Local enums

/// 카메라 기본 비율 picker.
enum SettingsAspectRatio: String, CaseIterable, Identifiable, Hashable {
    case square = "1:1"
    case fourFive = "4:5"
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case full = "풀스크린"

    var id: String { rawValue }
}

/// 민감 콘텐츠 필터링 강도.
enum SensitiveFilterLevel: String, CaseIterable, Identifiable, Hashable {
    case off = "끔"
    case soft = "보통"
    case strong = "강함"

    var id: String { rawValue }
}

// MARK: - SettingsScreen

/// 설정 — 10번 화면.
///
/// Phase D3 — `mockups/screens/10-settings.html` 와 정합.
/// 그룹화된 리스트 — 계정 / 카메라 / 알림·콘텐츠 / 정보 / 로그아웃.
/// 라이트 그레이 (`bg/1`) 위에 흰 카드 그룹을 겹침.
struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @EnvironmentObject private var walletStore: WalletStore
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @EnvironmentObject private var cameraStateStore: CameraStateStore

    // 카메라 (#22 — UserDefaults 영속화)
    @AppStorage("settings.cam.defaultAspectRatio") private var defaultAspectRatioRaw: String = SettingsAspectRatio.fourThree.rawValue
    @AppStorage("settings.cam.showGrid") private var showGrid: Bool = true
    @AppStorage("settings.cam.shutterSound") private var shutterSound: Bool = false
    @AppStorage("settings.cam.saveOriginal") private var saveOriginal: Bool = true

    private var defaultAspectRatio: Binding<SettingsAspectRatio> {
        Binding(
            get: { SettingsAspectRatio(rawValue: defaultAspectRatioRaw) ?? .fourThree },
            set: { defaultAspectRatioRaw = $0.rawValue }
        )
    }

    // 알림 상태는 SessionStore.notificationPreferences를 단일 진실원으로 사용.
    @AppStorage("settings.notif.sensitiveFilter") private var sensitiveFilterRaw: String = SensitiveFilterLevel.strong.rawValue

    private var sensitiveFilter: Binding<SensitiveFilterLevel> {
        Binding(
            get: { SensitiveFilterLevel(rawValue: sensitiveFilterRaw) ?? .strong },
            set: { sensitiveFilterRaw = $0.rawValue }
        )
    }

    // 다이얼로그
    @State private var showLogoutAlert = false
    @State private var showLoginRequiredDialog = false
    @State private var navigateToLogin = false

    // 운영 권한 (Firebase ID token의 `role` custom claim — admin/moderator)
    @State private var role: String?

    // 외부 링크 (이용약관 / 개인정보처리방침) — SafariView로 표시.
    @State private var externalURL: ExternalURL?
    @State private var downloadStorageUsageBytes: Int64 = 0

    private var downloadStorageUsageText: String {
        SignedFilterPackageDownloader.formattedCacheUsage(usedBytes: downloadStorageUsageBytes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                profileCard

                section(title: "계정") {
                    gatedNavigationRow(
                        icon: "person.crop.circle",
                        title: "프로필 정보",
                        route: .editProfile
                    )
                    divider
                    gatedNavigationRow(
                        icon: "lock.shield",
                        title: "개인정보 및 보안",
                        route: .dataExport
                    )
                }

                section(title: "카메라 기본값") {
                    aspectRatioRow
                    divider
                    listRow(
                        icon: "squareshape.split.3x3",
                        title: "그리드 표시",
                        accessory: .toggle(binding: $showGrid)
                    ) {}
                    divider
                    listRow(
                        icon: "speaker.wave.2",
                        title: "셔터 사운드",
                        accessory: .toggle(binding: $shutterSound)
                    ) {}
                    divider
                    listRow(
                        icon: "square.on.square",
                        title: "원본 함께 저장",
                        accessory: .toggle(binding: $saveOriginal)
                    ) {}
                }

                section(title: "알림") {
                    gatedNavigationRow(
                        icon: "bell",
                        title: "푸시 알림",
                        accessory: .value(text: sessionStore.notificationPreferences.systemEnabled ? "켬" : "끔", chevron: true),
                        route: .notificationSettings
                    )
                    divider
                    sensitiveFilterRow
                }

                section(title: "권한") {
                    listRow(
                        icon: "switch.2",
                        title: "시스템 권한",
                        accessory: .value(text: "카메라 · 사진 · 알림", chevron: true)
                    ) {
                        openSystemSettings()
                    }
                }

                section(title: "데이터") {
                    gatedNavigationRow(
                        icon: "creditcard",
                        title: "결제 및 구독",
                        accessory: .badge(text: "PRO", chevron: true),
                        route: .wallet
                    )
                    divider
                    navigationRow(
                        icon: "arrow.down.circle",
                        title: "다운로드 관리",
                        accessory: .value(text: downloadStorageUsageText, chevron: true),
                        route: .savedFilters
                    )
                    divider
                    gatedNavigationRow(
                        icon: "person.crop.circle.badge.xmark",
                        title: "차단 사용자",
                        route: .blockList
                    )
                }

                section(title: "정보") {
                    navigationRow(
                        icon: "questionmark.circle",
                        title: "도움말",
                        accessory: .chevron,
                        route: .helpCenter
                    )
                    divider
                    listRow(
                        icon: "doc.text",
                        title: "이용약관",
                        accessory: .chevron
                    ) {
                        externalURL = ExternalURL(value: MooditPolicyURL.terms)
                    }
                    divider
                    listRow(
                        icon: "hand.raised",
                        title: "개인정보처리방침",
                        accessory: .chevron
                    ) {
                        externalURL = ExternalURL(value: MooditPolicyURL.privacy)
                    }
                    divider
                    listRow(
                        icon: "info.circle",
                        title: "버전",
                        accessory: .value(text: "1.1.0 (build 144)", chevron: false)
                    ) {}
                }

                if hasAdminAccess {
                    section(title: "운영") {
                        navigationRow(
                            icon: "shield.lefthalf.filled",
                            title: "모더레이션 큐",
                            accessory: .chevron,
                            route: .modQueue
                        )
                        divider
                        navigationRow(
                            icon: "link",
                            title: "공유 링크 테스트",
                            accessory: .chevron,
                            route: .universalLinkLanding
                        )
                    }
                    .accessibilityIdentifier("settings.admin.section")
                }

                if sessionStore.isAuthenticated {
                    section(title: "위험 영역") {
                        listRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "로그아웃",
                            tone: .secondaryAction,
                            accessory: .chevron
                        ) {
                            showLogoutAlert = true
                        }
                        divider
                        navigationRow(
                            icon: "trash",
                            title: "계정 삭제",
                            tone: .destructiveAction,
                            accessory: .chevron,
                            route: .accountDeletion
                        )
                    }
                    .padding(.top, Sp.md)
                } else {
                    section(title: "로그인") {
                        NavigationLink(value: AppRoute.login) {
                            HStack(spacing: Sp.sm) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: IconSize.md, weight: .regular))
                                    .foregroundStyle(FMColors.Accent.primary)
                                    .frame(width: 28, height: 28)
                                Text("로그인하기")
                                    .fmTypography(.body)
                                    .foregroundStyle(FMColors.Accent.primary)
                                Spacer(minLength: Sp.xs)
                                chevron
                            }
                            .padding(.horizontal, Sp.md)
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.login")
                    }
                    .padding(.top, Sp.md)
                }

                footerNote
            }
            .padding(.horizontal, Sp.md)
            .padding(.top, Sp.md)
            .padding(.bottom, Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FMColors.Background.bg1, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToLogin) {
            LoginScreen(onAuthenticated: {
                navigateToLogin = false
            }, onContinueAsGuest: {
                navigateToLogin = false
            })
        }
        .task {
            refreshDownloadStorageUsage()
            await refreshRoleClaim()
        }
        .onReceive(filterLibraryStore.$downloadedFilterIDs) { _ in
            refreshDownloadStorageUsage()
        }
        .sheet(item: $externalURL) { external in
            SafariView(url: external.value)
        }
        .alert("로그인이 필요해요", isPresented: $showLoginRequiredDialog) {
            Button("취소", role: .cancel) {}
            Button("로그인하기") {
                navigateToLogin = true
            }
        } message: {
            Text("이 기능을 사용하려면 먼저 로그인해주세요.")
        }
        .fmDestructiveAlert(
            "로그아웃 하시겠어요?",
            message: "다시 로그인하면 다운로드 받은 필터를 그대로 이용할 수 있어요.",
            destructiveTitle: "로그아웃",
            isPresented: $showLogoutAlert
        ) {
            performSignOut()
        }
    }

    /// `role` custom claim ∈ {"admin", "moderator"} 인지 검사.
    /// 클라이언트 측 visibility 게이트일 뿐, 보안 경계는 Firestore Rules /
    /// Cloud Functions의 requireAdmin / requireModerator에서.
    private var hasAdminAccess: Bool {
        role == "admin" || role == "moderator"
    }

    /// Settings 진입 시마다 ID token을 강제 새로고침해 최신 role claim을 가져온다.
    /// `tools/bootstrap-admin.mjs` 또는 `setRole` Cloud Function이 변경한 역할이
    /// 다음 진입에서 즉시 반영되도록 함 (기본 캐시는 ~1시간).
    private func refreshRoleClaim() async {
        do {
            role = try await FirebaseSideEffects.refreshedRoleClaim()
        } catch {
            #if DEBUG
            print("[Settings] Failed to refresh role claim: \(error.localizedDescription)")
            #endif
            role = nil
        }
    }

    private func refreshDownloadStorageUsage() {
        downloadStorageUsageBytes = SignedFilterPackageDownloader.packageCacheUsageBytes()
    }

    /// Firebase Auth 세션 종료. SessionStore auth listener owns authenticated state.
    /// Firebase가 미설정인 경우(GoogleService-Info.plist 누락 시뮬레이터 등)에도
    /// store의 로컬 fallback 상태를 정리한다.
    private func performSignOut() {
        // (#48) signOut 흐름 race 제거 — listener teardown 먼저, 그 사이 stale snapshot 노출 방지.
        // 1. 현재 사용자의 디바이스 토큰 doc 삭제 (#23) — Auth.signOut() 전에 uid를 잡아야 함.
        if let uid = FirebaseSideEffects.currentUID {
            PushRegistration.shared.unregisterCurrentDevice(uid: uid)
        }
        // 2. Auth.signOut() — store의 authStateDidChangeListener가 attachWalletListeners(uid: nil) 호출 →
        //    모든 listener teardown + resetUserScopedState 자동 진행. 이중 cleanup race 제거.
        if FirebaseSideEffects.isConfigured {
            do {
                try FirebaseSideEffects.signOut()
            } catch {
                #if DEBUG
                print("[Settings] signOut failed: \(error.localizedDescription)")
                #endif
                // signOut 실패 시 fallback으로 명시 reset.
                resetUserScopedState()
            }
        } else {
            // Firebase 미구성 환경 (시뮬레이터 등) — 명시 reset.
            resetUserScopedState()
        }
        sessionStore.setLocalAuthenticationFallback(false)
        dismiss()
    }

    private func resetUserScopedState() {
        walletStore.reset()
        filterLibraryStore.resetUserScopedState()
        sessionStore.resetUserScopedState()
        cameraStateStore.resetUserScopedState()
        editorDraftStore.resetUserScopedState()
        sessionStore.markProfileUnloaded()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    // MARK: - Header (me) card

    private var profileCard: some View {
        HStack(spacing: Sp.md) {
            FMAvatar(
                url: sessionStore.isAuthenticated ? sessionStore.editableProfile.avatarURL : nil,
                size: .md,
                fallback: sessionStore.isAuthenticated ? sessionStore.editableProfile.initials : "G"
            )

            VStack(alignment: .leading, spacing: Sp.xxs) {
                Text(profileDisplayTitle)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)

                if sessionStore.isAuthenticated, !sessionStore.editableProfile.handle.isEmpty {
                    Text(sessionStore.editableProfile.displayHandle)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                } else {
                    Text(sessionStore.isAuthenticated ? "유저네임을 설정하세요" : "로그인하면 프로필과 구매 내역이 동기화돼요")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
            }

            Spacer(minLength: 0)

            if sessionStore.isAuthenticated {
                NavigationLink(value: AppRoute.editProfile) {
                    Text("편집")
                        .fmTypography(.subhead)
                        .fontWeight(.medium)
                        .padding(.horizontal, Sp.sm)
                        .padding(.vertical, 6)
                        .foregroundStyle(FMColors.Text.secondary)
                        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                        .overlay {
                            RoundedRectangle(cornerRadius: R.md)
                                .strokeBorder(FMColors.Border.default, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("프로필 편집")
            } else {
                NavigationLink(value: AppRoute.login) {
                    Text("로그인")
                        .fmTypography(.subhead)
                        .fontWeight(.medium)
                        .padding(.horizontal, Sp.sm)
                        .padding(.vertical, 6)
                        .foregroundStyle(FMColors.Accent.primary)
                        .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.md))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("로그인하기")
            }
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .overlay {
            RoundedRectangle(cornerRadius: R.lg)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .shadow(color: FMColors.Border.subtle.opacity(0.45), radius: 1, x: 0, y: 1)
    }

    private var profileDisplayTitle: String {
        guard sessionStore.isAuthenticated else { return "게스트" }
        return sessionStore.editableProfile.displayName.isEmpty
            ? sessionStore.editableProfile.handle.isEmpty ? "사용자" : sessionStore.editableProfile.handle
            : sessionStore.editableProfile.displayName
    }

    // MARK: - Section

    @ViewBuilder
    private func section<Rows: View>(
        title: String?,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            if let title {
                Text(title)
                    .fmTypography(.caption)
                    .fontWeight(.semibold)
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .padding(.leading, Sp.xs)
            }

            VStack(spacing: 0) {
                rows()
            }
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
        }
    }

    // MARK: - Row

    /// 우측 액세서리 종류.
    private enum RowAccessory {
        case none
        case chevron
        case toggle(binding: Binding<Bool>)
        case value(text: String, chevron: Bool)
        case badge(text: String, chevron: Bool)
    }

    private enum RowTone {
        case normal
        case secondaryAction
        case destructiveAction

        var iconColor: Color {
            switch self {
            case .normal:
                FMColors.Text.primary
            case .secondaryAction:
                FMColors.Text.secondary
            case .destructiveAction:
                FMColors.Semantic.error
            }
        }

        var textColor: Color {
            switch self {
            case .normal:
                FMColors.Text.primary
            case .secondaryAction:
                FMColors.Text.secondary
            case .destructiveAction:
                FMColors.Semantic.error
            }
        }

        var backgroundColor: Color {
            switch self {
            case .normal, .secondaryAction:
                Color.clear
            case .destructiveAction:
                FMColors.Semantic.errorBg.opacity(0.65)
            }
        }
    }

    @ViewBuilder
    private func listRow(
        icon: String,
        title: String,
        tone: RowTone = .normal,
        accessory: RowAccessory,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Sp.sm) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.md, weight: .regular))
                    .foregroundStyle(tone.iconColor)
                    .frame(width: 28, height: 28)

                Text(title)
                    .fmTypography(.body)
                    .foregroundStyle(tone.textColor)

                Spacer(minLength: Sp.xs)

                accessoryView(accessory)
            }
            .padding(.horizontal, Sp.md)
            .frame(minHeight: 52)
            .background(tone.backgroundColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("settings.row.\(title)")
    }

    @ViewBuilder
    private func navigationRow(
        icon: String,
        title: String,
        tone: RowTone = .normal,
        accessory: RowAccessory,
        route: AppRoute
    ) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Sp.sm) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.md, weight: .regular))
                    .foregroundStyle(tone.iconColor)
                    .frame(width: 28, height: 28)

                Text(title)
                    .fmTypography(.body)
                    .foregroundStyle(tone.textColor)

                Spacer(minLength: Sp.xs)

                accessoryView(accessory)
            }
            .padding(.horizontal, Sp.md)
            .frame(minHeight: 52)
            .background(tone.backgroundColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("settings.nav.\(route.title)")
    }

    @ViewBuilder
    private func gatedNavigationRow(
        icon: String,
        title: String,
        tone: RowTone = .normal,
        accessory: RowAccessory = .chevron,
        route: AppRoute
    ) -> some View {
        if sessionStore.isAuthenticated {
            navigationRow(icon: icon, title: title, tone: tone, accessory: accessory, route: route)
        } else {
            Button {
                showLoginRequiredDialog = true
            } label: {
                HStack(spacing: Sp.sm) {
                    Image(systemName: icon)
                        .font(.system(size: IconSize.md, weight: .regular))
                        .foregroundStyle(FMColors.Text.tertiary)
                        .frame(width: 28, height: 28)

                    Text(title)
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.tertiary)

                    Spacer(minLength: Sp.xs)

                    Image(systemName: "lock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FMColors.Text.tertiary)
                        .accessibilityLabel("로그인 필요")
                }
                .padding(.horizontal, Sp.md)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), 로그인 필요")
            .accessibilityIdentifier("settings.locked.\(route.title)")
        }
    }

    @ViewBuilder
    private func accessoryView(_ accessory: RowAccessory) -> some View {
        switch accessory {
        case .none:
            EmptyView()

        case .chevron:
            chevron

        case .toggle(let binding):
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(FMColors.Accent.primary)

        case .value(let text, let chevron):
            HStack(spacing: Sp.xs) {
                Text(text)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.tertiary)
                if chevron {
                    self.chevron
                }
            }

        case .badge(let text, let chevron):
            HStack(spacing: Sp.xs) {
                Text(text)
                    .fmTypography(.caption)
                    .fontWeight(.bold)
                    .tracking(0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(FMColors.Accent.primary)
                    .padding(.horizontal, Sp.xs)
                    .padding(.vertical, 2)
                    .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.sm))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.sm)
                            .strokeBorder(FMColors.Accent.primary.opacity(0.25), lineWidth: 1)
                    }
                if chevron {
                    self.chevron
                }
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FMColors.Text.tertiary)
    }

    private var divider: some View {
        Rectangle()
            .fill(FMColors.Border.subtle)
            .frame(height: 1)
            .padding(.leading, Sp.md + 28 + Sp.sm)
    }

    // MARK: - Specialised rows

    private var aspectRatioRow: some View {
        HStack(spacing: Sp.sm) {
            Image(systemName: "camera")
                .font(.system(size: IconSize.md, weight: .regular))
                .foregroundStyle(FMColors.Text.primary)
                .frame(width: 28, height: 28)

            Text("기본 비율")
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.primary)

            Spacer(minLength: Sp.xs)

            Picker("기본 비율", selection: defaultAspectRatio) {
                ForEach(SettingsAspectRatio.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(FMColors.Text.tertiary)
        }
        .padding(.horizontal, Sp.md)
        .frame(minHeight: 52)
        .accessibilityLabel("기본 비율, 현재 \(defaultAspectRatio.wrappedValue.rawValue)")
    }

    private var sensitiveFilterRow: some View {
        HStack(spacing: Sp.sm) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: IconSize.md, weight: .regular))
                .foregroundStyle(FMColors.Text.primary)
                .frame(width: 28, height: 28)

            Text("민감한 콘텐츠 필터링")
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.primary)

            Spacer(minLength: Sp.xs)

            Picker("민감 콘텐츠 필터링", selection: sensitiveFilter) {
                ForEach(SensitiveFilterLevel.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(FMColors.Accent.primary)
        }
        .padding(.horizontal, Sp.md)
        .frame(minHeight: 52)
        .accessibilityLabel("민감한 콘텐츠 필터링, 현재 \(sensitiveFilter.wrappedValue.rawValue)")
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("moodit © 2026 · 서울에서 만들었습니다")
            .fmTypography(.footnote)
            .foregroundStyle(FMColors.Text.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, Sp.sm)
    }
}

// MARK: - Preview

#Preview("SettingsScreen — Light") {
    NavigationStack {
        SettingsScreen()
    }
}

#Preview("SettingsScreen — Dark") {
    NavigationStack {
        SettingsScreen()
    }
    .preferredColorScheme(.dark)
}

#Preview("SettingsScreen — XXXLarge") {
    NavigationStack {
        SettingsScreen()
    }
    .dynamicTypeSize(.xxxLarge)
}
