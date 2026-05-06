# filterMarket — 권한 요청 플로우

> 버전: v1.2 · 작성일: 2026-05-06
> `mockups/screens/permissions/` 8개 화면과 1:1 매핑.
> iOS 17+, Swift 5.10+, SwiftUI+UIKit 기준.

---

## 개요

filterMarket 은 4가지 시스템 권한이 필요하다:

| 권한 | 필수 여부 | 요청 시점 |
|---|---|---|
| 카메라 | 핵심 기능 — 없으면 앱 주기능 불가 | 카메라 화면(03) 첫 진입 직전 |
| 사진 라이브러리 | 중요 — 없으면 저장/업로드 불가 | 촬영 후 저장 시도 시 |
| 푸시 알림 | 선택 — 없어도 핵심 기능 동작 | 온보딩 완료 후 (별도 흐름) |
| 위치 (EXIF) | 선택 — 사진 위치 태그 전용 | 첫 저장 시, 선택 항목으로 |

### 권한 UX 원칙

1. **Priming 먼저**: 시스템 다이얼로그 전에 반드시 앱 내 priming 화면을 보여준다. 시스템 다이얼로그는 한 번 거부하면 재호출 불가이므로 맥락을 충분히 설명한 뒤 요청한다.
2. **시점 존중**: 기능이 실제로 필요할 때 요청한다. 앱 실행 직후 일괄 요청 금지.
3. **거부 시 graceful fallback**: 거부해도 앱이 동작 가능한 범위를 최대화하고, 설정으로 안내하는 경로를 항상 제공한다.

---

## PF-01. 카메라 권한

### 요청 시점

사용자가 탭 바에서 카메라 탭을 탭하거나 마켓에서 "필터 적용해 찍기" CTA를 탭할 때.
카메라 라이브뷰(03) 화면으로 이동하기 **직전**에 priming 화면을 삽입한다.

```
[마켓 홈] → "필터 적용해 찍기" 탭
    → 카메라 권한 미승인 확인
        → [priming 화면: camera-priming.html]
            → "허용" 탭
                → iOS 시스템 다이얼로그
                    → 승인 → [카메라 라이브뷰 03]
                    → 거부 → [거부 안내 화면: camera-denied.html]
```

### Priming 화면 (`camera-priming.html`)

- **일러스트**: 카메라 아이콘 (`camera.fill`), 골드 강조
- **헤드라인**: 필터를 입혀 촬영하기
- **본문**: 라이브 프리뷰에서 필터를 적용해 사진을 찍으려면 카메라 접근이 필요해요. 촬영한 사진은 언제든 저장 또는 삭제할 수 있어요.
- **CTA Primary**: 허용
- **CTA Ghost**: 나중에
- **힌트**: 설정에서 언제든 변경할 수 있어요.

**한국어 / 영어 메시지 초안**

| | 한국어 | 영어 |
|---|---|---|
| 헤드라인 | 필터를 입혀 촬영하기 | Shoot with Live Filters |
| 본문 | 라이브 프리뷰에서 필터를 적용해 사진을 찍으려면 카메라 접근이 필요해요. | Camera access is needed to apply filters in real time while shooting. |
| Info.plist 문구 | filterMarket이 라이브 필터를 적용한 사진 촬영에 카메라를 사용합니다. | filterMarket uses the camera to take photos with live filters applied. |

### iOS Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>filterMarket이 라이브 필터를 적용한 사진 촬영에 카메라를 사용합니다.</string>
```

### 거부 시 Fallback (`camera-denied.html`)

iOS는 시스템 다이얼로그를 한 번 거부하면 앱에서 재호출할 수 없다.
반드시 **설정 앱으로 안내**해야 한다.

- **헤드라인**: 카메라 접근이 꺼져 있어요
- **본문**: 설정 앱에서 filterMarket의 카메라 접근을 켜주세요.
- **단계 안내**:
  1. **설정** 앱 열기
  2. **filterMarket** 항목으로 이동
  3. **카메라** 토글 켜기
- **CTA Primary**: 설정 열기
- **CTA Ghost**: 나중에 (카메라 없이 마켓만 사용)

### SwiftUI 구현 의사코드

```swift
import AVFoundation

func requestCameraAccess() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        return true
    case .notDetermined:
        return await AVCaptureDevice.requestAccess(for: .video)
    case .denied, .restricted:
        // 설정으로 안내
        await MainActor.run { showCameradenied = true }
        return false
    @unknown default:
        return false
    }
}

