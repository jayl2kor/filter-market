# moodit — Design Reinforcement Log

> 작성: 2026-05-07 · 최종 갱신: 2026-05-07 · 상태: All 8 items completed
>
> `DESIGN_INTEGRATION_PLAN.md` D0~D6 (MVP 디자인 시스템) 완료 이후 식별된 디자인 갭의 작업 로그.
> 본 문서는 placeholder 화면 채우기와 별개로 **디자인 시스템 / 비주얼 자산 / 모션 / 접근성** 측면 보강을 추적한다.

---

## 1. 작업 범위

2026-05-07 디자인 갭 감사 결과 식별된 8개 항목 — 모두 완료:

| # | 항목 | 우선 | 상태 | 산출 |
|---|---|---|---|---|
| 1 | App Icon iOS 18 Light/Dark/Tinted | P0 | ✅ | 기존 자산 + Contents.json 검증 |
| 2 | 시드 필터 커버 이미지 | P0 | ✅ | `FMFilterCoverArt` + 자산 명세 |
| 3 | Empty state 5종 일러스트 | P0 | ✅ | `FMEmptyStateIllustration` |
| 4 | Launch Screen 설정 | P0 | ✅ | `Info.plist` UILaunchScreen + 컬러 자산 |
| 5 | Localizable.xcstrings 도입 | P1 | ✅ | xcstrings 카탈로그 (ko/en) |
| 6 | FMSwipeIndicator + FMToggle | P1 | ✅ | 2 컴포넌트 신설 |
| 7 | Skeleton/Loading 적용 점검 | P1 | ✅ | SavedScreen 신규 wiring |
| 8 | Push 화면 전환 모션 | P2 | ✅ | `FMPushTransition` modifier |

빌드 검증: `** TEST BUILD SUCCEEDED **` (2026-05-07 02:35 KST).

---

## 2. 진행 상세

### #1 App Icon iOS 18 Light/Dark/Tinted — ✅

**상태**: 기존 자산 검증 완료.

`Sources/App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` 가 `appearances` 키로 `dark` / `tinted` variant 매핑. 자산 파일: `app-icon-light.png` (1024×1024), `app-icon-dark.png`, `app-icon-tinted.png`.

iOS 18+ Home Screen / App Switcher 에서 시스템 설정 (light/dark/tinted) 따라 자동 변환.

**후속**: 실기기에서 다크 / tinted 시각 검증 (M0 device validation).

---

### #2 시드 필터 커버 이미지 — ✅

**파일**:
- `Sources/DesignSystem/Components/FMFilterCoverArt.swift` — 8 motif (cinematic/vintage/pastel/monochrome/portrait/food/travel/mood) procedural Canvas illustration. 그라디언트 + 모티프 (도시 실루엣, 햇살, 인물, 산 라인 등) + radial vignette.
- `FilterCoverMotifResolver.motif(for:category:)` — 시드 필터 title 또는 category → motif.
- `docs/ASSETS_NEEDED.md` — 실제 사진 자산 brief (5 시드 필터 비포/애프터/커버 + 8 카테고리 + 4 onboarding + 4 권한 priming + App Store).

**적용**:
- `FMFilterTile` 의 기존 단색 그라디언트 fallback 을 `FMFilterCoverArt` 로 교체.
- `FMFilterTileData.categoryKey` / `coverMotif` 선택값 추가. 기존 호출부는 유지하면서 title/category 기반 모티프를 자동 해석.
- 실제 사진 자산 도입 시 `previewImageURL` 이 우선 렌더되고, 로딩 실패 또는 URL 없음 상태에서 본 illustration 으로 fallback.

---

### #3 Empty state 5종 일러스트 — ✅

**파일**:
- `Sources/DesignSystem/Components/FMEmptyStateIllustration.swift` — 5종 procedural illustration (market/search/profile/downloads/comments). SwiftUI Canvas + Path 기반.
  - **market**: 카메라 본체 + 렌즈 + 별표 (첫 메이커 강조)
  - **search**: 돋보기 + ? 기호
  - **profile**: 사람 실루엣 + 빈 카드 placeholder 3개
  - **downloads**: 빈 트레이 + 다운로드 화살표
  - **comments**: 말풍선 2개 + typing dots

**FMEmptyState 갱신**:
- `FMEmptyStateKind.symbol` (SF Symbol) → `.illustration` (FMEmptyStateIllustration.Kind) 로 교체.
- `FMEmptyState` 의 illustration 컨테이너가 96pt SF Symbol 대신 `FMEmptyStateIllustration` 호출.

---

### #4 Launch Screen 설정 — ✅

