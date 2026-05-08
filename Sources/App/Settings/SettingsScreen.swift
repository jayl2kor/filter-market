import DesignSystem
import FirebaseAuth
import FirebaseCore
import SwiftUI

// MARK: - Local enums

/// 카메라 기본 비율 picker.
enum SettingsAspectRatio: String, CaseIterable, Identifiable, Hashable {
    case square = "1:1"
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

    // 카메라
    @State private var defaultAspectRatio: SettingsAspectRatio = .fourThree
    @State private var showGrid = true
    @State private var shutterSound = false
    @State private var saveOriginal = true

    // 알림
    @State private var pushNotifications = true
    @State private var sensitiveFilter: SensitiveFilterLevel = .strong

    // 다이얼로그
    @State private var showLogoutAlert = false

    // 운영 권한 (Firebase ID token의 `role` custom claim — admin/moderator)
    @State private var role: String?

    // 인증 상태 (placeholder — 후속 Phase 에서 Firebase Auth 통합)
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false

    // 외부 링크 (이용약관 / 개인정보처리방침) — SafariView로 표시.
    @State private var externalURL: ExternalURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                profileCard

                section(title: "계정") {
                    navigationRow(
                        icon: "person.crop.circle",
                        title: "프로필 정보",
                        accessory: .chevron,
                        route: .editProfile
                    )
                    divider
                    navigationRow(
                        icon: "creditcard",
                        title: "결제 및 구독",
                        accessory: .badge(text: "PRO", chevron: true),
                        route: .wallet
                    )
                    divider
                    navigationRow(
                        icon: "lock.shield",
                        title: "개인정보 및 보안",
                        accessory: .chevron,
                        route: .dataExport
                    )
                }

                section(title: "카메라") {
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

                section(title: "알림 및 콘텐츠") {
                    navigationRow(
                        icon: "bell",
                        title: "푸시 알림",
                        accessory: .value(text: pushNotifications ? "켬" : "끔", chevron: true),
                        route: .notificationSettings
                    )
                    divider
                    navigationRow(
                        icon: "arrow.down.circle",
                        title: "다운로드 관리",
                        accessory: .value(text: "42 / 200MB", chevron: true),
                        route: .savedFilters
                    )
                    divider
                    sensitiveFilterRow
                    divider
                    navigationRow(
                        icon: "person.crop.circle.badge.xmark",
                        title: "차단 사용자",
                        accessory: .chevron,
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

                section(title: nil) {
                    listRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "로그아웃",
                        isDestructive: true,
                        accessory: .none
                    ) {
                        showLogoutAlert = true
                    }
                }

                section(title: nil) {
                    navigationRow(
                        icon: "trash",
                        title: "계정 삭제",
                        isDestructive: true,
                        accessory: .chevron,
                        route: .accountDeletion
                    )
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
        .task { await refreshRoleClaim() }
        .sheet(item: $externalURL) { external in
            SafariView(url: external.value)
        }
        .fmDestructiveAlert(
            "로그아웃 하시겠어요?",
            message: "다시 로그인하면 다운로드 받은 필터를 그대로 이용할 수 있어요.",
            destructiveTitle: "로그아웃",
            isPresented: $showLogoutAlert
        ) {
            performSignOut()
        }
        .appRouteDestinations()
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
        guard FirebaseApp.app() != nil, let user = Auth.auth().currentUser else {
            role = nil
            return
        }
        do {
            let result = try await user.getIDTokenResult(forcingRefresh: true)
            role = result.claims["role"] as? String
        } catch {
            #if DEBUG
            print("[Settings] Failed to refresh role claim: \(error.localizedDescription)")
            #endif
            role = nil
        }
    }

    /// Firebase Auth 세션 종료 + AppStorage 인증 플래그 클리어.
    /// Firebase가 미설정인 경우(GoogleService-Info.plist 누락 시뮬레이터 등)에도
    /// 로컬 isAuthenticated만 false로 떨어지도록 안전하게 처리한다.
    private func performSignOut() {
        if FirebaseApp.app() != nil {
            do {
                try Auth.auth().signOut()
            } catch {
                #if DEBUG
                print("[Settings] signOut failed: \(error.localizedDescription)")
                #endif
            }
        }
        isAuthenticated = false
        dismiss()
    }

    // MARK: - Header (me) card

    private var profileCard: some View {
        HStack(spacing: Sp.md) {
            FMAvatar(initials: "JS", size: .md)

            VStack(alignment: .leading, spacing: 2) {
                Text("jisoo.films")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)

                Text("필터 24개 · 팔로워 1.2K")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
            }

            Spacer(minLength: 0)

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
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .overlay {
            RoundedRectangle(cornerRadius: R.lg)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
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
                    .font(.system(size: 11, weight: .semibold))
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

    @ViewBuilder
    private func listRow(
        icon: String,
        title: String,
        isDestructive: Bool = false,
        accessory: RowAccessory,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Sp.sm) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.md, weight: .regular))
                    .foregroundStyle(isDestructive ? FMColors.Semantic.error : FMColors.Text.primary)
                    .frame(width: 28, height: 28)

                Text(title)
                    .fmTypography(.body)
                    .foregroundStyle(isDestructive ? FMColors.Semantic.error : FMColors.Text.primary)

                Spacer(minLength: Sp.xs)

                accessoryView(accessory)
            }
            .padding(.horizontal, Sp.md)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func navigationRow(
        icon: String,
        title: String,
        isDestructive: Bool = false,
        accessory: RowAccessory,
        route: AppRoute
    ) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Sp.sm) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.md, weight: .regular))
                    .foregroundStyle(isDestructive ? FMColors.Semantic.error : FMColors.Text.primary)
                    .frame(width: 28, height: 28)

                Text(title)
                    .fmTypography(.body)
                    .foregroundStyle(isDestructive ? FMColors.Semantic.error : FMColors.Text.primary)

                Spacer(minLength: Sp.xs)

                accessoryView(accessory)
            }
            .padding(.horizontal, Sp.md)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
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
                    .font(.system(size: 10, weight: .bold))
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

            Picker("기본 비율", selection: $defaultAspectRatio) {
                ForEach(SettingsAspectRatio.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(FMColors.Text.tertiary)
        }
        .padding(.horizontal, Sp.md)
        .frame(minHeight: 52)
        .accessibilityLabel("기본 비율, 현재 \(defaultAspectRatio.rawValue)")
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

            Picker("민감 콘텐츠 필터링", selection: $sensitiveFilter) {
                ForEach(SensitiveFilterLevel.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(FMColors.Accent.primary)
        }
        .padding(.horizontal, Sp.md)
        .frame(minHeight: 52)
        .accessibilityLabel("민감한 콘텐츠 필터링, 현재 \(sensitiveFilter.rawValue)")
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
