# moodit — i18n Migration Guide

> 작성: 2026-05-07 · 상태: ko (source) + en (translation) Active
>
> Korean → Korean+English 다국어 지원 구축 가이드. 패턴, 예제, 점진 마이그레이션 절차.

---

## 1. 현황

| 항목 | 상태 |
|---|---|
| String Catalog | `Sources/App/Resources/Localizable.xcstrings` (~130 키) |
| Source language | `ko` (`CFBundleDevelopmentRegion=ko`) |
| Supported languages | `ko`, `en` (`CFBundleLocalizations`) |
| Reference 마이그레이션 | `NotificationsInboxScreen` |

---

## 2. 키 명명 규칙

```
{domain}.{screen}.{element}
```

예시:
- `nav.market` — 탭바 마켓 라벨
- `common.save` — 공통 저장 CTA
- `notifications.category.all` — 알림 카테고리 (전체)
- `empty.search.title` — 빈 검색 결과 타이틀
- `permissions.camera.body` — 카메라 권한 설명

도메인 prefix:
- `nav` / `common` — 글로벌
- `auth`, `marketplace`, `search`, `saved`, `profile`, `settings`,
  `notifications`, `favorites`, `moderation`, `wallet`, `comments`,
  `rating`, `onboarding` — 화면별
- `empty` — 빈 상태
- `permissions` — 권한 흐름
- `toast` — 토스트 메시지
- `filter.detail.*` — 필터 상세

---

## 3. 코드 사용 패턴

### 3.1 SwiftUI `Text()` — `LocalizedStringKey` 자동 변환

```swift
// 가장 권장 — Text(_ key: LocalizedStringKey)
Text("notifications.title")
Text("common.save")

// navigationTitle / accessibilityLabel — Text 명시 권장
.navigationTitle(Text("notifications.title"))
.accessibilityLabel(Text("notifications.settings.title"))
```

### 3.2 동적 보간 (substitution)

```swift
// xcstrings — value: "\"%@\"에 맞는 필터가 없어요"
Text("empty.search.title \(query)")
// 또는 String(localized:)
String(localized: "empty.search.title \(query)")
```

xcstrings 의 placeholder 는 `%@` (String) / `%lld` (Int) / `%lf` (Double).

### 3.3 ViewModel / 비-View 코드

```swift
// LocalizedStringResource — Text 가 아닌 곳에서 사용
let title = String(localized: "notifications.title")

// 또는
let title = LocalizedStringResource("notifications.title")
let stringValue = String(localized: title)
```

### 3.4 enum / model 의 표시 텍스트

`label: String` → `localizedKey: LocalizedStringKey` 로 교체. 호출처에서
`Text(value.localizedKey)` 로 사용.

```swift
// Before
enum Category {
    var label: String {
        switch self { case .all: "전체" ... }
    }
}
Text(category.label)

// After
enum Category {
    var localizedKey: LocalizedStringKey {
        switch self { case .all: "notifications.category.all" ... }
    }
}
Text(category.localizedKey)
```

비-View 컨텍스트 (예: 정렬 / 검색용 String 비교) 가 필요하면 두 프로퍼티 병행:

```swift
var localizedKey: LocalizedStringKey { ... }
var localizedString: String { String(localized: localizedKey) }
```

### 3.5 동적 단위 / 포맷

| 종류 | 사용 |
|---|---|
| 통화 (Coin) | `String(localized: "wallet.coin_unit \(amount)")` 또는 `NumberFormatter` |
| 다운로드 수 | `String(localized: "filter.detail.downloads_count \(formatted)")` |
| 상대 시간 (`5분 전`) | `RelativeDateTimeFormatter()` (시스템 자동 i18n) |
| 별점 | `Text(verbatim: "★ \(rating)")` (verbatim — 번역 X) |

---

## 4. Reference 화면: NotificationsInboxScreen

`Sources/App/Notifications/NotificationsInboxScreen.swift` — 본 마이그레이션의 reference.