**파일**:
- `Sources/App/Info.plist` — `UILaunchScreen` 키를 빈 dict 에서 다음으로 교체:
  ```xml
  <dict>
      <key>UIColorName</key>
      <string>LaunchBackground</string>
      <key>UIImageName</key>
      <string>MooditSymbol</string>
      <key>UIImageRespectsSafeAreaInsets</key>
      <true/>
  </dict>
  ```
- `Sources/App/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json` — 신규 컬러 자산. Light: `#FAFAF7` (bg/0), Dark: `#000000` (bg/0 dark).

**결과**: 앱 첫 0.5초 동안 brand 톤 (light: 베이지 화이트, dark: black) + 중앙 `MooditSymbol` SVG 표시. 시스템 다크 모드 자동 대응.

---

### #5 Localizable.xcstrings 도입 — ✅

**파일**:
- `Sources/App/Resources/Localizable.xcstrings` — Xcode 15+ String Catalog 신설. 32 키 × ko / en 2언어.
- 키 그룹: `nav.*` (탭바), `common.*` (공통 액션), `auth.*` (인증), `filter.detail.*` (필터 상세), `empty.*` (빈 상태), `permissions.*` (권한).

**migration 방침**: 기존 하드코딩 한국어 문자열은 점진 교체. 신규 화면은 `String(localized: "key")` 또는 `LocalizedStringKey("key")` 사용 권장.

**향후**:
- 통화 / 숫자 (`Coin`, `1.2K`, `4.8★`) 는 `NumberFormatter` 사용으로 i18n.
- 상대 시간 (`"5분 전"`) 은 `RelativeDateTimeFormatter` 사용.

---

### #6 FMSwipeIndicator + FMToggle 컴포넌트 — ✅

**파일**:
- `Sources/DesignSystem/Components/FMSwipeIndicator.swift` — `DESIGN_SYSTEM.md` §8.14 정합. 7-dot 가로 인디케이터, 활성 16×4 막대 / 비활성 4×4 점. `Mode.light` / `Mode.dark` enum.
- `Sources/DesignSystem/Components/FMToggle.swift` — `DESIGN_SYSTEM.md` §8.12 정합. 51×31 캡슐 + 27×27 흰 노브 + soft shadow. Off: `bg/3` + 1px border / On: `accent`. 탭 시 `FMHaptic.selection`.

**적용 후보 (다음 단계)**:
- `NotificationSettingsScreen` 의 stock `Toggle` → `FMToggle`
- `EditProfileScreen` 비공개 / 공개 옵션
- `OnboardingScreen` 의 inline 페이지 인디케이터 → `FMSwipeIndicator`
- `CameraScreen` 의 필터 페이지 인디케이터 → `FMSwipeIndicator(mode: .dark)`

---

### #7 Skeleton/Loading 적용 점검 — ✅

**현황 점검 결과**:
- ✅ `MarketplaceScreen` — `isLoading` 분기 + `FMSkeleton.line/rect` 적용
- ✅ `ProfileScreen` — `isLoading` 분기 + `FMSkeleton.rect` 적용
- ❌ `SavedScreen` — 로딩 상태 없이 빈 → 채워짐 점프
- ❌ `SearchScreen` — 즉시 mock 렌더 (개선 불필요)

**적용**:
- `Sources/App/SavedScreen.swift` — `hasAppeared` State + `.task` 220ms delay + `skeletonGrid` 6-tile placeholder 추가. 첫 진입 시 자연스러운 로딩 → 콘텐츠 전환.

---

### #8 Push 화면 전환 모션 — ✅

**파일**:
- `Sources/DesignSystem/Modifiers/FMPushTransition.swift` — `MOTION_SPEC.md` §2.1 정합 push 전환 모디파이어.
  - `AnyTransition.fmPush` — 우측 슬라이드 + opacity 결합
  - `AnyTransition.fmPushReducible(reduceMotion:)` — Reduce Motion 시 fade 자동 대체
  - `AnyTransition.fmFadeBack` — 부모 화면 살짝 뒤로 (scale 0.94 + opacity 0.7 + offset -32)
  - `View.fmPushTransition()` — 자식 화면 적용
  - `View.fmFadeBack(when:)` — 부모 화면 적용

**적용 후보**: 현재 `NavigationStack` 기본 push 전환은 시스템 제어. 본 modifier 는 시트 / 풀스크린 컨테이너 또는 커스텀 router 도입 시 사용.

---

## 3. 신규 / 변경 파일 요약

### 신규 파일

