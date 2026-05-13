import FirebaseFirestore
import Foundation
import Models

/// 다른 사용자(`otherUid`) 프로필 화면용 콘텐츠 store.
///
/// 두 종류 데이터를 동시에 구독:
/// - `filters`: `/filters` 컬렉션 — `authorUid == uid && status == approved` 필터
/// - `reviews`: `/filters/{*}/reviews` collectionGroup — `authorUid == uid` 리뷰 (해당 사용자가 작성한 모든 리뷰)
///
/// `ProfileSelfStore` 와 달리 Auth 와 무관하게 타깃 uid 만 본다. 본인 프로필에서는 사용 안 됨.
@MainActor
final class OtherProfileContentStore: ObservableObject {
    @Published private(set) var filters: [Models.Filter] = []
    @Published private(set) var reviews: [OtherProfileReviewItem] = []
    @Published private(set) var filtersState: LoadState<Void> = .idle
    @Published private(set) var reviewsState: LoadState<Void> = .idle

    private var filtersListener: ListenerRegistration?
    private var reviewsListener: ListenerRegistration?
    private var currentUid: String?

    // deinit 미사용 — `ProfileSelfStore` 와 동일하게 호스팅 뷰의 `.onDisappear` 에서
    // `stop()` 을 명시 호출. (Swift 6 strict concurrency 에서 @MainActor 격리 프로퍼티는
    // nonisolated deinit 에서 접근 불가)

    /// 타깃 uid 로 listener 부착. 이미 같은 uid 가 살아 있으면 noop, 다른 uid 면 정리 후 재부착.
    func start(uid: String) {
        guard !uid.isEmpty else { return }
        if currentUid == uid, filtersListener != nil { return }
        stop()
        currentUid = uid
        attachFiltersListener(uid: uid)
        attachReviewsListener(uid: uid)
    }

    func stop() {
        filtersListener?.remove()
        reviewsListener?.remove()
        filtersListener = nil
        reviewsListener = nil
        filters = []
        reviews = []
        filtersState = .idle
        reviewsState = .idle
        currentUid = nil
    }

    /// Pull-to-refresh 강제 재load — 현재 listener 를 끊고 같은 uid 로 재부착.
    func refresh() {
        guard let uid = currentUid else { return }
        let saved = uid
        stop()
        start(uid: saved)
    }

    // MARK: - Listeners

    private func attachFiltersListener(uid: String) {
        filtersState = .loading
        let db = FirebaseSideEffects.firestore()
        filtersListener = db.collection("filters")
            .whereField("authorUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "approved")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.filtersState = .failed(FriendlyError(
                            message: FirestoreErrorMapper.friendlyMessage(for: error)
                        ))
                        return
                    }
                    let docs = snapshot?.documents ?? []
                    self.filters = docs.compactMap { FirestoreFilterRepository.decode($0) }
                    self.filtersState = .loaded(())
                }
            }
    }

    private func attachReviewsListener(uid: String) {
        reviewsState = .loading
        let db = FirebaseSideEffects.firestore()
        reviewsListener = db.collectionGroup("reviews")
            .whereField("authorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.reviewsState = .failed(FriendlyError(
                            message: FirestoreErrorMapper.friendlyMessage(for: error)
                        ))
                        return
                    }
                    let docs = snapshot?.documents ?? []
                    self.reviews = docs.compactMap { OtherProfileReviewItem.decode($0) }
                    self.reviewsState = .loaded(())
                }
            }
    }
}

// MARK: - OtherProfileReviewItem

struct OtherProfileReviewItem: Identifiable, Sendable, Hashable {
    let id: String          // "{filterId}_{authorUid}" — 고유성 보장
    let filterId: String
    let stars: Int
    let body: String
    let createdAt: Date
    let photoURL: URL?
    let helpfulCount: Int

    static func decode(_ doc: QueryDocumentSnapshot) -> OtherProfileReviewItem? {
        let data = doc.data()
        let filterId = (data["filterId"] as? String) ?? doc.reference.parent.parent?.documentID ?? ""
        guard !filterId.isEmpty else { return nil }
        let stars = (data["stars"] as? Int) ?? (data["rating"] as? Int) ?? 0
        let body = (data["body"] as? String) ?? ""
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let helpful = (data["helpfulCount"] as? Int) ?? 0
        let photo = (data["photoUrl"] as? String).flatMap(URL.init(string:))
            ?? (data["imageURL"] as? String).flatMap(URL.init(string:))
            ?? (data["imageUrl"] as? String).flatMap(URL.init(string:))
        return OtherProfileReviewItem(
            id: "\(filterId)_\(doc.documentID)",
            filterId: filterId,
            stars: stars,
            body: body,
            createdAt: createdAt,
            photoURL: photo,
            helpfulCount: helpful
        )
    }

    /// "방금 전" / "N분" / "N시간" / "N일" — SocialDiscoveryScreens 의 동일 로직 채택.
    var elapsedLabel: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "방금 전" }
        if interval < 3600 { return "\(Int(interval / 60))분" }
        if interval < 86400 { return "\(Int(interval / 3600))시간" }
        return "\(Int(interval / 86400))일"
    }
}
