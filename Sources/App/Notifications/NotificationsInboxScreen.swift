import DesignSystem
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

/// 27 Notifications Inbox — `mockups/screens/27-notifications-inbox.html` 정합.
///
/// 카테고리 segmented chip + 그룹 (새 알림/오늘/이번 주/이전) + 행 variants
/// (좋아요/댓글/다운로드/팔로우/시스템). 미확인 행은 `accent.bg` highlight.
struct NotificationsInboxScreen: View {
    @State private var category: NotificationCategory = .all
    @StateObject private var store = NotificationsInboxStore()
    @State private var followErrorMessage: String?
    @State private var actionErrorMessage: String?
    @State private var isRefreshing = false
    @State private var now = Date()
    // 프로덕션: store.items (Firestore listener) 사용.
    // UI 테스트 (-ui-testing 런치 인자): 기존 mock 데이터로 fallback해 시드 가능 상태 유지. (#30)
    private var items: [NotificationItem] {
        isUITesting ? NotificationItem.mock : store.items
    }

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
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.notificationSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("알림 설정")
                .accessibilityIdentifier("notif.settings")
            }
        }
        .task { store.start() }
        .onDisappear { store.stop() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .alert("팔로우 실패", isPresented: Binding(
            get: { followErrorMessage != nil },
            set: { if !$0 { followErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(followErrorMessage ?? "")
        }
        .alert("알림 처리 실패", isPresented: Binding(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(actionErrorMessage ?? "")
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
                        Text(value.title)
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
        let groups = NotificationItem.group(items: filteredItems, now: now)

        if groups.isEmpty {
            ScrollView {
                emptyState
                    .frame(minHeight: 420)
            }
            .refreshable {
                await refreshNotifications()
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(groups) { group in
                        groupLabel(group.title)
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

                    if store.canLoadMore {
                        FMButton("이전 알림 더 보기", variant: .secondary, size: .md, isLoading: store.isLoadingMore) {
                            Task { await loadMoreNotifications() }
                        }
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.md)
                        .accessibilityIdentifier("notif.loadMore")
                    }
                }
                .padding(.bottom, Sp.xxxl)
            }
            .refreshable {
                await refreshNotifications()
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
            Text("알림이 없어요")
                .fmTypography(.headline)
                .foregroundStyle(FMColors.Text.primary)
            Text("새 알림이 도착하면 여기에 표시됩니다.")
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
                    Text(item.relativeTime(now: now))
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
                Text("팔로우")
                    .fmTypography(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.Text.inverse)
                    .padding(.horizontal, Sp.sm)
                    .frame(height: 28)
                    .background(FMColors.Accent.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("notif.follow.action.\(userID)")

        case .like(let filterID), .review(let filterID), .download(let filterID):
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

    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .fmTypography(.caption)
            .fontWeight(.bold)
            .tracking(0.4)
            .foregroundStyle(FMColors.Text.tertiary)
            .textCase(.uppercase)
    }

    // MARK: - Actions

    private func markRead(_ item: NotificationItem) {
        // (#33) firestoreDocId 가 있으면 store.markRead가 readAt 타임스탬프를 즉시 작성.
        // 다음 listener 도착 시 isUnread=false 자동 반영. mock/UI test 항목은 docId 없음 → no-op.
        if let docId = item.firestoreDocId {
            Task {
                do {
                    try await store.markRead(notificationId: docId)
                } catch {
                    await MainActor.run {
                        actionErrorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func acceptFollow(_ item: NotificationItem) {
        guard case .followRequest(let actorUid) = item.kind else { return }
        Task {
            do {
                try await followBack(actorUid: actorUid)
                await MainActor.run {
                    markRead(item)
                }
            } catch {
                await MainActor.run {
                    followErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadMoreNotifications() async {
        do {
            try await store.loadMore()
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func refreshNotifications() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await store.refresh()
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func followBack(actorUid: String) async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard uid != actorUid else { return }
        let edgeRef = Firestore.firestore()
            .collection("follows").document("\(uid)_\(actorUid)")
        let snapshot = try await edgeRef.getDocument()
        guard !snapshot.exists else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            edgeRef
                .setData([
                    "actorUid": uid,
                    "targetUid": actorUid,
                    "createdAt": FieldValue.serverTimestamp()
                ]) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
        }
    }
}

// MARK: - Model

enum NotificationCategory: String, CaseIterable, Identifiable, Hashable {
    case all
    case likes
    case reviews
    case downloads
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "전체"
        case .likes: "좋아요"
        case .reviews: "리뷰"
        case .downloads: "다운로드"
        case .system: "시스템"
        }
    }

    var identifier: String { rawValue }
}

struct NotificationItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case like(filterID: String)
        case review(filterID: String)
        case download(filterID: String)
        case followRequest(userID: String)
        case system

        var category: NotificationCategory {
            switch self {
            case .like: .likes
            case .review: .reviews
            case .download: .downloads
            case .followRequest: .system
            case .system: .system
            }
        }

        var overlaySymbol: String {
            switch self {
            case .like: "heart.fill"
            case .review: "bubble.left.fill"
            case .download: "arrow.down"
            case .followRequest: "person.fill.badge.plus"
            case .system: "checkmark"
            }
        }

        var overlayTint: (foreground: Color, background: Color) {
            switch self {
            case .like: (FMColors.Semantic.error, FMColors.Semantic.errorBg)
            case .review: (FMColors.Semantic.info, FMColors.Semantic.infoBg)
            case .download: (FMColors.Semantic.success, FMColors.Semantic.successBg)
            case .followRequest: (FMColors.Accent.primary, FMColors.Accent.bg)
            case .system: (FMColors.Accent.primary, FMColors.Accent.bg)
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let body: AttributedSegments
    let createdAt: Date
    var isUnread: Bool
    /// Firestore /users/{uid}/notifications/{docId} ID — markRead 시 사용 (#33).
    /// nil이면 mock/local 항목 (UI 테스트 등).
    var firestoreDocId: String? = nil

    var gradient: [Color] {
        switch kind {
        case .like: [Color(hex: 0xF3DCC4), Color(hex: 0xD4A482)]
        case .review: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)]
        case .download: [Color(hex: 0xB9D2E8), Color(hex: 0x4A6A90)]
        case .followRequest: [Color(hex: 0xF6E2E8), Color(hex: 0xB39EC2)]
        case .system: [FMColors.Accent.bg, FMColors.Accent.bg]
        }
    }

    var thumbGradient: [Color] {
        switch kind {
        case .like: [Color(hex: 0xC79A72), Color(hex: 0x6A4A2C)]
        case .review: [Color(hex: 0x8A9D6A), Color(hex: 0x3D5230)]
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

    func relativeTime(now: Date) -> String {
        let interval = max(0, now.timeIntervalSince(createdAt))
        if interval < 60 { return "방금 전" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        return "\(Int(interval / 86400))일 전"
    }

    func group(now: Date) -> NotificationGroup {
        let interval = max(0, now.timeIntervalSince(createdAt))
        if interval < 3600 { return .fresh }
        if interval < 86400 { return .today }
        if interval < 604_800 { return .week }
        return .earlier
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

    var title: String {
        switch self {
        case .fresh: "새 알림"
        case .today: "오늘"
        case .week: "이번 주"
        case .earlier: "이전"
        }
    }
}

struct NotificationGroupBucket: Identifiable {
    let group: NotificationGroup
    let items: [NotificationItem]
    var id: NotificationGroup { group }
    var title: String { group.title }
}

extension NotificationItem {
    static func group(items: [NotificationItem], now: Date) -> [NotificationGroupBucket] {
        NotificationGroup.allCases.compactMap { group in
            let bucket = items.filter { $0.group(now: now) == group }
            guard !bucket.isEmpty else { return nil }
            return NotificationGroupBucket(group: group, items: bucket)
        }
    }

    static let mock: [NotificationItem] = [
        NotificationItem(
            kind: .like(filterID: "sample-filter"),
            body: AttributedSegments(segments: [
                .strong("민지"),
                .normal(" 외 12명이 "),
                .strong("추천 필터"),
                .normal("에 좋아요를 눌렀습니다")
            ]),
            createdAt: Date(),
            isUnread: true
        ),
        NotificationItem(
            kind: .review(filterID: "sample-filter"),
            body: AttributedSegments(segments: [
                .strong("Alex"),
                .normal("가 "),
                .strong("추천 필터"),
                .normal("에 댓글을 남겼습니다 — \"Mid-tone에 살짝 마젠타가...\"")
            ]),
            createdAt: Date().addingTimeInterval(-300),
            isUnread: true
        ),
        NotificationItem(
            kind: .download(filterID: "sample-filter"),
            body: AttributedSegments(segments: [
                .strong("추천 필터"),
                .normal("이 오늘 "),
                .strong("120회"),
                .normal(" 다운로드되었습니다")
            ]),
            createdAt: Date().addingTimeInterval(-7_200),
            isUnread: false
        ),
        NotificationItem(
            kind: .followRequest(userID: "sarah"),
            body: AttributedSegments(segments: [
                .strong("Sarah"),
                .normal("가 회원님을 팔로우했습니다")
            ]),
            createdAt: Date().addingTimeInterval(-18_000),
            isUnread: false
        ),
        NotificationItem(
            kind: .system,
            body: AttributedSegments(segments: [
                .strong("Amber Café"),
                .normal(" 검수가 통과되었습니다 — 마켓에 공개됨")
            ]),
            createdAt: Date().addingTimeInterval(-172_800),
            isUnread: false
        ),
        NotificationItem(
            kind: .review(filterID: "Honey Glow"),
            body: AttributedSegments(segments: [
                .strong("유나"),
                .normal("가 회원님의 댓글에 답글을 남겼습니다")
            ]),
            createdAt: Date().addingTimeInterval(-259_200),
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
