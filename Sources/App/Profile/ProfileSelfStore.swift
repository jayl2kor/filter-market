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

    private var myFiltersListener: ListenerRegistration?
    private var savedListener: ListenerRegistration?
    private var capturesListener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    func start() {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.attach(uid: user?.uid)
        }
    }

    private func attach(uid: String?) {
        myFiltersListener?.remove()
        savedListener?.remove()
        capturesListener?.remove()
        myFiltersListener = nil
        savedListener = nil
        capturesListener = nil

        guard let uid else {
            myFilters = []
            savedFilterIDs = []
            captureIDs = []
            return
        }
        let db = Firestore.firestore()
        myFiltersListener = db.collection("filters")
            .whereField("authorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let docs = snapshot?.documents ?? []
                self.myFilters = docs.compactMap { FirestoreFilterRepository.decode($0) }
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
    }
}
