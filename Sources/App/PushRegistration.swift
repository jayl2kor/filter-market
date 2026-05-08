import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

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

    /// Persist `(uid, deviceId, fcmToken)` to Firestore so backend fan-out can
    /// address every device of a user.
    fileprivate func persistDevice(fcmToken: String) {
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
    /// Foreground delivery — show banner + sound while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
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
