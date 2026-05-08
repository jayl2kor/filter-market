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
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var lastError: String?
    @Published public private(set) var isProcessing = false

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

    /// App Store Connect에서 등록된 상품을 가져옴.
    /// 실패 시 lastError에 기록하고 빈 배열 유지.
    public func loadProducts(ids: [String] = IAPProductIDs.allIDs) async {
        do {
            let loaded = try await Product.products(for: ids)
            // 일관된 표시 순서 (코인 4종 → Pro 2종) 위해 IAPProductIDs.allIDs 순서 매칭.
            self.products = ids.compactMap { id in loaded.first(where: { $0.id == id }) }
            if self.products.isEmpty {
                self.lastError = "현재 결제 패키지를 불러올 수 없습니다. 잠시 후 다시 시도해주세요."
            } else {
                self.lastError = nil
            }
        } catch {
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
        defer { isProcessing = false }
        Telemetry.log(.iapAttempted, parameters: ["product_id": product.id])
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await creditBackend(transaction: transaction, productId: product.id, jws: verification.jwsRepresentation)
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
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedProductIDs.insert(transaction.productID)
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
        // 갱신 / 환불 / 백그라운드 푸시 시 도착하는 트랜잭션은 즉시 finish + 서버 동기화.
        await creditBackend(transaction: transaction, productId: transaction.productID, jws: jws)
        purchasedProductIDs.insert(transaction.productID)
        await transaction.finish()
    }

    // MARK: - Backend bridge

    /// StoreKit 검증된 트랜잭션 → Firebase Functions callable 호출.
    /// 실패해도 사용자에게는 noisy하게 보이지 않고 lastError만 갱신 — 사용자는 이미 결제 완료 후이므로.
    private func creditBackend(transaction: StoreKit.Transaction, productId: String, jws: String) async {
        let callableName = IAPProductIDs.isProSubscription(productId)
            ? "proSubscriptionUpdate"
            : "creditCoinsFromIAP"
        let callable = Functions.functions(region: region).httpsCallable(callableName)
        do {
            _ = try await callable.call([
                "originalTransactionId": String(transaction.originalID),
                "productId": productId,
                "signedJWS": jws
            ])
        } catch {
            lastError = "서버 동기화 실패: \(error.localizedDescription)"
        }
    }
}