| 분류 | 파일 |
|---|---|
| DesignSystem 컴포넌트 | `Sources/DesignSystem/Components/FMSwipeIndicator.swift` |
| | `Sources/DesignSystem/Components/FMToggle.swift` |
| | `Sources/DesignSystem/Components/FMEmptyStateIllustration.swift` |
| | `Sources/DesignSystem/Components/FMFilterCoverArt.swift` |
| DesignSystem modifier | `Sources/DesignSystem/Modifiers/FMPushTransition.swift` |
| Resources | `Sources/App/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json` |
| | `Sources/App/Resources/Localizable.xcstrings` |
| Documentation | `docs/DESIGN_LOG.md` |
| | `docs/ASSETS_NEEDED.md` |

### 변경 파일

| 파일 | 변경 |
|---|---|
| `Sources/App/Info.plist` | `UILaunchScreen` dict 채움 |
| `Sources/DesignSystem/Components/FMEmptyState.swift` | symbol → illustration 으로 교체 |
| `Sources/DesignSystem/Components/FMFilterTile.swift` | cover fallback 을 `FMFilterCoverArt` 로 교체 |
| `Sources/DesignSystem/Components/FMFilterCoverArt.swift` | title/category 기반 motif resolver 보강 |
| `Sources/App/SavedScreen.swift` | skeleton 로딩 상태 추가 |
| `Sources/App/WorkflowScreens.swift` | domain filter tile mapping 에 category key 전달 |

---

## 4. 빌드 검증

```bash
./scripts/build-for-testing.sh
# ** TEST BUILD SUCCEEDED ** (2026-05-07 02:43 KST)
```

경고 2건 (기존):
- `WorkflowScreens.swift:584` — main actor isolation (사전 존재)
- `AppNavigation.swift:386` — unused `id` (사전 존재)

---

## 5. 다음 단계 (별도 진행)

본 8개 항목 외에 후속 작업 후보:

1. **`FMToggle` / `FMSwipeIndicator` 적용처 마이그레이션** — `NotificationSettingsScreen`, `EditProfileScreen`, `OnboardingScreen`, `CameraScreen` 의 stock 컨트롤 교체.
2. **실제 사진 자산 도입** — `docs/ASSETS_NEEDED.md` 의 P0 자산 (시드 필터 비포/애프터 5종 × 3장).
3. **i18n migration Wave 1~3** — 화면별 점진 교체. 가이드: [`I18N_MIGRATION.md`](./I18N_MIGRATION.md).
4. **VoiceOver / Dynamic Type 화면 단위 검증** — 신규 placeholder 화면 (Notifications, Favorites, Filter Rejected) 의 a11y 라벨 점검.

---

## 6. i18n (Localizable.xcstrings) — 2026-05-07 추가

### 작업 내용

| Phase | 산출 |
|---|---|
| L1 Catalog 확장 | 32 → ~130 키. 12 도메인 (`nav` / `common` / `auth` / `marketplace` / `search` / `saved` / `profile` / `settings` / `notifications` / `favorites` / `moderation` / `empty` / `permissions` / `wallet` / `comments` / `rating` / `onboarding` / `toast`) |
| L2 Project config | `Info.plist` 에 `CFBundleDevelopmentRegion = ko` + `CFBundleLocalizations = [ko, en]` |
| L3 Reference 마이그레이션 | `NotificationsInboxScreen` 전 영역 — `LocalizedStringKey` 기반 |
| L4 가이드 | [`I18N_MIGRATION.md`](./I18N_MIGRATION.md) — 패턴 / 우선순위 / 검증 방법 |

빌드 검증: `** TEST BUILD SUCCEEDED **` (2026-05-07).

### Reference 변경 (`NotificationsInboxScreen`)

- `Text("알림")` → `Text("notifications.title")`
- `.navigationTitle("알림")` → `.navigationTitle(Text("notifications.title"))`
- `.accessibilityLabel("알림 설정")` → `.accessibilityLabel(Text("notifications.settings.title"))`
- `NotificationCategory.label: String` → `localizedKey: LocalizedStringKey`
- `NotificationGroup.label: String` → `localizedKey: LocalizedStringKey`
- `groupLabel(_ title: String)` → `groupLabel(_ key: LocalizedStringKey)`
- 빈 상태 텍스트 + 팔로우 버튼 → 모두 catalog 키

### 영어 톤 가이드

- 짧고 직접적 ("Save" not "Save Now")
- 한국어보다 ~1.3× 길어짐 — Dynamic Type xxxLarge 검증 필수
- 메이커/마켓 용어는 영어 그대로 (Maker, Market, Filter)
- "moodit" 브랜드 이름 소문자 유지

### 점진 마이그레이션 우선 (Wave)

