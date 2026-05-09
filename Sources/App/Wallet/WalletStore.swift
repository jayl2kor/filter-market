import FirebaseCore
import FirebaseFirestore
import Foundation

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var coinBalance: Int = 0
    @Published private(set) var isProActive: Bool = false
    @Published var lastPaymentErrorMessage: String?

    private var walletListener: ListenerRegistration?
    private var proStatusListener: ListenerRegistration?
    private var optimisticCoinReconcileTask: Task<Void, Never>?
    private var currentUID: String?

    func attach(uid: String?) {
        walletListener?.remove()
        proStatusListener?.remove()
        optimisticCoinReconcileTask?.cancel()
        walletListener = nil
        proStatusListener = nil
        optimisticCoinReconcileTask = nil
        currentUID = uid

        guard let uid else {
            reset()
            return
        }

        let db = Firestore.firestore()
        walletListener = db.collection("users").document(uid)
            .collection("wallet").document("balance")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    let value = (snapshot?.data()?["value"] as? Int) ?? 0
                    self.optimisticCoinReconcileTask?.cancel()
                    self.optimisticCoinReconcileTask = nil
                    self.coinBalance = value
                }
            }
        proStatusListener = db.collection("users").document(uid)
            .collection("proStatus").document("status")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    self.isProActive = (snapshot?.data()?["active"] as? Bool) ?? false
                }
            }
    }

    func reset() {
        coinBalance = 0
        isProActive = false
        lastPaymentErrorMessage = nil
    }

    func markProActiveOptimistically() {
        isProActive = true
    }

    func creditCoinsOptimistically(_ amount: Int) {
        coinBalance = max(0, coinBalance + amount)
        optimisticCoinReconcileTask?.cancel()
        optimisticCoinReconcileTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await self?.forceReloadWalletBalance()
        }
    }

    func reconcileCoinBalance(_ balance: Int) {
        optimisticCoinReconcileTask?.cancel()
        optimisticCoinReconcileTask = nil
        coinBalance = max(0, balance)
    }

    private func forceReloadWalletBalance() async {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard let uid = currentUID, FirebaseApp.app() != nil else { return }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("wallet").document("balance")
                .getDocument()
            let value = (snapshot.data()?["value"] as? Int) ?? 0
            await MainActor.run {
                self.coinBalance = value
                self.optimisticCoinReconcileTask = nil
            }
        } catch {
            await MainActor.run {
                self.lastPaymentErrorMessage = "잔액 동기화 실패: \(error.localizedDescription)"
            }
        }
    }
}
