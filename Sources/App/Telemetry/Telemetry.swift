import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation
import SwiftUI

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
        case deepLinkFailed    = "deep_link_failed"
        case filterApplied     = "filter_applied"
        case filterShared      = "filter_shared"
        case filterSaved       = "filter_saved"

        // Maker funnel
        case filterSubmitted   = "filter_submitted"
        case filterApproved    = "filter_approved"
        case filterRejected    = "filter_rejected"

        // Screen and UX health
        case screenExit        = "screen_exit"
        case funnelStep        = "funnel_step"
        case userAction        = "user_action"
        case emptyStateShown   = "empty_state_shown"
        case errorShown        = "error_shown"
        case pullToRefresh     = "pull_to_refresh"
    }

    enum Screen: String {
        case marketplaceHome = "marketplace_home"
        case search = "search"
        case saved = "saved"
        case profile = "profile"
        case cameraLive = "camera_live"
        case filterDetail = "filter_detail"
        case filterDownload = "filter_download"
        case filterAfterDownload = "filter_after_download"
        case login = "login"
        case emailLogin = "email_login"
        case settings = "settings"
        case wallet = "wallet"
        case walletTopup = "wallet_topup"
        case walletTransactions = "wallet_transactions"
        case paywall = "paywall"
        case proSubscription = "pro_subscription"
        case ordersHistory = "orders_history"
        case insufficientBalance = "insufficient_balance"
        case reviews = "reviews"
        case reviewCompose = "review_compose"
        case rating = "rating"
        case notifications = "notifications"
        case notificationSettings = "notification_settings"
        case otherProfile = "other_profile"
        case followers = "followers"
        case following = "following"
        case favoritesCollection = "favorites_collection"
        case forYou = "for_you"
        case followingFeed = "following_feed"
        case filterEditor = "filter_editor"
        case editorParameters = "editor_parameters"
        case editorLUT = "editor_lut"
        case editorDraft = "editor_draft"
        case uploadCover = "upload_cover"
        case uploadTags = "upload_tags"
        case uploadSubmit = "upload_submit"
        case uploadPending = "upload_pending"
        case photoImport = "photo_import"
        case photoEdit = "photo_edit"
        case captureDetail = "capture_detail"
        case cameraAspect = "camera_aspect"
        case cameraTimer = "camera_timer"
        case builtinFilters = "builtin_filters"
        case accountDeletion = "account_deletion"
        case editProfile = "edit_profile"
        case universalLinkLanding = "universal_link_landing"
        case makerDashboard = "maker_dashboard"
        case reportForm = "report_form"
        case moderationQueue = "moderation_queue"
        case moderationDetail = "moderation_detail"
        case blockList = "block_list"
        case remixFlow = "remix_flow"
        case payoutOnboarding = "payout_onboarding"
        case payoutTaxInfo = "payout_tax_info"
        case payoutHistory = "payout_history"
        case earningsWithdraw = "earnings_withdraw"
        case filterRejected = "filter_rejected"
        case proStatus = "pro_status"
        case myFilters = "my_filters"
        case paymentFailed = "payment_failed"
        case dataExport = "data_export"
        case refundRequest = "refund_request"
        case helpCenter = "help_center"
    }

    /// 분석 이벤트 발행. parameters는 Firebase Analytics 규약을 따름 (key, value 모두 직렬화 가능).
    static func log(_ event: Event, parameters: [String: Any]? = nil) {
        guard !isUITesting else { return }
        Analytics.logEvent(event.rawValue, parameters: sanitizedParameters(parameters ?? [:]))
    }

    static func trackScreenView(_ screen: Screen, parameters: [String: Any] = [:]) {
        guard !isUITesting else { return }
        var payload = sanitizedParameters(parameters)
        payload[AnalyticsParameterScreenName] = screen.rawValue
        Analytics.logEvent(AnalyticsEventScreenView, parameters: payload)
    }

    static func trackScreenExit(
        _ screen: Screen,
        duration: TimeInterval?,
        parameters: [String: Any] = [:]
    ) {
        guard !isUITesting else { return }
        var payload = sanitizedParameters(parameters)
        payload["screen_name"] = screen.rawValue
        if let duration {
            payload["duration_ms"] = max(0, Int((duration * 1_000).rounded()))
        }
        log(.screenExit, parameters: payload)
    }

    static func trackAction(_ action: String, screen: Screen, parameters: [String: Any] = [:]) {
        var payload = sanitizedParameters(parameters)
        payload["screen_name"] = screen.rawValue
        payload["action"] = action
        log(.userAction, parameters: payload)
    }

    static func trackFunnelStep(_ funnel: String, step: String, screen: Screen, parameters: [String: Any] = [:]) {
        var payload = sanitizedParameters(parameters)
        payload["screen_name"] = screen.rawValue
        payload["funnel"] = funnel
        payload["step"] = step
        log(.funnelStep, parameters: payload)
    }

    static func trackEmptyState(_ name: String, screen: Screen, parameters: [String: Any] = [:]) {
        var payload = sanitizedParameters(parameters)
        payload["screen_name"] = screen.rawValue
        payload["state_name"] = name
        log(.emptyStateShown, parameters: payload)
    }

    static func trackError(_ name: String, screen: Screen, parameters: [String: Any] = [:]) {
        var payload = sanitizedParameters(parameters)
        payload["screen_name"] = screen.rawValue
        payload["error_name"] = name
        log(.errorShown, parameters: payload)
    }

    static func trackPullToRefresh(_ screen: Screen, parameters: [String: Any] = [:]) {
        var payload = sanitizedParameters(parameters)
        payload["screen_name"] = screen.rawValue
        log(.pullToRefresh, parameters: payload)
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

    static func sanitizedParameters(_ parameters: [String: Any]) -> [String: Any] {
        parameters.reduce(into: [String: Any]()) { result, entry in
            guard let value = sanitizedParameterValue(entry.value) else { return }
            let key = sanitizedParameterKey(entry.key)
            result[key] = value
        }
    }

    private static func sanitizedParameterKey(_ key: String) -> String {
        let normalized = key
            .lowercased()
            .map { character -> Character in
                if character.isLetter || character.isNumber || character == "_" {
                    return character
                }
                return "_"
            }
        let joined = String(normalized)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return String((joined.isEmpty ? "param" : joined).prefix(40))
    }

    private static func sanitizedParameterValue(_ value: Any) -> Any? {
        switch value {
        case let value as String:
            return String(value.prefix(100))
        case let value as Int:
            return value
        case let value as Double:
            return value.isFinite ? value : nil
        case let value as Float:
            return value.isFinite ? Double(value) : nil
        case let value as Bool:
            return value ? 1 : 0
        case let value as NSNumber:
            return value
        case let value as URL:
            return value.host ?? "url"
        default:
            return nil
        }
    }
}

private struct FMScreenTrackingModifier: ViewModifier {
    let screen: Telemetry.Screen
    let parameters: [String: Any]
    @State private var appearedAt: Date?

    func body(content: Content) -> some View {
        content
            .onAppear {
                appearedAt = Date()
                Telemetry.trackScreenView(screen, parameters: parameters)
            }
            .onDisappear {
                Telemetry.trackScreenExit(
                    screen,
                    duration: appearedAt.map { Date().timeIntervalSince($0) },
                    parameters: parameters
                )
                appearedAt = nil
            }
    }
}

extension View {
    func fmTrackScreen(_ screen: Telemetry.Screen, parameters: [String: Any] = [:]) -> some View {
        modifier(FMScreenTrackingModifier(screen: screen, parameters: parameters))
    }
}