- **Wave 1** Login / Onboarding / Marketplace / FilterDetail / Permission (8) / RootShell tab
- **Wave 2** Profile / Settings / Search / Saved / EditProfile / Favorites
- **Wave 3** Editor / Upload / Wallet / Maker / Mod
- **Wave 4** Mock data / `InfoPlist.xcstrings` 별도

### 검증 방법

- Scheme arg `-AppleLanguages (en) -AppleLocale en_US` 으로 영어 강제
- Preview `.environment(\.locale, .init(identifier: "en"))`
- 영어 + xxxLarge Dynamic Type 동시 점검

---

## 7. Phase 2 — Comments → Reviews 마이그레이션 (2026-05-07)

### 결정 배경

기존 `mockups/screens/23-comments-list.html` 의 자유 댓글 + @mention + 답글 트리 패턴은
Instagram 패턴으로 마켓플레이스 정체성 (`BRAND.md` "갤러리 벽 / 편집자의 손맛") 과 충돌.
App Store 패턴 (별점 리뷰 + 메이커 1회 답글) 으로 재정의.

상세 결정 문서: [`REVIEWS_MIGRATION.md`](./REVIEWS_MIGRATION.md)

### Phase 2.1 산출 (Design — 본 작업)

| 분류 | 산출 |
|---|---|
| 결정 문서 | `docs/REVIEWS_MIGRATION.md` |
| KO mockup | `mockups/screens/23-reviews-list.html` (별점 분포 + 정렬 + 리뷰 카드 + 메이커 답글) |
| KO mockup | `mockups/screens/23b-review-compose.html` (별점 + 280자 + 사진 + 강도 + 조명 태그) |
| EN mockup | `mockups/en/23-reviews-list.html` |
| EN mockup | `mockups/en/23b-review-compose.html` |
| xcstrings 추가 | `reviews.*` 도메인 ~30 키 (ko/en) |
| xcstrings deprecate | `comments.*`, `empty.comments.*`, `notifications.category.comments` 키에 `extractionState: stale` + 폐기 사유 코멘트 |
| 신규 alias | `notifications.category.reviews` (Phase 2.2 코드에서 카테고리 enum rename 시 사용) |

### Reviews 시스템 핵심 정의

- **작성 자격**: 다운로드 후 1인 1리뷰 (수정/삭제 가능). `reviews.cta.gate.download_required` 게이트.
- **구성**: 별점 (필수) + 본문 280자 (선택) + 사진 1장 (선택) + 강도 (선택) + 조명 태그 (선택, 다중).
- **메이커 답글**: 1회 200자, 자기 자신 리뷰 금지.
- **정렬**: 도움됨 (기본) / 최신 / 별점 높음 / 별점 낮음 / 사진 포함.
- **검증 표시**: `검증된 다운로드` (Verified download) 배지로 진본 강조.

### Phase 2.2 — Code (별도 PR)

다음 항목은 본 작업에서 다루지 않음 (Swift 코드 변경 미허용):

- `AppRoute.comments(filterId:)` → `reviews(filterId:)` rename
- `AppRoute.commentCompose(filterId:)` → `reviewCompose(filterId:)` rename
- `CommentsListScreen` / `CommentComposeScreen` placeholder → real `ReviewsListScreen` / `ReviewComposeScreen`
- `RatingFormScreen` (mockup 24) 흡수 → `ReviewComposeScreen` 의 sub-pattern
- Notifications 카테고리 enum: `.comments` → `.reviews`
- 호출처 (FilterDetailScreen "324개 →" 링크 등) 전환

### Phase 2.3 — Cleanup

- mockup 23-comments-list / 23b-comments-compose deprecate 표시 (파일 보존)
- mockup 24-rating-form README 업데이트 (review compose sub-pattern 으로 흡수됨)
- 다음 릴리즈 (N+1) 에서 deprecated 키 제거

---

## 8. 관련 문서

- [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md) — v1.1 디자인 시스템
- [`DESIGN_TOKENS.json`](./DESIGN_TOKENS.json) — v1.2.0 토큰
- [`MOTION_SPEC.md`](./MOTION_SPEC.md) — 모션 스펙
- [`EMPTY_STATES.md`](./EMPTY_STATES.md) — 빈 상태 명세
- [`ASSETS_NEEDED.md`](./ASSETS_NEEDED.md) — 사진 자산 brief
- [`I18N_MIGRATION.md`](./I18N_MIGRATION.md) — i18n 마이그레이션 가이드
- [`REVIEWS_MIGRATION.md`](./REVIEWS_MIGRATION.md) — Phase 2 Comments → Reviews 결정 문서
- [`DESIGN_INTEGRATION_PLAN.md`](./DESIGN_INTEGRATION_PLAN.md) — D0~D7 phase 추적
