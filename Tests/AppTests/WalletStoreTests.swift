import Testing
@testable import moodit

@MainActor
@Suite("Wallet store")
struct WalletStoreTests {
    @Test("optimistic coin credits clamp at zero and reconcile to server balance")
    func coinOptimismAndReconcile() {
        let store = WalletStore()

        store.creditCoinsOptimistically(500)
        #expect(store.coinBalance == 500)

        store.creditCoinsOptimistically(-700)
        #expect(store.coinBalance == 0)

        store.reconcileCoinBalance(320)
        #expect(store.coinBalance == 320)
    }

    @Test("pro optimism and reset clear user scoped wallet state")
    func proOptimismAndReset() {
        let store = WalletStore()

        store.markProActiveOptimistically()
        store.creditCoinsOptimistically(120)
        store.lastPaymentErrorMessage = "결제 실패"

        #expect(store.isProActive)
        #expect(store.coinBalance == 120)
        #expect(store.lastPaymentErrorMessage == "결제 실패")

        store.reset()

        #expect(!store.isProActive)
        #expect(store.coinBalance == 0)
        #expect(store.lastPaymentErrorMessage == nil)
    }
}