// 설정 앱 열기
Button("설정 열기") {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}
```

---

## PF-02. 사진 라이브러리 권한

### 요청 시점

촬영 미리보기(05)에서 "사진에 저장" 버튼을 탭할 때.
또는 업로드 플로우(12)에서 갤러리 접근 시.

```
[촬영 미리보기 05] → "사진에 저장" 탭
    → 사진 권한 미승인 확인
        → [priming 화면: photos-priming.html]
            → "허용" 탭
                → iOS 시스템 다이얼로그 (Add Only 또는 Full Access)
                    → 승인 → 사진 저장 실행
                    → 거부 → [거부 안내 화면: photos-denied.html]
```

> **iOS 14+ Add-Only 권한**: `PHAuthorizationStatus.limited` 또는 `.addOnly` 상태에서 저장만 가능. filterMarket 의 "저장" 기능은 `.addOnly` 만으로 충분하므로 Full Access 를 강요하지 않는다.

### Priming 화면 (`photos-priming.html`)

- **일러스트**: 사진 프레임 아이콘 (`photo.on.rectangle`), 골드
- **헤드라인**: 사진 앱에 저장하기
- **본문**: 촬영한 사진을 사진 앱에 저장하려면 접근 권한이 필요해요. filterMarket 은 저장 기능에만 사용하며, 기존 사진을 읽거나 수정하지 않아요.
- **CTA Primary**: 허용
- **CTA Ghost**: 나중에 (저장하지 않고 계속)

**한국어 / 영어 메시지 초안**

| | 한국어 | 영어 |
|---|---|---|
| 헤드라인 | 사진 앱에 저장하기 | Save to Photos |
| 본문 | 촬영한 사진을 사진 앱에 저장하려면 접근이 필요해요. 저장 기능에만 사용해요. | We need access to save your photo to the Photos app. We only add photos, never read or modify existing ones. |
| Info.plist 문구 | filterMarket이 촬영한 사진을 사진 앱에 저장합니다. 기존 사진에는 접근하지 않습니다. | filterMarket saves captured photos to your Photos library. Existing photos are never accessed. |

### iOS Info.plist

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>filterMarket이 촬영한 사진을 사진 앱에 저장합니다. 기존 사진에는 접근하지 않습니다.</string>

<!-- 갤러리 읽기(업로드)가 필요한 경우 추가 -->
<key>NSPhotoLibraryUsageDescription</key>
<string>filterMarket이 필터 업로드를 위해 사진 앱의 이미지를 읽습니다.</string>
```

### 거부 시 Fallback (`photos-denied.html`)

- **헤드라인**: 사진 저장이 꺼져 있어요
- **본문**: 설정 앱에서 filterMarket 의 사진 접근을 켜주세요.
- **단계 안내**: 설정 → filterMarket → 사진 → "추가만" 또는 "모든 사진" 선택
- **CTA Primary**: 설정 열기
- **CTA Ghost**: 나중에 (저장 없이 계속)

### SwiftUI 구현 의사코드

```swift
import Photos

func requestPhotoLibraryAccess() async -> PHAuthorizationStatus {
    let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    if current == .notDetermined {
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
    return current
}

func savePhoto(_ image: UIImage) async {
    let status = await requestPhotoLibraryAccess()
    switch status {
    case .authorized, .limited:
        // PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) }
        break
    case .denied, .restricted:
        await MainActor.run { showPhotosDenied = true }
    default:
        break
    }
}
```

---

## PF-03. 푸시 알림 권한

### 요청 시점

온보딩(01) 완료 후, 메인 화면(06) 첫 진입 시점에 별도 priming 화면으로 요청.
핵심 기능(카메라, 마켓)과 무관하므로 앱 첫 실행 즉시 요청 금지.

```
[온보딩 완료] → [마켓 홈 첫 진입]
    → 3~5초 지연 후 or 자연스러운 맥락 전환 시
        → [priming 화면: notifications-priming.html]
            → "허용" 탭
                → iOS 시스템 다이얼로그
                    → 승인 → 알림 활성화
                    → 거부 → [거부 안내 화면: notifications-denied.html]
```

> **재요청 불가 원칙**: 거부 후 `UNUserNotificationCenter.requestAuthorization` 재호출은 iOS에서 무시된다. 거부된 사용자에게는 priming 화면을 반복 노출하지 않는다.

