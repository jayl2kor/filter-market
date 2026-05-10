import FirebaseFunctions
import Foundation
import StoreKit
import SwiftUI

/// StoreKit 2 통합 매니저.
///
/// - 상품 로드: `loadProducts(ids:)`
/// - 구매: `purchase(_:)` — 결과 Verified/Unverified 구분, 검증 성공 시 백엔드 callable 호출 + StoreKit.Transaction.finish()
/// - 트랜잭션 업데이트 리스너: 인스턴스 시작 시 자동 시작 (구독 갱신, 환불 등 백그라운드 이벤트 처리)
///
/// 백엔드 연동:
/// - 코인 SKU → `creditCoinsFromIAP({ originalTransactionId, productId, signedJWS })` callable
/// - Pro SKU → `proSubscriptionUpdate({ originalTransactionId, productId, signedJWS })` callable (신규 — Sprint2)
@MainActor
public final class StoreKitManager: ObservableObject {
    public struct CoinCreditResult: Equatable, Sendable {
        public let creditedAmount: Int
        public let balance: Int
        public let duplicate: Bool
    }

    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastCoinCreditResult: CoinCreditResult?
    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastProductsLoadFailureKind: ProductsLoadFailureKind?

    private var updatesTask: Task<Void, Never>?
    private let region: String

