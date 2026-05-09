import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI
import UserNotifications

/// `/users/{uid}/notifications` Firestore listener.
///
/// `NotificationsInboxScreen` 의 @StateObject로 사용. UI 테스트(-ui-testing)에서는
/// 기존 NotificationItem.mock을 fallback으로 직접 사용 (이 store는 production path).
@MainActor
final class NotificationsInboxStore: ObservableObject {
    @Published private(set) var items: [NotificationItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = false
    @Published private(set) var loadError: String?

    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUid: String?
    private var liveItems: [NotificationItem] = []
    private var pagedItems: [NotificationItem] = []
    private var lastLiveDocument: DocumentSnapshot?
    private let pageSize = 100

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

    func stop() {
        listener?.remove()
        listener = nil
        currentUid = nil
        liveItems = []
        pagedItems = []
        lastLiveDocument = nil
        canLoadMore = false
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
            self.authHandle = nil
        }
    }

    private func attach(uid: String?) {
        listener?.remove()
        listener = nil
        guard let uid else {
            currentUid = nil
            publish(live: [], paged: [])
            return
        }
        currentUid = uid
        isLoading = true
        listener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.loadError = error.localizedDescription
                    return
                }
                let docs = snapshot?.documents ?? []
                self.lastLiveDocument = docs.last
                self.canLoadMore = docs.count == self.pageSize
                self.publish(live: docs.compactMap { Self.decode($0) }, paged: self.pagedItems)
                self.loadError = nil
            }
    }

    func loadMore() async throws {
        guard !isLoadingMore else { return }
        guard let uid = currentUid, let lastLiveDocument, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .start(afterDocument: lastLiveDocument)
            .limit(to: pageSize)
            .getDocuments()
        let decoded = snapshot.documents.compactMap { Self.decode($0) }
        pagedItems.append(contentsOf: decoded)
        canLoadMore = snapshot.documents.count == pageSize
        publish(live: liveItems, paged: pagedItems)
    }

    func refresh() async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = currentUid else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let snapshot = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
            .getDocuments()
        let docs = snapshot.documents
        lastLiveDocument = docs.last
        canLoadMore = docs.count == pageSize
        publish(live: docs.compactMap { Self.decode($0) }, paged: [])
        loadError = nil
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
            createdAt: createdAt,
            isUnread: isUnread,
            firestoreDocId: doc.documentID
        )
    }

    /// 행 탭 시 readAt 타임스탬프 작성.
    func markRead(notificationId: String) async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let wasUnread = items.first { $0.firestoreDocId == notificationId }?.isUnread ?? false
        setNotification(notificationId, isUnread: false)
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                Firestore.firestore()
                .collection("users").document(uid)
                .collection("notifications").document(notificationId)
                .setData(["readAt": FieldValue.serverTimestamp()], merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            setNotification(notificationId, isUnread: wasUnread)
            throw error
        }
    }

    func markAllRead() async throws {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let unreadIds = items.compactMap { item in
            item.isUnread ? item.firestoreDocId : nil
        }
        guard !unreadIds.isEmpty else { return }

        setAllNotificationsRead()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let batch = Firestore.firestore().batch()
                let collection = Firestore.firestore()
                    .collection("users").document(uid)
                    .collection("notifications")
                unreadIds.forEach { id in
                    batch.setData(["readAt": FieldValue.serverTimestamp()], forDocument: collection.document(id), merge: true)
                }
                batch.commit { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            unreadIds.forEach { setNotification($0, isUnread: true) }
            throw error
        }
    }

    private func setNotification(_ notificationId: String, isUnread: Bool) {
        func update(_ list: inout [NotificationItem]) {
            guard let index = list.firstIndex(where: { $0.firestoreDocId == notificationId }) else { return }
            list[index].isUnread = isUnread
        }
        update(&liveItems)
        update(&pagedItems)
        update(&items)
        updateAppBadge()
    }

    private func setAllNotificationsRead() {
        func update(_ list: inout [NotificationItem]) {
            for index in list.indices {
                list[index].isUnread = false
            }
        }
        update(&liveItems)
        update(&pagedItems)
        update(&items)
        updateAppBadge()
    }

    private func publish(live: [NotificationItem], paged: [NotificationItem]) {
        liveItems = live
        pagedItems = paged
        var seen = Set<String>()
        items = (live + paged).filter { item in
            guard let docId = item.firestoreDocId else { return true }
            return seen.insert(docId).inserted
        }
        updateAppBadge()
    }

    private func updateAppBadge() {
        let unreadCount = items.filter(\.isUnread).count
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(unreadCount)
        }
    }
}
