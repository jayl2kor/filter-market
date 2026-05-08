import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation

/// Telemetry — analytics 이벤트 + crash 보고를 한 곳에서.
///
/// FirebaseApp.configure() 후 자동 활성화. 호출은 main thread 안전.
enum Telemetry {
    enum Event: String {
        // Auth funnel
        case signInAttempted   = "signin_attempted"
        case signInSucceeded   = "signin_succeeded"
        case signInFailed      = "signin_failed"

        // IAP funnel (코인 충전 / Pro 구독)
        case iapAttempted      = "iap_attempted"
        case iapSucceeded      = "iap_succeeded"
        case iapFailed         = "iap_failed"

        // Filter purchase (코인 차감)
        case filterPurchaseAttempted    = "filter_purchase_attempted"
        case filterPurchaseSucceeded    = "filter_purchase_succeeded"
        case filterPurchaseInsufficient = "filter_purchase_insufficient"
        case filterPurchaseFailed       = "filter_purchase_failed"

        // Engagement
        case appResumed        = "app_resumed"
        case deepLinkReceived  = "deep_link_received"
        case deepLinkDeferred  = "deep_link_deferred"
        case deepLinkFlushed   = "deep_link_flushed"
        case filterApplied     = "filter_applied"
        case filterShared      = "filter_shared"
        case filterSaved       = "filter_saved"

        // Maker funnel
        case filterSubmitted   = "filter_submitted"
        case filterApproved    = "filter_approved"
        case filterRejected    = "filter_rejected"
    }

    /// 분석 이벤트 발행. parameters는 Firebase Analytics 규약을 따름 (key, value 모두 직렬화 가능).
    static func log(_ event: Event, parameters: [String: Any]? = nil) {
        guard !isUITesting else { return }
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }

    /// Crashlytics에 user identifier 등록 — 인증된 uid 또는 nil(로그아웃).
    static func setUserId(_ uid: String?) {
        guard !isUITesting else { return }
        Crashlytics.crashlytics().setUserID(uid ?? "")
        if let uid {
            Analytics.setUserID(uid)
        } else {
            Analytics.setUserID(nil)
        }
    }

    /// 비치명적 오류 기록. 사용자 화면에 표시되지 않은 백그라운드 오류 추적용.
    static func record(error: Error, context: [String: String] = [:]) {
        guard !isUITesting else { return }
        let crashlytics = Crashlytics.crashlytics()
        for (key, value) in context {
            crashlytics.setCustomValue(value, forKey: key)
        }
        crashlytics.record(error: error)
    }
}
