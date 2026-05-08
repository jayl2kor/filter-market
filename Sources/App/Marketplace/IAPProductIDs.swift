import Foundation

/// In-App Purchase 상품 ID 모음.
///
/// App Store Connect IAP 등록 ID와 1:1 매칭 (Issue #14).
/// 신규 상품 추가 시 이 enum 만 수정하면 StoreKitManager 가 자동 인식.
public enum IAPProductIDs {
    /// 코인 100개 — 가장 가벼운 충전.
    public static let coins100 = "com.jayl2kor.moodit.coins.100"
    /// 코인 550개 (50 보너스).
    public static let coins550 = "com.jayl2kor.moodit.coins.550"
    /// 코인 1200개 (200 보너스, 가장 인기).
    public static let coins1200 = "com.jayl2kor.moodit.coins.1200"
    /// 코인 3000개 (700 보너스, Pro Pack).
    public static let coins3000 = "com.jayl2kor.moodit.coins.3000"

    /// Pro 멤버십 월간.
    public static let proMonthly = "com.jayl2kor.moodit.pro.monthly"
    /// Pro 멤버십 연간.
    public static let proYearly = "com.jayl2kor.moodit.pro.yearly"

    /// 모든 코인 SKU.
    public static let coinIDs: [String] = [coins100, coins550, coins1200, coins3000]
    /// 모든 Pro 구독 SKU.
    public static let proIDs: [String] = [proMonthly, proYearly]
    /// 전체 SKU.
    public static let allIDs: [String] = coinIDs + proIDs

    /// 상품 ID → 제공 코인 수 (코인 패키지에 한해).
    public static func coinAmount(for productId: String) -> Int? {
        switch productId {
        case coins100: 100
        case coins550: 550
        case coins1200: 1200
        case coins3000: 3000
        default: nil
        }
    }

    /// Pro 구독 여부 판정.
    public static func isProSubscription(_ productId: String) -> Bool {
        proIDs.contains(productId)
    }
}