### Priming 화면 (`notifications-priming.html`)

- **일러스트**: 벨 아이콘 (`bell.badge`), 골드
- **헤드라인**: 놓치지 말아야 할 소식
- **본문**: 내가 팔로우한 메이커의 신규 필터, 댓글 답글, 구매 완료 알림을 받아볼 수 있어요.
- **CTA Primary**: 알림 받기
- **CTA Ghost**: 나중에
- **힌트**: 언제든 설정에서 변경할 수 있어요.

**한국어 / 영어 메시지 초안**

| | 한국어 | 영어 |
|---|---|---|
| 헤드라인 | 놓치지 말아야 할 소식 | Stay in the Loop |
| 본문 | 팔로우한 메이커의 신규 필터와 댓글 답글을 알려드려요. | Get notified about new filters from makers you follow and replies to your comments. |
| Info.plist 문구 | filterMarket이 신규 필터 출시, 댓글 답글, 구매 업데이트 알림을 보냅니다. | filterMarket sends notifications for new filter releases, comment replies, and purchase updates. |

### iOS Info.plist

알림은 별도 plist 키가 없다. `UNUserNotificationCenter` API 로만 요청.

### 거부 시 Fallback (`notifications-denied.html`)

거부된 경우 앱 내 알림 센터(인앱 피드)로 대체 제공. 강요하지 않는다.

- **헤드라인**: 알림이 꺼져 있어요
- **본문**: 설정에서 언제든 다시 켤 수 있어요. 그동안 앱 내 알림 탭에서 소식을 확인할 수 있어요.
- **CTA Ghost**: 설정 열기 (강요하지 않으므로 secondary 처리)
- **CTA Ghost**: 괜찮아요

### SwiftUI 구현 의사코드

```swift
import UserNotifications

func requestNotificationPermission() async -> Bool {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()

    guard settings.authorizationStatus == .notDetermined else {
        return settings.authorizationStatus == .authorized
    }

    let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    return granted ?? false
}
```

---

## PF-04. 위치 권한 (EXIF 태그)

### 요청 시점

촬영 미리보기(05)에서 "위치 태그 포함" 옵션을 사용자가 처음 활성화할 때.
기본값은 **꺼짐**. 사용자가 명시적으로 켤 때만 요청.

```
[촬영 미리보기 05] → 위치 태그 토글 탭
    → 위치 권한 미승인 확인
        → [priming 화면: location-priming.html]
            → "허용" 탭
                → iOS 시스템 다이얼로그 (사용 중 허용)
                    → 승인 → 위치 EXIF 기록 활성화
                    → 거부 → [거부 안내 화면: location-denied.html]
```

> **`WhenInUse` 만 요청**: EXIF 태그는 촬영 순간(앱 사용 중)만 필요. `AlwaysAuthorization` 요청 금지. 백그라운드 위치 수집 금지.

### Priming 화면 (`location-priming.html`)

- **일러스트**: 위치 핀 아이콘 (`location.circle`), 골드
- **헤드라인**: 사진에 장소를 담기
- **본문**: 촬영한 사진에 위치 정보를 추가할 수 있어요. 위치는 사진 파일에만 저장되며 filterMarket 서버로 전송되지 않아요.
- **CTA Primary**: 허용
- **CTA Ghost**: 위치 없이 저장
- **힌트**: 위치 정보는 EXIF 형식으로 사진 파일에만 저장됩니다.

**한국어 / 영어 메시지 초안**

| | 한국어 | 영어 |
|---|---|---|
| 헤드라인 | 사진에 장소를 담기 | Tag the Place You Shot |
| 본문 | 촬영한 사진에 위치 정보를 추가할 수 있어요. 위치는 사진 파일에만 저장되며 서버로 전송되지 않아요. | Add location info to your photo as EXIF data. It's stored in the photo file only — never sent to our servers. |
| Info.plist 문구 | filterMarket이 촬영한 사진에 위치 태그(EXIF)를 추가합니다. 위치는 사진 파일에만 저장되며 수집되지 않습니다. | filterMarket adds location tags (EXIF) to photos you take. Location is stored in the photo file only, never collected. |

