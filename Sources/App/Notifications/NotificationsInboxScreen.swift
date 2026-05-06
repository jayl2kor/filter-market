import DesignSystem
import SwiftUI

/// 27 Notifications Inbox — `mockups/screens/27-notifications-inbox.html` 정합.
///
/// 카테고리 segmented chip + 그룹 (새 알림/오늘/이번 주/이전) + 행 variants
/// (좋아요/댓글/다운로드/팔로우/시스템). 미확인 행은 `accent.bg` highlight.
struct NotificationsInboxScreen: View {
    @State private var category: NotificationCategory = .all
    @State private var items: [NotificationItem] = NotificationItem.mock

    var body: some View {
        VStack(spacing: 0) {
            categoryStrip
                .background(FMColors.Background.bg1)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(FMColors.Border.subtle)
                        .frame(height: 1)
                }

            content
        }
        .background(FMColors.Background.bg1)
        .navigationTitle(Text("notifications.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.notificationSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text("notifications.settings.title"))
                .accessibilityIdentifier("notif.settings")
            }
        }
    }

    // MARK: - Category strip

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.xs) {
                ForEach(NotificationCategory.allCases) { value in
                    let isActive = category == value
                    Button {
                        FMHaptic.selection.play()
                        category = value
                    } label: {
                        Text(value.localizedKey)
                            .fmTypography(.subhead)
                            .foregroundStyle(isActive ? FMColors.Accent.primary : FMColors.Text.secondary)
                            .padding(.horizontal, Sp.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(isActive ? FMColors.Accent.bg : FMColors.Background.bg2)
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        isActive ? FMColors.Accent.primary : FMColors.Border.subtle,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("notif.cat.\(value.identifier)")
                }
            }
            .padding(.horizontal, Sp.md)
            .padding(.vertical, Sp.sm)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let groups = NotificationItem.group(items: filteredItems)

        if groups.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(groups) { group in
                        groupLabel(group.localizedKey)
                            .padding(.horizontal, Sp.md)
                            .padding(.top, Sp.md)
                            .padding(.bottom, Sp.xs)

                        ForEach(group.items) { item in
                            row(item)
                            if item.id != group.items.last?.id {
                                Rectangle()
                                    .fill(FMColors.Border.subtle)
                                    .frame(height: 1)
                                    .padding(.leading, Sp.md + 40 + Sp.sm)
                            }
                        }
                    }
                }
                .padding(.bottom, Sp.xxxl)
            }
        }
    }

    private var filteredItems: [NotificationItem] {
        switch category {
        case .all: items
        default: items.filter { $0.kind.category == category }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Sp.sm) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(FMColors.Text.tertiary)
            Text("notifications.empty.title")
                .fmTypography(.headline)
                .foregroundStyle(FMColors.Text.primary)
            Text("notifications.empty.body")
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Sp.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.Background.bg1)
    }

    // MARK: - Row

    private func row(_ item: NotificationItem) -> some View {
        Button {
            FMHaptic.light.play()
            markRead(item)
        } label: {
            HStack(alignment: .top, spacing: Sp.sm) {
                avatar(item)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    item.attributedText
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.relativeTime)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailing(item)
            }
            .padding(.horizontal, Sp.md)
            .padding(.vertical, Sp.sm)
            .frame(minHeight: 64)
            .background(item.isUnread ? FMColors.Accent.bg : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("notif.tap")
    }

    private func avatar(_ item: NotificationItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            avatarFill(item)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            iconOverlay(item)
        }
    }

    @ViewBuilder
    private func avatarFill(_ item: NotificationItem) -> some View {
        switch item.kind {
        case .system:
            Circle()
                .fill(FMColors.Accent.bg)
                .overlay {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FMColors.Accent.primary)
                }
        default:
            LinearGradient(
                colors: item.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func iconOverlay(_ item: NotificationItem) -> some View {
        let symbol = item.kind.overlaySymbol
        let tint = item.kind.overlayTint
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint.foreground)
            .frame(width: 18, height: 18)
            .background(tint.background, in: Circle())
            .overlay {
                Circle().strokeBorder(FMColors.Background.bg1, lineWidth: 2)
            }
            .offset(x: 4, y: 4)
    }

    @ViewBuilder
    private func trailing(_ item: NotificationItem) -> some View {
        switch item.kind {
        case .followRequest(let userID):
            Button {
                FMHaptic.success.play()
                acceptFollow(item)
            } label: {
                Text("profile.follow")
                    .fmTypography(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.Text.inverse)
                    .padding(.horizontal, Sp.sm)
                    .frame(height: 28)
                    .background(FMColors.Accent.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("notif.follow.action.\(userID)")

        case .like(let filterID), .comment(let filterID), .download(let filterID):
            NavigationLink(value: AppRoute.filterDetail(id: filterID)) {
                thumb(item)
            }
            .buttonStyle(.plain)

        case .system:
            EmptyView()
        }
    }

    private func thumb(_ item: NotificationItem) -> some View {
        RoundedRectangle(cornerRadius: R.sm)
            .fill(
                LinearGradient(
                    colors: item.thumbGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 50)
            .overlay {
                RoundedRectangle(cornerRadius: R.sm)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
    }

    private func groupLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .fmTypography(.caption)
            .fontWeight(.bold)
            .tracking(0.4)
            .foregroundStyle(FMColors.Text.tertiary)
            .textCase(.uppercase)
    }

    // MARK: - Actions

    private func markRead(_ item: NotificationItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isUnread = false
    }

    private func acceptFollow(_ item: NotificationItem) {
        markRead(item)
    }
}

// MARK: - Model

enum NotificationCategory: String, CaseIterable, Identifiable, Hashable {
    case all
    case likes
    case comments
    case downloads
    case system

    var id: String { rawValue }

    /// `Localizable.xcstrings` 의 카테고리 키.
    var localizedKey: LocalizedStringKey {
        switch self {
        case .all: "notifications.category.all"
        case .likes: "notifications.category.likes"
        case .comments: "notifications.category.comments"
        case .downloads: "notifications.category.downloads"
        case .system: "notifications.category.system"
        }
    }

    var identifier: String { rawValue }
}

struct NotificationItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case like(filterID: String)
        case comment(filterID: String)
        case download(filterID: String)
        case followRequest(userID: String)
        case system

        var category: NotificationCategory {
            switch self {
            case .like: .likes
            case .comment: .comments
            case .download: .downloads
            case .followRequest: .system
            case .system: .system
            }
        }

        var overlaySymbol: String {
            switch self {
            case .like: "heart.fill"
            case .comment: "bubble.left.fill"
            case .download: "arrow.down"
            case .followRequest: "person.fill.badge.plus"
            case .system: "checkmark"
            }
        }

        var overlayTint: (foreground: Color, background: Color) {
            switch self {
            case .like: (FMColors.Semantic.error, FMColors.Semantic.errorBg)
            case .comment: (FMColors.Semantic.info, FMColors.Semantic.infoBg)
            case .download: (FMColors.Semantic.success, FMColors.Semantic.successBg)
            case .followRequest: (FMColors.Accent.primary, FMColors.Accent.bg)
            case .system: (FMColors.Accent.primary, FMColors.Accent.bg)
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let body: AttributedSegments
    let relativeTime: String
    let createdGroup: NotificationGroup
    var isUnread: Bool

    var gradient: [Color] {
        switch kind {
        case .like: [Color(hex: 0xF3DCC4), Color(hex: 0xD4A482)]
        case .comment: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)]
        case .download: [Color(hex: 0xB9D2E8), Color(hex: 0x4A6A90)]
        case .followRequest: [Color(hex: 0xF6E2E8), Color(hex: 0xB39EC2)]
        case .system: [FMColors.Accent.bg, FMColors.Accent.bg]
        }
    }

    var thumbGradient: [Color] {
        switch kind {
        case .like: [Color(hex: 0xC79A72), Color(hex: 0x6A4A2C)]
        case .comment: [Color(hex: 0x8A9D6A), Color(hex: 0x3D5230)]
        case .download: [Color(hex: 0x8AA8C6), Color(hex: 0x3D547A)]
        default: [Color(hex: 0xC8C5BE), Color(hex: 0x8A8782)]
        }
    }

    @MainActor
    var attributedText: Text {
        body.segments.reduce(Text("")) { acc, segment in
            switch segment {
            case .strong(let value):
                acc + Text(value).fontWeight(.bold)
            case .normal(let value):
                acc + Text(value)
            }
        }
    }
}

struct AttributedSegments: Hashable {
    enum Segment: Hashable {
        case normal(String)
        case strong(String)
    }

    let segments: [Segment]
}

enum NotificationGroup: String, CaseIterable, Hashable {
    case fresh
    case today
    case week
    case earlier

    /// `Localizable.xcstrings` 의 그룹 헤더 키.
    var localizedKey: LocalizedStringKey {
        switch self {
        case .fresh: "notifications.group.fresh"
        case .today: "notifications.group.today"
        case .week: "notifications.group.week"
        case .earlier: "notifications.group.earlier"
        }
    }
}

struct NotificationGroupBucket: Identifiable {
    let group: NotificationGroup
    let items: [NotificationItem]
    var id: NotificationGroup { group }
    var localizedKey: LocalizedStringKey { group.localizedKey }
}

extension NotificationItem {
    static func group(items: [NotificationItem]) -> [NotificationGroupBucket] {
        NotificationGroup.allCases.compactMap { group in
            let bucket = items.filter { $0.createdGroup == group }
            guard !bucket.isEmpty else { return nil }
            return NotificationGroupBucket(group: group, items: bucket)
        }
    }

    static let mock: [NotificationItem] = [
        NotificationItem(
            kind: .like(filterID: "Sunset 1973"),
            body: AttributedSegments(segments: [
                .strong("민지"),
                .normal(" 외 12명이 "),
                .strong("Sunset 1973"),
                .normal("에 좋아요를 눌렀습니다")
            ]),
            relativeTime: "방금 전",
            createdGroup: .fresh,
            isUnread: true
        ),
        NotificationItem(
            kind: .comment(filterID: "Sunset 1973"),
            body: AttributedSegments(segments: [
                .strong("Alex"),
                .normal("가 "),
                .strong("Sunset 1973"),
                .normal("에 댓글을 남겼습니다 — \"Mid-tone에 살짝 마젠타가...\"")
            ]),
            relativeTime: "5분 전",
            createdGroup: .fresh,
            isUnread: true
        ),
        NotificationItem(
            kind: .download(filterID: "Sunset 1973"),
            body: AttributedSegments(segments: [
                .strong("Sunset 1973"),
                .normal("이 오늘 "),
                .strong("120회"),
                .normal(" 다운로드되었습니다")
            ]),
            relativeTime: "2시간 전",
            createdGroup: .today,
            isUnread: false
        ),
        NotificationItem(
            kind: .followRequest(userID: "sarah"),
            body: AttributedSegments(segments: [
                .strong("Sarah"),
                .normal("가 회원님을 팔로우했습니다")
            ]),
            relativeTime: "5시간 전",
            createdGroup: .today,
            isUnread: false
        ),
        NotificationItem(
            kind: .system,
            body: AttributedSegments(segments: [
                .strong("Amber Café"),
                .normal(" 검수가 통과되었습니다 — 마켓에 공개됨")
            ]),
            relativeTime: "2일 전",
            createdGroup: .week,
            isUnread: false
        ),
        NotificationItem(
            kind: .comment(filterID: "Honey Glow"),
            body: AttributedSegments(segments: [
                .strong("유나"),
                .normal("가 회원님의 댓글에 답글을 남겼습니다")
            ]),
            relativeTime: "3일 전",
            createdGroup: .week,
            isUnread: false
        )
    ]
}

// MARK: - Preview

#Preview("Notifications inbox") {
    NavigationStack {
        NotificationsInboxScreen()
            .environmentObject(MooditStore())
    }
}

#Preview("Notifications inbox — Dark") {
    NavigationStack {
        NotificationsInboxScreen()
            .environmentObject(MooditStore())
    }
    .preferredColorScheme(.dark)
}
