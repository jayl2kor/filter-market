@preconcurrency import AVFoundation
import CoreLocation
import Foundation
@preconcurrency import Photos
import SwiftUI
import UIKit
@preconcurrency import UserNotifications

// MARK: - PermissionCoordinator
//
// Phase D5 — `docs/PERMISSIONS_FLOW.md` 와 정합.
// 4 종 권한 (카메라 / 사진 / 푸시 / 위치) 의 상태 조회 + 시스템 다이얼로그 트리거.
//
// 본 코디네이터는 priming/denied SwiftUI 화면이 시스템 다이얼로그와 협업하기 위한
// 얇은 어댑터다. 기존 `Camera/CameraSession.swift` 와 `Camera/PhotoLibrarySaver.swift` 의
// 권한 체크 로직은 유지되며, 본 타입은 앱 진입 흐름 (priming → request → 결과 분기) 만
// 책임진다.
@MainActor
public final class PermissionCoordinator: ObservableObject {
    /// 권한 종류.
    public enum Permission: String, CaseIterable, Sendable {
        case camera
        case photos
        case notifications
        case location
    }

    /// 단순화된 권한 상태.
    /// - Note: PHAuthorizationStatus.limited 는 사진 한정으로 `.authorized` 로 매핑한다.
    ///         (moodit 의 add-only 저장에는 충분.)
    public enum Status: Equatable, Sendable {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    private let locationManager: CLLocationManager

    public init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
    }

    // MARK: - Status

    /// 시스템 API 로 현재 권한 상태 조회. 비동기가 필요한 푸시 알림용은 `currentStatusAsync` 사용.
    public func currentStatus(_ permission: Permission) -> Status {
        switch permission {
        case .camera:
            mapCamera(AVCaptureDevice.authorizationStatus(for: .video))
        case .photos:
            mapPhotos(PHPhotoLibrary.authorizationStatus(for: .addOnly))
        case .notifications:
            // 동기로는 정확히 알 수 없음 — 호출자는 `currentStatusAsync(.notifications)` 사용 권장.
            // priming 게이트에는 `.notDetermined` 로 응답해 비동기 확인을 유도한다.
            .notDetermined
        case .location:
            mapLocation(locationManager.authorizationStatus)
        }
    }

    /// 푸시 알림 등 비동기 조회 권한.
    public func currentStatusAsync(_ permission: Permission) async -> Status {
        switch permission {
        case .notifications:
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return mapNotifications(settings.authorizationStatus)
        case .camera, .photos, .location:
            return currentStatus(permission)
        }
    }

    // MARK: - Request

    /// 시스템 다이얼로그 트리거. 이미 결정된 상태면 시스템 호출 없이 현재 상태를 반환.
    @discardableResult
    public func request(_ permission: Permission) async -> Status {
        switch permission {
        case .camera:
            return await requestCamera()
        case .photos:
            return await requestPhotos()
        case .notifications:
            return await requestNotifications()
        case .location:
            return await requestLocation()
        }
    }

    /// 시스템 설정 앱의 본 앱 페이지로 이동.
    public func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Camera

    private func requestCamera() async -> Status {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else {
            return mapCamera(status)
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }

    private func mapCamera(_ status: AVAuthorizationStatus) -> Status {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }

    // MARK: - Photos (add-only)

    private func requestPhotos() async -> Status {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .notDetermined else {
            return mapPhotos(status)
        }
        let next = await withCheckedContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                continuation.resume(returning: newStatus)
            }
        }
        return mapPhotos(next)
    }

    private func mapPhotos(_ status: PHAuthorizationStatus) -> Status {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized, .limited: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }

    // MARK: - Notifications

    private func requestNotifications() async -> Status {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return mapNotifications(settings.authorizationStatus)
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    private func mapNotifications(_ status: UNAuthorizationStatus) -> Status {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized, .provisional, .ephemeral: .authorized
        case .denied: .denied
        @unknown default: .denied
        }
    }

    // MARK: - Location (WhenInUse only — EXIF 태그용)

    private func requestLocation() async -> Status {
        let initial = locationManager.authorizationStatus
        guard initial == .notDetermined else {
            return mapLocation(initial)
        }

        // CLLocationManager 는 콜백이 KVO/delegate 기반이라 폴링이 가장 안전한 단순 방식이다.
        // 시스템 다이얼로그는 `requestWhenInUseAuthorization()` 호출 즉시 표시되며,
        // 사용자가 응답할 때까지 `authorizationStatus` 가 `.notDetermined` 로 유지된다.
        locationManager.requestWhenInUseAuthorization()

        // 최대 30초 동안 0.1초 간격 폴링 (사용자 응답 대기). 응답 없으면 notDetermined 유지.
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            let current = locationManager.authorizationStatus
            if current != .notDetermined {
                return mapLocation(current)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return mapLocation(locationManager.authorizationStatus)
    }

    private func mapLocation(_ status: CLAuthorizationStatus) -> Status {
        switch status {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }
}

// MARK: - Environment
//
// `PermissionCoordinator` 는 `@MainActor` 격리이므로 EnvironmentKey 의 동기 default 를
// 직접 제공하기 어렵다. 본 phase 에서는 호출 측에서 `@StateObject` / `@EnvironmentObject`
// 로 직접 주입한다.
