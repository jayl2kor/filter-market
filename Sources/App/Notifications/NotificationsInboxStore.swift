import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

/// `/users/{uid}/notifications` Firestore listener.
///
/// `NotificationsInboxScreen` 의 @StateObject로 사용. UI 테스트(-ui-testing)에서는
/// 기존 NotificationItem.mock을 fallback으로 직접 사용 (이 store는 production path).
@MainActor
final class NotificationsInboxStore: ObservableObject {
    @Published private(set) var items: [NotificationItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    func start() {
        guard authHandle == nil else { return }
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.attach(uid: user?.uid)
        }
    }

    private func attach(uid: String?) {
        listener?.remove()
        listener = nil
        guard let uid else {
            items = []
            return
        }
        isLoading = true
        listener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.loadError = error.localizedDescription
                    return
                }
                let docs = snapshot?.documents ?? []
                self.items = docs.compactMap { Self.decode($0) }
                self.loadError = nil
            }
    }

    /// Firestore notification doc → NotificationItem.
    /// Schema:
    ///   kind: "like" | "review" | "download" | "followRequest" | "system"
    ///   filterId: optional
    ///   actorUid / actorName: optional
    ///   filterTitle: optional (denormalized for display)
    ///   message: optional fallback string for system kind
    ///   createdAt: Timestamp
    ///   readAt: Timestamp (optional)
    static func decode(_ doc: DocumentSnapshot) -> NotificationItem? {
        guard let data = doc.data() else { return nil }
        let kindRaw = (data["kind"] as? String) ?? "system"
        let filterId = data["filterId"] as? String
        let actorName = (data["actorName"] as? String) ?? "사용자"
        let filterTitle = data["filterTitle"] as? String
        let message = data["message"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let isUnread = data["readAt"] == nil

        let kind: NotificationItem.Kind
        let body: AttributedSegments
        switch kindRaw {
        case "like":
            kind = .like(filterID: filterId ?? "")
            body = AttributedSegments(segments: [
                .strong(actorName),
                .normal("이 "),
                .strong(filterTitle ?? "필터"),
                .normal("에 좋아요를 눌렀습니다")
            ])
        case "review":
            kind = .review(filterID: filterId ?? "")
            body = AttributedSegments(segments: [
                .strong(actorName),
                .normal("가 "),
                .strong(filterTitle ?? "필터"),
                .normal("에 리뷰를 남겼습니다")
            ])
        case "download":
            kind = .download(filterID: filterId ?? "")
            body = AttributedSegments(segments: [
                .strong(filterTitle ?? "필터"),
                .normal(" 가 다운로드되었습니다")
            ])
        case "followRequest":
            kind = .followRequest(userID: data["actorUid"] as? String ?? "")
            body = AttributedSegments(segments: [
                .strong(actorName),
                .normal("님이 팔로우했습니다")
            ])
        default:
            kind = .system
            body = AttributedSegments(segments: [.normal(message ?? "새 알림")])
        }

        return NotificationItem(
            kind: kind,
            body: body,
            relativeTime: Self.relativeTime(from: createdAt),
            createdGroup: Self.bucket(for: createdAt),
            isUnread: isUnread,
            firestoreDocId: doc.documentID
        )
    }

    /// 행 탭 시 readAt 타임스탬프 작성.
    func markRead(notificationId: String) {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("notifications").document(notificationId)
            .setData(["readAt": FieldValue.serverTimestamp()], merge: true)
    }

    private static func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "방금 전" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        return "\(Int(interval / 86400))일 전"
    }

    private static func bucket(for date: Date) -> NotificationGroup {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return .fresh }
        if interval < 86400 { return .today }
        if interval < 604_800 { return .week }
        return .earlier
    }
}