    public init(region: String = "asia-northeast3") {
        self.region = region
        startTransactionListener()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Products

    public enum ProductsLoadFailureKind: String, Equatable, Sendable {
        case empty
        case partial
        case requestFailed
    }

    /// App Store Connect에서 등록된 상품을 가져옴.
    /// 실패 시 lastError에 기록하고 빈 배열 유지.
    public func loadProducts(ids: [String] = IAPProductIDs.allIDs, retryOnEmpty: Bool = true) async {
        await loadProducts(ids: ids, attempt: 1)
        guard retryOnEmpty, products.isEmpty, lastProductsLoadFailureKind == .empty else { return }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await loadProducts(ids: ids, attempt: 2)
    }

    private func loadProducts(ids: [String], attempt: Int) async {
        do {
            let loaded = try await Product.products(for: ids)
            // 일관된 표시 순서 (코인 4종 → Pro 2종) 위해 IAPProductIDs.allIDs 순서 매칭.
            self.products = ids.compactMap { id in loaded.first(where: { $0.id == id }) }
            let loadedIDs = Set(loaded.map(\.id))
            let missingIDs = Self.missingProductIDs(requested: ids, loaded: loadedIDs)
            if self.products.isEmpty {
                self.lastProductsLoadFailureKind = .empty
                self.lastError = Self.emptyProductsMessage
                Telemetry.log(.iapProductsLoadEmpty, parameters: [
                    "requested_count": ids.count,
                    "attempt": attempt,
                    "missing_product_ids": missingIDs.joined(separator: ",")
                ])
            } else if !missingIDs.isEmpty {
                self.lastProductsLoadFailureKind = .partial
                self.lastError = nil
                Telemetry.log(.iapProductsLoadPartial, parameters: [
                    "requested_count": ids.count,
                    "loaded_count": self.products.count,
                    "attempt": attempt,
                    "missing_product_ids": missingIDs.joined(separator: ",")
                ])
            } else {
                self.lastProductsLoadFailureKind = nil
                self.lastError = nil
            }
        } catch {
            self.lastProductsLoadFailureKind = .requestFailed
            self.lastError = "상품을 불러오지 못했어요: \(error.localizedDescription)"
            self.products = []
        }
    }

    // MARK: - Purchase

    public enum PurchaseOutcome {
        case success(VerificationResult<StoreKit.Transaction>)
        case userCancelled
        case pending
        case failed(String)
    }

    /// 사용자가 선택한 상품을 구매 시도. 검증 성공 시 백엔드 callable로 코인/Pro 적립.
    public func purchase(_ product: Product) async -> PurchaseOutcome {
        isProcessing = true
        lastCoinCreditResult = nil
        defer { isProcessing = false }
        Telemetry.log(.iapAttempted, parameters: ["product_id": product.id])
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    let synced = await creditBackend(transaction: transaction, productId: product.id, jws: verification.jwsRepresentation)
                    guard synced else {
                        Telemetry.log(.iapFailed, parameters: ["product_id": product.id, "reason": "backend_sync_failed"])
                        return .failed(lastError ?? "서버 동기화 실패")
                    }
                    purchasedProductIDs.insert(product.id)
                    await transaction.finish()
                    Telemetry.log(.iapSucceeded, parameters: ["product_id": product.id])
                    return .success(verification)
                case .unverified(_, let error):
                    lastError = "결제 검증 실패: \(error.localizedDescription)"
                    Telemetry.log(.iapFailed, parameters: ["product_id": product.id, "reason": "unverified"])
                    return .failed(error.localizedDescription)
                }
            case .userCancelled:
                Telemetry.log(.iapFailed, parameters: ["product_id": product.id, "reason": "user_cancelled"])
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                Telemetry.log(.iapFailed, parameters: ["product_id": product.id, "reason": "unknown"])
                return .failed("알 수 없는 결제 결과")
            }
        } catch {
            lastError = error.localizedDescription
            Telemetry.log(.iapFailed, parameters: ["product_id": product.id, "reason": "exception"])
            Telemetry.record(error: error, context: ["where": "StoreKitManager.purchase", "product_id": product.id])
            return .failed(error.localizedDescription)
        }
    }

    /// 복원 — Pro 구독 entitlement / 미반영된 코인 receipts를 다시 동기화.
    public func restore() async {
        lastCoinCreditResult = nil
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                let synced = await creditBackend(
                    transaction: transaction,
                    productId: transaction.productID,
                    jws: result.jwsRepresentation
                )
                if synced {
                    purchasedProductIDs.insert(transaction.productID)
                }
            }
        }
    }

    // MARK: - Background transaction listener

    private func startTransactionListener() {
        updatesTask?.cancel()
        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await self.handleBackgroundTransaction(transaction, jws: update.jwsRepresentation)
                }
            }
        }
    }

    private func handleBackgroundTransaction(_ transaction: StoreKit.Transaction, jws: String) async {
        // Finish only after backend sync succeeds so StoreKit can retry transient failures.
        let synced = await creditBackend(transaction: transaction, productId: transaction.productID, jws: jws)
        guard synced else { return }
        purchasedProductIDs.insert(transaction.productID)
        await transaction.finish()
    }

    // MARK: - Backend bridge

    /// StoreKit 검증된 트랜잭션 → Firebase Functions callable 호출.
    /// Returns true only when the backend accepted the transaction. Callers must not
    /// finish StoreKit transactions on false so StoreKit can retry later.
    @discardableResult
    private func creditBackend(transaction: StoreKit.Transaction, productId: String, jws: String) async -> Bool {
        let callableName = Self.backendCallableName(for: productId)
        let isProSubscription = IAPProductIDs.isProSubscription(productId)
        let callable = Functions.functions(region: region).httpsCallable(callableName)
        do {
            let result = try await callable.call([
                "originalTransactionId": String(transaction.originalID),
                "productId": productId,
                "signedJWS": jws
            ])
            guard !isProSubscription else {
                return true
            }
            guard let coinResult = Self.parseCoinCreditResult(result.data) else {
                lastError = "서버 응답을 해석하지 못했어요."
                return false
            }
            lastCoinCreditResult = coinResult
            return true
        } catch {
            lastError = "서버 동기화 실패: \(error.localizedDescription)"
            return false
        }
    }

    nonisolated static func backendCallableName(for productId: String) -> String {
        IAPProductIDs.isProSubscription(productId)
            ? "proSubscriptionUpdate"
            : "creditCoinsFromIAP"
    }

    nonisolated static func missingProductIDs(requested: [String], loaded: Set<String>) -> [String] {
        requested.filter { !loaded.contains($0) }
    }

    nonisolated private static var emptyProductsMessage: String {
        #if DEBUG
        return "결제 상품을 찾지 못했어요. 개발 빌드에서는 Xcode scheme의 StoreKit Configuration 연결을 확인하고, TestFlight/운영에서는 App Store Connect 상품 ID와 판매 가능 상태를 확인해주세요."
        #else
        return "현재 결제 패키지를 불러올 수 없습니다. 잠시 후 다시 시도해주세요."
        #endif
    }

    nonisolated static func parseCoinCreditResult(_ data: Any) -> CoinCreditResult? {
        guard let dict = data as? [String: Any] else { return nil }
        let creditedAmount = dict["creditedAmount"] as? Int ?? (dict["creditedAmount"] as? NSNumber)?.intValue
        let balance = dict["balance"] as? Int ?? (dict["balance"] as? NSNumber)?.intValue
        let duplicate = dict["duplicate"] as? Bool ?? (dict["duplicate"] as? NSNumber)?.boolValue
        guard let creditedAmount, let balance, let duplicate else { return nil }
        return CoinCreditResult(
            creditedAmount: creditedAmount,
            balance: max(balance, 0),
            duplicate: duplicate
        )
    }
}
