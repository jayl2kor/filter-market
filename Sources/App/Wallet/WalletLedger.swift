import FirebaseAuth
import FirebaseFirestore
import Foundation

/// 지갑 거래 내역 한 항목.
public struct WalletLedgerEntry: Identifiable, Sendable, Equatable {
    public enum Kind: String, Sendable {
        case topup     // 충전 (코인 IAP)
        case purchase  // 사용 (필터 구매 / Pro 구독)
        case refund    // 환불
        case bonus     // 프로모션 적립
        case unknown
    }

    public let id: String
    public let kind: Kind
    public let amount: Int             // + 적립, - 차감
    public let relatedItemTitle: String?
    public let createdAt: Date

    public init(
        id: String,
        kind: Kind,
        amount: Int,
        relatedItemTitle: String?,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.relatedItemTitle = relatedItemTitle
        self.createdAt = createdAt
    }
}

/// `/users/{uid}/walletLedger` 컬렉션 Firestore 리스너 관리.
/// `WalletTransactionsScreen` 의 @StateObject 로 사용.
@MainActor
final class WalletLedgerStore: ObservableObject {
    @Published private(set) var entries: [WalletLedgerEntry] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadError: String?

    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private let pageLimit: Int

    init(pageLimit: Int = 50) {
        self.pageLimit = pageLimit
    }

    func start() {
        // (#47) NotificationsInboxStore와 동일 패턴 — auth state 변경 시 listener 자동 재attach.
        guard authHandle == nil else { return }
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.listener?.remove()
            self.listener = nil
            guard let uid = user?.uid else {
                self.entries = []
                return
            }
            self.startListener(uid: uid)
        }
    }

    func refresh() async {
        // Snapshot listener는 실시간이지만 사용자가 명시적으로 새로 받고 싶을 수 있음.
        // 동일 listener를 재시작.
        listener?.remove()
        listener = nil
        guard let uid = Auth.auth().currentUser?.uid else { return }
        startListener(uid: uid)
    }

    private func startListener(uid: String) {
        isLoading = true
        listener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("walletLedger")
            .order(by: "createdAt", descending: true)
            .limit(to: pageLimit)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.loadError = error.localizedDescription
                    return
                }
                let docs = snapshot?.documents ?? []
                self.entries = docs.compactMap { Self.decode($0) }
                self.loadError = nil
            }
    }

    static func decode(_ doc: DocumentSnapshot) -> WalletLedgerEntry? {
        guard let data = doc.data() else { return nil }
        guard let amount = data["amount"] as? Int else { return nil }
        let kindRaw = (data["kind"] as? String) ?? "unknown"
        let kind = WalletLedgerEntry.Kind(rawValue: kindRaw) ?? .unknown
        let relatedItem = data["relatedItemTitle"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return WalletLedgerEntry(
            id: doc.documentID,
            kind: kind,
            amount: amount,
            relatedItemTitle: relatedItem,
            createdAt: createdAt
        )
    }

    /// 인메모리 fake 데이터 주입 (테스트/Preview 용).
    func setEntriesForTesting(_ entries: [WalletLedgerEntry]) {
        self.entries = entries
    }
}