### iOS Info.plist

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>filterMarket이 촬영한 사진에 위치 태그(EXIF)를 추가합니다. 위치는 사진 파일에만 저장되며 수집되지 않습니다.</string>
```

### 거부 시 Fallback (`location-denied.html`)

- **헤드라인**: 위치 접근이 꺼져 있어요
- **본문**: 위치 없이 저장해도 좋아요. 나중에 설정에서 켤 수 있어요.
- **CTA Primary**: 위치 없이 저장 (주요 경로 — 거부해도 저장은 가능)
- **CTA Ghost**: 설정 열기

### SwiftUI 구현 의사코드

```swift
import CoreLocation

class LocationPermissionManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    func requestWhenInUse() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // 설정으로 안내
            showLocationDenied = true
        case .authorizedWhenInUse, .authorizedAlways:
            // 이미 승인됨
            break
        @unknown default:
            break
        }
    }
}
```

---

## 첫 요청 vs. 재요청

### 핵심 차이

iOS 는 각 권한 종류당 **시스템 다이얼로그를 한 번만** 표시한다.
한 번 거부하면 앱에서 `requestAuthorization` 을 재호출해도 다이얼로그가 뜨지 않는다.

| 상태 | 동작 |
|---|---|
| `.notDetermined` | `requestAuthorization` 호출 → 시스템 다이얼로그 표시 |
| `.authorized` | 바로 기능 사용 |
| `.denied` | 시스템 다이얼로그 재호출 불가 → **반드시 설정 앱으로 안내** |
| `.restricted` | 디바이스 정책(MDM 등)으로 금지됨 → 설정 변경 불가 안내 |

```swift
// 권한 상태 체크 유틸리티
func cameraAuthStatus() -> CameraPermissionState {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:     return .granted
    case .notDetermined:  return .notAsked
    case .denied:         return .denied   // → settings 안내
    case .restricted:     return .restricted
    @unknown default:     return .denied
    }
}
```

### 재요청 흐름 (설정 딥링크)

```swift
// 거부된 상태에서 설정으로 이동
func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
}
```

---

## 모범 사례 & 안티패턴

### 모범 사례

| 항목 | 설명 |
|---|---|
| 맥락 직전 요청 | 기능이 실제 필요한 시점에 요청 |
| Priming 필수 | 시스템 다이얼로그 전 항상 설명 화면 삽입 |
| 거부 존중 | 거부 후 재요청 팝업 반복 금지 |
| Add-Only 선호 | 사진 저장은 Full Access 대신 Add Only 로 충분 |
| 단계 안내 | 거부 후 설정 이동 방법을 1·2·3 단계로 명확히 표시 |
| 기능 분리 | 권한이 없어도 핵심 외 기능은 계속 동작 |

### 안티패턴

| 항목 | 설명 |
|---|---|
| 앱 실행 즉시 모든 권한 요청 | 맥락 없는 요청은 거부율을 높인다 |
| Priming 없는 시스템 다이얼로그 직접 호출 | 한 번의 기회를 낭비한다 |
| 거부 후 재요청 반복 | 사용자 경험을 해치고 앱 평가를 떨어뜨린다 |
| 불필요한 Always 위치 요청 | EXIF 태그는 WhenInUse 로 충분 |
| 거부 시 기능 완전 차단 | 가능한 한 fallback 경로 제공 |
| Info.plist 문구 부실 | Apple 심사 거절 사유 — 구체적 사용 목적 명시 필수 |

---

## 화면 ↔ 명세 매핑

| 파일명 | 명세 | 단계 |
|---|---|---|
| `permissions/camera-priming.html` | PF-01 카메라 | Priming |
| `permissions/camera-denied.html` | PF-01 카메라 | 거부 fallback |
| `permissions/photos-priming.html` | PF-02 사진 라이브러리 | Priming |
| `permissions/photos-denied.html` | PF-02 사진 라이브러리 | 거부 fallback |
| `permissions/notifications-priming.html` | PF-03 푸시 알림 | Priming |
| `permissions/notifications-denied.html` | PF-03 푸시 알림 | 거부 fallback |
| `permissions/location-priming.html` | PF-04 위치 EXIF | Priming |
| `permissions/location-denied.html` | PF-04 위치 EXIF | 거부 fallback |

---

> 관련 문서: [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md) · [`MOTION_SPEC.md §7 햅틱`](./MOTION_SPEC.md) · [`ARCHITECTURE.md`](./ARCHITECTURE.md)
