import FirebaseAuth
import FirebaseFirestore
import Foundation
import Models

/// 내 프로필 화면용 Firestore listener (myFilters / savedFilters / captures).
///
/// `ProfileScreen` 의 @StateObject 로 사용. 로그인 상태에서만 동작 — 비로그인 시 모든 배열은 빈 채로 유지되어 FMEmptyState 노출.
@MainActor
final class ProfileSelfStore: ObservableObject {
    @Published private(set) var myFilters: [Models.Filter] = []
    @Published private(set) var savedFilterIDs: [String] = []
    @Published private(set) var captureIDs: [String] = []
    /// Firebase Auth + /users/{uid} Firestore doc 에서 합성한 사용자 본인 프로필.
    /// 비로그인이면 nil — 호출자(ProfileScreen)는 guestBody로 분기.
    @Published private(set) var currentUserProfile: ProfileUser?

    private var myFiltersListener: ListenerRegistration?
    private var savedListener: ListenerRegistration?
    private var capturesListener: ListenerRegistration?
    private var userDocListener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    func start() {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.attach(authUser: user)
        }
    }

    private func attach(authUser: User?) {
        myFiltersListener?.remove()
        savedListener?.remove()
        capturesListener?.remove()
        userDocListener?.remove()
        myFiltersListener = nil
        savedListener = nil
        capturesListener = nil
        userDocListener = nil

        guard let authUser else {
            myFilters = []
            savedFilterIDs = []
            captureIDs = []
            currentUserProfile = nil
            return
        }
        let uid = authUser.uid
        // 즉시 사용 가능한 정보로 currentUserProfile를 채워두고, /users/{uid} 도착 시 갱신.
        currentUserProfile = Self.buildBaseline(authUser: authUser, doc: nil, filterCount: myFilters.count)

        let db = Firestore.firestore()
        myFiltersListener = db.collection("filters")
            .whereField("authorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let docs = snapshot?.documents ?? []
                self.myFilters = docs.compactMap { FirestoreFilterRepository.decode($0) }
                if var p = self.currentUserProfile {
                    p = ProfileUser(
                        displayName: p.displayName,
                        handle: p.handle,
                        bio: p.bio,
                        avatarInitials: p.avatarInitials,
                        filterCount: self.myFilters.count,
                        followerCount: p.followerCount,
                        followingCount: p.followingCount,
                        isOwnProfile: true
                    )
                    self.currentUserProfile = p
                }
            }
        savedListener = db.collection("users").document(uid)
            .collection("savedFilters")
            .order(by: "savedAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let docs = snapshot?.documents ?? []
                self.savedFilterIDs = docs.map { $0.documentID }
            }
        capturesListener = db.collection("users").document(uid)
            .collection("captures")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let docs = snapshot?.documents ?? []
                self.captureIDs = docs.map { $0.documentID }
            }
        userDocListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let data = snapshot?.data()
                self.currentUserProfile = Self.buildBaseline(
                    authUser: authUser,
                    doc: data,
                    filterCount: self.myFilters.count
                )
            }
    }

    /// FirebaseAuth.User + Firestore doc → 표시용 ProfileUser.
    /// Firestore doc이 nil이면 Auth 정보만 사용.
    static func buildBaseline(authUser: User, doc: [String: Any]?, filterCount: Int) -> ProfileUser {
        let displayName = (doc?["displayName"] as? String)
            ?? authUser.displayName
            ?? authUser.email?.split(separator: "@").first.map(String.init)
            ?? "사용자"
        let handle = (doc?["handle"] as? String)
            ?? "@" + (authUser.email?.split(separator: "@").first.map(String.init) ?? authUser.uid.prefix(8).description)
        let bio = (doc?["bio"] as? String) ?? ""
        let initials = String(displayName.prefix(2)).uppercased()
        let followerCount = (doc?["followerCount"] as? Int) ?? 0
        let followingCount = (doc?["followingCount"] as? Int) ?? 0
        return ProfileUser(
            displayName: displayName,
            handle: handle,
            bio: bio,
            avatarInitials: initials,
            filterCount: filterCount,
            followerCount: followerCount,
            followingCount: followingCount,
            isOwnProfile: true
        )
    }
}
