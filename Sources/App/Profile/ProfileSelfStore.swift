import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
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
    /// (#47) 신규 사용자 doc seed 1회 가드 — listener가 exists==false로 여러 번 fire되어도 중복 호출 방지.
    private var didAttemptSeed: Set<String> = []

    func start() {
        guard authHandle == nil else { return }
        #if DEBUG
        if isUITesting {
            currentUserProfile = .preview
            myFilters = []
            savedFilterIDs = []
            captureIDs = []
            return
        }
        #endif
        guard !Self.isUnitTesting, FirebaseApp.app() != nil else {
            attach(authUser: nil)
            return
        }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.attach(authUser: user)
        }
    }

    func stop() {
        myFiltersListener?.remove()
        savedListener?.remove()
        capturesListener?.remove()
        userDocListener?.remove()
        myFiltersListener = nil
        savedListener = nil
        capturesListener = nil
        userDocListener = nil
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
            self.authHandle = nil
        }
    }

    func refresh() async {
        #if DEBUG
        if isUITesting { return }
        #endif
        guard !Self.isUnitTesting, FirebaseApp.app() != nil else {
            attach(authUser: nil)
            return
        }
        guard let authUser = Auth.auth().currentUser else {
            attach(authUser: nil)
            return
        }

        let uid = authUser.uid
        let db = Firestore.firestore()
        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let filterDocs = try await db.collection("filters")
                .whereField("authorUid", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            let savedDocs = try await db.collection("users").document(uid)
                .collection("savedFilters")
                .order(by: "savedAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            let captureDocs = try await db.collection("users").document(uid)
                .collection("captures")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()

            myFilters = filterDocs.documents.compactMap { FirestoreFilterRepository.decode($0) }
            savedFilterIDs = savedDocs.documents.map(\.documentID)
            captureIDs = captureDocs.documents.map(\.documentID)
            currentUserProfile = Self.buildBaseline(
                authUser: authUser,
                doc: userDoc.data(),
                filterCount: myFilters.count
            )
        } catch {
            // Listener가 계속 살아 있으므로 manual refresh 실패는 기존 화면 상태를 유지한다.
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
                        avatarURL: p.avatarURL,
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
                // (#16) 신규 사용자 — /users/{uid} doc이 없으면 client-side 1회 seed.
                // (#47) didAttemptSeed 가드 — listener가 여러 번 fire되어도 중복 callable 호출 방지.
                if snapshot?.exists == false, !self.didAttemptSeed.contains(authUser.uid) {
                    self.didAttemptSeed.insert(authUser.uid)
                    Task { await self.seedInitialUserDoc(authUser: authUser) }
                }
            }
    }

    /// 신규 사용자가 처음 로그인 시 /users/{uid} 기본 doc을 1회 작성.
    /// updateProfile callable 사용 (서버 측 검증 + 일관 schema, /handles는 별도 setHandle로 보호).
    private func seedInitialUserDoc(authUser: User) async {
        let displayName = authUser.displayName
            ?? authUser.email?.split(separator: "@").first.map(String.init)
            ?? "사용자"
        let region = "asia-northeast3"
        let callable = Functions.functions(region: region).httpsCallable("updateProfile")
        do {
            _ = try await callable.call([
                "displayName": displayName,
                "bio": "",
                "website": "",
                "makerPageVisible": true,
                "photoSharingAllowed": false,
                "avatarVariant": 0
            ] as [String: Any])
        } catch {
            // 실패해도 다음 진입 시 listener가 재시도. 사용자는 Auth-derived 임시 표시.
        }
    }

    /// FirebaseAuth.User + Firestore doc → 표시용 ProfileUser.
    /// Firestore doc이 nil이면 Auth 정보만 사용.
    static func buildBaseline(authUser: User, doc: [String: Any]?, filterCount: Int) -> ProfileUser {
        buildBaseline(
            authDisplayName: authUser.displayName,
            authEmail: authUser.email,
            uid: authUser.uid,
            doc: doc,
            filterCount: filterCount
        )
    }

    static func buildBaseline(
        authDisplayName: String?,
        authEmail: String?,
        uid: String,
        doc: [String: Any]?,
        filterCount: Int
    ) -> ProfileUser {
        let displayName = (doc?["displayName"] as? String)
            ?? authDisplayName
            ?? authEmail?.split(separator: "@").first.map(String.init)
            ?? "사용자"
        let rawHandle = (doc?["handle"] as? String)
            ?? authEmail?.split(separator: "@").first.map(String.init)
            ?? uid.prefix(8).description
        let handle = displayHandle(from: rawHandle)
        let bio = (doc?["bio"] as? String) ?? ""
        let initials = String(displayName.prefix(2)).uppercased()
        let avatarURL = url(from: doc?["avatarURL"]) ?? url(from: doc?["photoURL"])
        let followerCount = (doc?["followerCount"] as? Int) ?? 0
        let followingCount = (doc?["followingCount"] as? Int) ?? 0
        return ProfileUser(
            displayName: displayName,
            handle: handle,
            bio: bio,
            avatarInitials: initials,
            avatarURL: avatarURL,
            filterCount: filterCount,
            followerCount: followerCount,
            followingCount: followingCount,
            isOwnProfile: true
        )
    }

    private static func url(from value: Any?) -> URL? {
        guard let string = value as? String else { return nil }
        return URL(string: string)
    }

    static func displayHandle(from rawValue: String) -> String {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        return normalized.isEmpty ? "@user" : "@\(normalized)"
    }

    private static var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
