import DesignSystem
import SwiftUI
import UIKit
import UserNotifications

struct NotificationSettingsScreen: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.openURL) private var openURL
    @State private var systemAuthorizationStatus: UNAuthorizationStatus?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "알림 설정",
                    subtitle: "시스템 권한과 앱 안의 알림 카테고리를 함께 관리합니다.",
                    symbol: "bell.badge"
                )

                systemCard
                categoryCard
                quietHoursCard
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshSystemAuthorizationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await refreshSystemAuthorizationStatus()
            }
        }
        .storeErrorToast(
            message: sessionStore.lastSubmitErrorMessage,
            title: "알림 설정 저장 실패"
        ) {
            sessionStore.clearLastSubmitError()
        }
    }

    private var systemCard: some View {
        FMCard {
            HStack(alignment: .top, spacing: Sp.sm) {
                Image(systemName: systemPermissionIcon)
                    .font(.system(size: IconSize.md, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(systemPermissionTitle)
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(systemPermissionDetail)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FMColors.Accent.primary)
                .accessibilityIdentifier("notif.system.open")
            }
        }
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("카테고리")
            FMCard {
                VStack(spacing: 0) {
                    preferenceToggle("소셜", detail: "팔로우, 좋아요, 메이커 활동", isOn: preferenceBinding(\.social))
                    workflowDivider()
                    preferenceToggle("리뷰 알림", detail: "내 필터에 새 리뷰 또는 메이커 답글이 달릴 때", isOn: preferenceBinding(\.reviews))
                    workflowDivider()
                    preferenceToggle("마켓", detail: "추천 필터, 컬렉션 업데이트", isOn: preferenceBinding(\.marketplace))
                    workflowDivider()
                    preferenceToggle("메이커", detail: "업로드한 필터의 검수 완료 알림", isOn: preferenceBinding(\.creator))
                    workflowDivider()
                    preferenceToggle("지갑과 결제", detail: "구매, 환불, 정산 상태", isOn: preferenceBinding(\.wallet))
                    workflowDivider()
                    preferenceToggle("제품 소식", detail: "새 기능과 이벤트", isOn: preferenceBinding(\.product))
                }
            }
            .accessibilityIdentifier("notif.cat.toggle")
        }
    }

    private var quietHoursCard: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("방해 금지 시간")
            FMCard {
                VStack(spacing: 0) {
                    preferenceToggle(
                        "방해 금지 시간 사용",
                        detail: "시스템 알림 외 모두 차단",
                        isOn: preferenceBinding(\.quietHoursEnabled)
                    )
                    .accessibilityIdentifier("notif.quiet.toggle")
                    workflowDivider()
                    quietRow("시작", value: sessionStore.notificationPreferences.quietStart) {
                        sessionStore.setNotificationPreference(
                            \.quietStart,
                            to: nextQuietStart(after: sessionStore.notificationPreferences.quietStart)
                        )
                    }
                    workflowDivider()
                    quietRow("종료", value: sessionStore.notificationPreferences.quietEnd) {
                        sessionStore.setNotificationPreference(
                            \.quietEnd,
                            to: nextQuietEnd(after: sessionStore.notificationPreferences.quietEnd)
                        )
                    }
                }
            }
        }
    }

    private var systemPermissionIcon: String {
        switch systemAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "bell.fill"
        case .denied:
            return "bell.slash"
        case .notDetermined:
            return "bell.badge"
        case nil:
            return "bell"
        @unknown default:
            return "bell"
        }
    }

    private var systemPermissionTitle: String {
        switch systemAuthorizationStatus {
        case .authorized:
            return "시스템 알림 — 허용됨"
        case .provisional, .ephemeral:
            return "시스템 알림 — 임시 허용됨"
        case .denied:
            return "시스템 알림 — 차단됨"
        case .notDetermined:
            return "시스템 알림 — 권한 미결정"
        case nil:
            return "시스템 알림 — 확인 중"
        @unknown default:
            return "시스템 알림 — 확인 필요"
        }
    }

    private var systemPermissionDetail: String {
        switch systemAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "잠금화면, 배지, 소리는 iOS 설정에서 허용되어 있습니다."
        case .denied:
            return "푸시 알림을 받으려면 iOS 설정에서 moodit 알림을 허용해야 합니다."
        case .notDetermined:
            return "아직 iOS 알림 권한을 요청하지 않았습니다."
        case nil:
            return "iOS 알림 권한 상태를 확인하고 있습니다."
        @unknown default:
            return "iOS 설정에서 알림 권한 상태를 확인해 주세요."
        }
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { sessionStore.notificationPreferences[keyPath: keyPath] },
            set: { sessionStore.setNotificationPreference(keyPath, to: $0) }
        )
    }

    private func refreshSystemAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemAuthorizationStatus = settings.authorizationStatus
    }

    private func preferenceToggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                Text(detail)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
        .tint(FMColors.Accent.primary)
        .padding(.vertical, Sp.xs)
    }

    private func quietRow(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                Spacer()
                Text(value)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Accent.primary)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func nextQuietStart(after value: String) -> String {
        switch value {
        case "21:00": "22:00"
        case "22:00": "23:00"
        default: "21:00"
        }
    }

    private func nextQuietEnd(after value: String) -> String {
        switch value {
        case "06:00": "07:00"
        case "07:00": "08:00"
        default: "06:00"
        }
    }
}