**변경 요약**:
- `.navigationTitle("알림")` → `.navigationTitle(Text("notifications.title"))`
- `.accessibilityLabel("알림 설정")` → `.accessibilityLabel(Text("notifications.settings.title"))`
- `Text(value.label)` → `Text(value.localizedKey)` (label String → localizedKey LocalizedStringKey)
- `Text("표시할 알림이 없어요")` → `Text("notifications.empty.title")`
- `Text("팔로우")` → `Text("profile.follow")`
- `groupLabel(_ title: String)` → `groupLabel(_ key: LocalizedStringKey)`
- `NotificationCategory.label` → `localizedKey`
- `NotificationGroup.label` → `localizedKey`
- `NotificationGroupBucket.label` → `localizedKey`

(Mock data 의 `body: AttributedSegments` 같은 진짜 콘텐츠는 별도 — API 응답 시 i18n 은 백엔드 책임.)

---

## 5. 점진 마이그레이션 우선순위

### Wave 1 — Critical (반드시 i18n 필요)

| 화면 | 사유 |
|---|---|
| LoginScreen / SignupScreen | 첫 진입 |
| OnboardingScreen | 첫 진입 |
| MarketplaceScreen | 메인 |
| FilterDetailScreen | 핵심 사용 흐름 |
| Permission priming/denied (8) | 사용자 결정 화면 |
| RootShell 탭바 | ✅ 이미 키 존재 (적용만 남음) |

### Wave 2 — Standard

| 화면 | 사유 |
|---|---|
| NotificationsInboxScreen | ✅ Done (reference) |
| ProfileScreen | 자주 사용 |
| SettingsScreen | 자주 사용 |
| SearchScreen | 자주 사용 |
| SavedScreen | 자주 사용 |
| EditProfileScreen | 가입 후 |
| FavoritesCollectionScreen | 컬렉션 |

### Wave 3 — Lower priority

- WorkflowScreens.swift (Editor / Upload / Wallet / Maker / Mod) — 기능 채택률 후 진행

### Wave 4 — Edge

- Mock 데이터 (`MarketplaceMockData`, `FilterDetailMock`) — production data 도입 시 영어 응답 가정.
- `Info.plist` `NSCameraUsageDescription` 등 — 자동 영어 변환은 `InfoPlist.xcstrings` 별도 catalog 필요.

---

## 6. 검증 방법

### 6.1 Scheme 인자로 영어 미리보기

`Edit Scheme` → `Run` → `Arguments Passed On Launch` 에 추가:

```
-AppleLanguages (en)
-AppleLocale en_US
```

런타임에 영어로 강제 동작.

### 6.2 SwiftUI Preview 에서 영어 미리보기

```swift
#Preview("English") {
    NotificationsInboxScreen()
        .environment(\.locale, .init(identifier: "en"))
        .environmentObject(MooditStore())
}
```

### 6.3 Dynamic Type + 영어 동시 검증

```swift
#Preview("EN xxxLarge") {
    SomeScreen()
        .environment(\.locale, .init(identifier: "en"))
        .dynamicTypeSize(.xxxLarge)
}
```

영어가 한국어보다 일반적으로 ~1.3× 길이가 늘어나므로 layout 깨짐 점검 필수.

---

## 7. 자주 묻는 질문

**Q. `LocalizedStringKey` 와 `String(localized:)` 차이?**
A. SwiftUI `Text()` 는 `LocalizedStringKey` 를 받고 자동 변환. 그 외 (logic 코드, 문자열 비교, alert title) 는 `String(localized:)` 사용.

**Q. xcstrings 키가 늘어나면 관리가 어렵지 않나요?**
A. Xcode 의 String Catalog 편집기로 검색 / 그룹 보기 가능. 사용처 자동 추적 (Xcode 15+).

**Q. `Localizable.xcstrings` 가 자동 생성 / 추출 되나요?**
A. Xcode 가 `extractionState: "extracted_with_value"` 로 자동 추출. 본 프로젝트는 `manual` 표시 (수동 작성). Xcode 빌드 시 누락 키 자동 추가.

**Q. 영어 번역이 어색한데 누가 검수?**
A. 본 카탈로그는 1차 draft. native English speaker 검수 필요 (특히 marketing tone).

---

## 8. 관련 문서

- [DESIGN_LOG.md](./DESIGN_LOG.md) — 디자인 보강 로그
- [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) — 디자인 시스템 v1.1
- [Localizable.xcstrings](../Sources/App/Resources/Localizable.xcstrings) — String Catalog
- Apple [WWDC23 Discover String Catalogs](https://developer.apple.com/wwdc23/10155)
