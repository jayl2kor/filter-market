import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

final class ForegroundNotificationPolicy: @unchecked Sendable {
    static let shared = ForegroundNotificationPolicy()

    private enum Category {
        case system
        case social
        case reviews
        case marketplace
        case creator
        case wallet
        case product
    }

    private let lock = NSLock()
    private var preferences = NotificationPreferences()

    private init() {}

    func update(preferences: NotificationPreferences) {
        lock.lock()
        self.preferences = preferences
        lock.unlock()
    }

    func presentationOptions(
        for userInfo: [AnyHashable: Any],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UNNotificationPresentationOptions {
        lock.lock()
        let current = preferences
        lock.unlock()

        let category = category(for: userInfo)
        guard current.systemEnabled else { return [.badge] }
        guard isCategoryEnabled(category, preferences: current) else { return [.badge] }
        if category != .system, isQuietTime(now: now, calendar: calendar, preferences: current) {
            return [.badge]
        }
        return [.banner, .badge, .sound]
    }

    private func category(for userInfo: [AnyHashable: Any]) -> Category {
        let rawKind = stringValue(for: "kind", in: userInfo)
            ?? stringValue(for: "type", in: userInfo)
            ?? stringValue(for: "category", in: userInfo)
            ?? "system"
        switch rawKind.lowercased() {
        case "follow", "followrequest", "newfollower", "like", "liked", "mention":
            return .social
        case "review", "reviews", "comment", "makerreply", "rating":
            return .reviews
        case "download", "downloads", "recommendation", "collection", "marketplace", "filter":
            return .marketplace
        case "creator", "maker", "moderation", "approved", "rejected", "upload":
            return .creator
        case "wallet", "payment", "refund", "purchase", "pro", "subscription":
            return .wallet
        case "product", "news", "event", "announcement":
            return .product
        default:
            return .system
        }
    }

    private func stringValue(for key: String, in userInfo: [AnyHashable: Any]) -> String? {
        if let value = userInfo[key] as? String {
            return value
        }
        if let value = userInfo[AnyHashable(key)] as? String {
            return value
        }
        return nil
    }

    private func isCategoryEnabled(_ category: Category, preferences: NotificationPreferences) -> Bool {
        switch category {
        case .system:
            return preferences.systemEnabled
        case .social:
            return preferences.social
        case .reviews:
            return preferences.reviews
        case .marketplace:
            return preferences.marketplace
        case .creator:
            return preferences.creator
        case .wallet:
            return preferences.wallet
        case .product:
            return preferences.product
        }
    }

    private func isQuietTime(
        now: Date,
        calendar: Calendar,
        preferences: NotificationPreferences
    ) -> Bool {
        guard preferences.quietHoursEnabled else { return false }
        guard
            let start = minutes(from: preferences.quietStart),
            let end = minutes(from: preferences.quietEnd)
        else { return false }

        let components = calendar.dateComponents([.hour, .minute], from: now)
        let current = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if start == end {
            return false
        }
        if start < end {
            return current >= start && current < end
        }
        return current >= start || current < end
    }

    private func minutes(from value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard
            parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }
}

/// Centralizes APNs + FCM registration and per-device token persistence.
///
/// Lifecycle:
/// 1. `bootstrap(application:)` is called from `AppDelegate.didFinishLaunching`.
/// 2. The user is prompted for `.alert | .badge | .sound` authorization.
/// 3. On grant, the app registers for remote notifications.
/// 4. APNs delivers a device token → forwarded to `Messaging.apnsToken`.
/// 5. Firebase Messaging issues an FCM token → persisted to Firestore at
///    `/users/{uid}/devices/{deviceId}` so server-side fan-out can address
///    multiple devices per user (iPad + iPhone, etc.).
///
/// `deviceId` is `identifierForVendor` — stable per (vendor, device) until the
/// user uninstalls every moodit app from the vendor.
@MainActor
final class PushRegistration: NSObject {
    static let shared = PushRegistration()

    /// Closure invoked when the user taps a notification carrying a recognized
    /// deep-link payload. Wired by the app shell so it can route into a
    /// `MooditStore.pendingDeepLinkRoute`.
    var deepLinkHandler: ((AppRoute) -> Void)?
    private var lastKnownFCMToken: String?

    private var firestore: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }

    private var auth: Auth? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth()
    }

    private override init() { super.init() }

    /// Wire delegates and request authorization. Idempotent — safe to call once
    /// per launch from `AppDelegate.didFinishLaunching`.
    func bootstrap(application: UIApplication) {
        guard FirebaseApp.app() != nil else {
            // Firebase not configured (missing GoogleService-Info.plist) — skip
            // silently to mirror AppDelegate.configureFirebaseIfAvailable behavior.
            #if DEBUG
            print("[Push] Firebase not configured; skipping push registration.")
            #endif
            return
        }

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error {
                #if DEBUG
                print("[Push] Authorization error: \(error.localizedDescription)")
                #endif
                return
            }
            guard granted else {
                #if DEBUG
                print("[Push] Authorization denied by user.")
                #endif
                return
            }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    /// APNs token → FirebaseMessaging.
    func handleAPNsToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    /// Called after Auth becomes available. FCM may have issued the token while
    /// signed out, so retry with the cached token or explicitly fetch it.
    func retryDeviceRegistrationForCurrentUser() {
        guard FirebaseApp.app() != nil else { return }
        if let lastKnownFCMToken {
            persistDevice(fcmToken: lastKnownFCMToken)
            return
        }

        Messaging.messaging().token { [weak self] token, error in
            if let error {
                #if DEBUG
                print("[Push] Failed to fetch FCM token after auth: \(error.localizedDescription)")
                #endif
                return
            }
            guard let token else { return }
            Task { @MainActor in
                self?.persistDevice(fcmToken: token)
            }
        }
    }

    /// 로그아웃 직전 호출 — 현재 디바이스의 \`/users/{uid}/devices/{deviceId}\` doc 삭제.
    /// uid를 인자로 받는 이유: Auth.signOut() 후엔 currentUser가 nil이라 doc 경로를 못 만듦. (#23)
    func unregisterCurrentDevice(uid: String) {
        guard
            let firestore,
            let deviceId = UIDevice.current.identifierForVendor?.uuidString
        else { return }
        firestore
            .collection("users")
            .document(uid)
            .collection("devices")
            .document(deviceId)
            .delete { error in
                #if DEBUG
                if let error {
                    print("[Push] Failed to delete device doc: \(error.localizedDescription)")
                }
                #endif
            }
    }

    /// Persist `(uid, deviceId, fcmToken)` to Firestore so backend fan-out can
    /// address every device of a user.
    fileprivate func persistDevice(fcmToken: String) {
        lastKnownFCMToken = fcmToken
        guard
            let firestore,
            let uid = auth?.currentUser?.uid,
            let deviceId = UIDevice.current.identifierForVendor?.uuidString
        else {
            #if DEBUG
            print("[Push] Skipping persist — no Firebase, signed-out user, or missing vendor id.")
            #endif
            return
        }

        let payload: [String: Any] = [
            "fcmToken": fcmToken,
            "platform": "ios",
            "deviceId": deviceId,
            "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            "osVersion": UIDevice.current.systemVersion,
            "deviceModel": UIDevice.current.model,
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        firestore
            .collection("users")
            .document(uid)
            .collection("devices")
            .document(deviceId)
            .setData(payload, merge: true) { error in
                #if DEBUG
                if let error {
                    print("[Push] Failed to persist device record: \(error.localizedDescription)")
                } else {
                    print("[Push] Persisted FCM token for device \(deviceId).")
                }
                #endif
            }
    }
}

// MARK: - MessagingDelegate

extension PushRegistration: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            self.persistDevice(fcmToken: fcmToken)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushRegistration: UNUserNotificationCenterDelegate {
    /// Foreground delivery — respect app notification preferences while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(
            ForegroundNotificationPolicy.shared.presentationOptions(
                for: notification.request.content.userInfo
            )
        )
    }

    /// Tap handling — parses the FCM payload via UniversalLinkParser and
    /// forwards a resolved route to the app shell's `deepLinkHandler`.
    ///
    /// `userInfo` and `completionHandler` are not `Sendable` so we resolve the
    /// route on the calling actor (where this delegate is invoked) and only
    /// hop to the main actor with the already-resolved (Sendable) route.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let route = UniversalLinkParser.route(forPushUserInfo: userInfo)
        if let route {
            Task { @MainActor [route] in
                self.deepLinkHandler?(route)
            }
        }
        completionHandler()
    }
}
