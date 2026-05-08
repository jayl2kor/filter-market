# moodit - Design Integration Plan

> **Legacy**: 이 문서는 초기 HTML mockup → SwiftUI 디자인 통합 계획 기록이다.  
> 현재 디자인 변경 이력은 [`DESIGN_LOG.md`](./DESIGN_LOG.md), 현재 진행 상태는 [`PHASE_ROADMAP_STATUS.md`](./PHASE_ROADMAP_STATUS.md)를 기준으로 한다.

> 버전: v1.0 · 작성일: 2026-05-06 · 상태: Active
>
> 이 문서는 `mockups/` HTML 디자인과 `docs/DESIGN_*.md` 디자인 시스템을 실제 SwiftUI 프로젝트(`Sources/`)에 적용하는 단계별 계획이다.

---

## 1. 배경과 목표

### 1.1 현재 상태 (2026-05-06 기준)

**디자인 자산** (`mockups/`, `docs/DESIGN_*.md`)
- 화면 12 핵심 + 카탈로그 1 + 권한 8 + 모달 4 = HTML 목업 25
- 보강 가이드 4: `MOTION_SPEC`, `EMPTY_STATES`, `PERMISSIONS_FLOW`, `MODAL_PATTERNS`
- `DESIGN_TOKENS.json` v1.2.0 — 라이트/다크 듀얼 + interaction/state/disabled/z 토큰
- 5탭 + 중앙 셔터 패턴 (마켓 / 검색 / **카메라(셔터)** / 저장됨 / 프로필)

**프로젝트 현황** (`Sources/`)
- iOS 17+ Swift 6, SwiftUI 기반 모듈 분리
- 모듈: `App`, `Camera`, `FilterEngine`, `Marketplace`, `Storage`, `Models`, `DesignSystem`, `Auth`
- `Sources/DesignSystem/DesignTokens.swift` 초안 (제 v1.2와 미정합)
- `RootShell.swift`에 4탭 셸 (`Camera / Filters / Market / Profile`)
- Camera + Metal 파이프라인 PoC 거의 완료, 실기기 검증 대기
- 마켓/프로필/검색/설정 화면 placeholder 상태

### 1.2 목표

1. 디자인 시스템 v1.2 → SwiftUI에서 1급 시민으로 사용
2. 12개 화면 + 보강 화면 → 실제 SwiftUI 화면 구현
3. 5탭 + 중앙 셔터 패턴 → 앱 셸 적용
4. 권한/모달/상태 표준화 (재사용 가능한 컴포넌트)
5. 모션/햅틱 → DesignSystem 모듈에 토큰화

---

## 2. 격차 분석

| 영역 | 디자인 (현재) | 프로젝트 (현재) | 작업 |
|---|---|---|---|
| 토큰 | v1.2 듀얼 모드 + 상태 토큰 | 초안만 | 정합화 (Phase D0) |
| 탭 구조 | 5탭 + 중앙 셔터 | 4탭 (Camera/Filters/Market/Profile) | 재구성 (Phase D2) |
| 마켓/프로필/검색/설정 | 풀 디자인 | placeholder 화면 | UI 구현 (Phase D3) |
| 카메라 흐름 | 다크 풀스크린 + HUD | 부분 구현, 폴리시 필요 | 시각 통합 (Phase D4) |
| 권한 화면 | 8개 priming/denied | 없음 | 신규 (Phase D5) |
| 모달/상태/시머/토스트 | 명세 + 목업 | 없음 | 컴포넌트 + 적용 (Phase D6) |
| 컴포넌트 (Button/Card/Tile/...) | HTML/CSS | SwiftUI 미작성 | 라이브러리 (Phase D1) |
| 모션 | `MOTION_SPEC.md` | 없음 | Animation enum + 적용 (Phase D6) |

---

## 3. 단계별 계획

### Phase D0 — 토큰·디자인시스템 동기화 (1일)

**목표**: `DESIGN_TOKENS.json` v1.2 → SwiftUI에서 `Color.bg0`, `Sp.md`, `Animation.fmEaseOut` 등 사용 가능

**작업**
1. `Sources/DesignSystem/`에 토큰 파일 분리:
   - `Colors.swift` — 라이트/다크 듀얼, `Color(light:dark:)` 헬퍼
   - `Typography.swift` — Display/Title/Body 9단계 + Weight enum
   - `Spacing.swift` — `Sp.xxs ... Sp.4xl`
   - `Radius.swift` — `R.sm/md/lg/xl/full`
   - `Motion.swift` — `Animation.fmEaseOut`, `.fmSpring` 등 + cubic-bezier 값
   - `Iconography.swift` — 아이콘 사이즈 enum + SF Symbols 매핑
   - `State.swift` — interaction/disabled/skeleton 알파
   - `ZIndex.swift` — modal/popover/toast 레이어
2. Asset Catalog `Sources/App/Resources/Assets.xcassets/Colors/` — 컬러마다 라이트/다크 variant
3. (선택) `tools/generate-tokens.swift` — JSON → Swift 변환 자동화

**검증**
- `Color.bg0`, `Sp.md` 등이 모든 모듈에서 import 가능
- 라이트/다크 자동 전환 (시스템 또는 `.preferredColorScheme(.dark)`)
- 기존 `DesignTokens.swift`의 사용처가 새 API로 마이그레이션됨

**의존성**: 없음 (독립 시작)

---

### Phase D1 — 컴포넌트 라이브러리 (2~3일)

**목표**: HTML 컴포넌트 → SwiftUI 재사용 가능 View. 모든 후속 화면이 이 라이브러리를 활용.

**컴포넌트 (우선순위 순)**

| 순서 | 컴포넌트 | 변형 |
|---|---|---|
| 1 | `FMButton` | primary / secondary / ghost / destructive × sm/md/lg + loading |
| 2 | `FMCard` | 흰 fill + subtle border + soft shadow |
| 3 | `FMTextField` | outlined + focus 골드 ring + error 상태 |
| 4 | `FMTag`, `FMChip` | 카테고리 / 트렌딩 / 필터 |
| 5 | `FMSlider` | 강도 조절 (이미 있을 수 있음 — 통합) |
| 6 | `FMToast`, `FMBanner` | success/warning/error/info 4 variants |
| 7 | `FMSkeleton` | 시머 애니메이션 1.5s 사이클 |
| 8 | `FMEmptyState` | 5종 빈 상태 + SVG 일러스트 |
| 9 | `FMTabBar` | 5탭 + 중앙 셔터 56px lift -12px |
| 10 | `FMSegmentedControl` | iOS 표준 + 골드 강조 |
| 11 | `FMAvatar` | 원형 + 사이즈 4단계 + placeholder |
| 12 | `FMFilterTile` | 마켓 그리드용, 비포/애프터 mini |

**산출**
- `Sources/DesignSystem/Components/*.swift` 약 12~15 파일
- 각 컴포넌트 `#Preview` — 모든 상태/사이즈 변형

**검증**
- Light/Dark mode 모두 정상
- Dynamic Type xxxLarge에서 깨지지 않음
- VoiceOver 라벨 적용

**의존성**: D0 (토큰 필요)

---

### Phase D2 — 5탭 셸 재구성 (0.5일)

**목표**: 4탭 → 5탭 (마켓 / 검색 / **카메라(셔터)** / 저장됨 / 프로필)

**작업**
1. `Sources/App/RootShell.swift` 변경:
   - 기존 `Camera` 탭 → 중앙 셔터로 이동
   - `Filters` 탭 → `Saved (저장됨)` 탭으로 변경 (저장된 필터 + 다운로드)
   - `Search` 탭 신규 추가
2. `FMTabBar` 컴포넌트 적용
3. 셔터 탭 → `CameraScreen` full-screen present (`.fullScreenCover`)
4. 다른 4탭은 각자 `NavigationStack` 안에서 푸시

**검증**
- 5탭 모두 탭 가능, 활성 상태 시각 표시
- 셔터 탭 → 카메라 풀스크린 → dismiss → 원래 탭 복귀
- 라이트 모드에서 마진/색 정상

**의존성**: D1의 `FMTabBar`

---

### Phase D3 — 메인 화면 마이그레이션 (3~4일)

HTML 목업 → SwiftUI 화면. 각 화면당 0.5~1일.

| 순서 | 화면 | 우선 이유 |
|---|---|---|
| 1 | **02 Login** | 신규 사용자 진입점, AuthPlaceholder 대체 |
| 2 | **06 Marketplace Home** | 핵심 경험, placeholder 대체 |
| 3 | **07 Filter Detail** | 마켓 클릭 다음 페이지 |
| 4 | **09 Profile** | placeholder 대체 |
| 5 | **08 Search** | 신규 |
| 6 | **10 Settings** | 신규 |
| 7 | **01 Onboarding** | 첫 사용자만 보지만 첫인상 |
| 8 | **05 Capture Preview** | 촬영 후 결과 시트 강화 |

**각 화면당 작업**
- 정적 SwiftUI 뷰 작성 (Mock 데이터 → `Preview`)
- ViewModel 분리 (Observable 또는 `@Observable`)
- 기존 Repository / UseCase와 연결
- Preview 변형: 정상 / 빈 / 로딩 / 에러
- VoiceOver 라벨

**의존성**: D1 (컴포넌트), D0 (토큰)

---

### Phase D4 — 카메라 화면 다크 통합 (1일)

**목표**: 03/04/05 카메라 흐름 디자인 → 기존 `CameraScreen`에 적용

이미 코드는 있고 시각 폴리시만:
- 03 Camera Live: 컨트롤 위치/크기 디자인 일치
- 04 Filter Swipe: 캐러셀 인디케이터 + 강도 슬라이더 시각
- 05 Capture Preview: 결과 시트 풀스크린화
- 04 좌우 스와이프 → `MOTION_SPEC.md` §4 따름 (snap 350ms spring)

**조건**
- 카메라 로직 (Metal 파이프라인, AVFoundation)은 건드리지 않음
- 시각만 변경

**의존성**: D1 (컴포넌트), D6 (모션)

---

### Phase D5 — 권한 흐름 구현 (1.5일)

**목표**: priming → 시스템 다이얼로그 → denied 화면 흐름

**작업**
1. `Sources/App/Permissions/` 신설:
   - `CameraPermissionPriming.swift`, `CameraPermissionDenied.swift`
   - `PhotosPermissionPriming.swift`, `PhotosPermissionDenied.swift`
   - `NotificationsPermissionPriming.swift`, `NotificationsPermissionDenied.swift`
   - `LocationPermissionPriming.swift`, `LocationPermissionDenied.swift` (선택)
2. `Info.plist` 키 추가:
   - `NSCameraUsageDescription`
   - `NSPhotoLibraryUsageDescription`
   - `NSPhotoLibraryAddUsageDescription`
   - `NSLocationWhenInUseUsageDescription` (선택)
3. priming → `requestAccess` → 결과 분기 코디네이터
4. denied 화면 "설정 열기" → `UIApplication.openSettingsURLString`

**참조**: `docs/PERMISSIONS_FLOW.md`

**의존성**: D1 (컴포넌트)

---

### Phase D6 — 모달/상태/모션 적용 (1.5일)

**목표**: 4 보강 가이드를 코드로

1. **모달**: `MODAL_PATTERNS.md` → SwiftUI `.sheet`/`.confirmationDialog`/`.alert`/`ShareLink` 표준화
2. **빈 상태**: `EMPTY_STATES.md` → `FMEmptyState` 5변형 적용 위치 통합
3. **모션**: `MOTION_SPEC.md` → `Animation` enum 토큰 (`.fmEaseOut`, `.fmSpring`)
4. **햅틱**: `HapticEngine` wrapper — `light/medium/heavy/success/warning/error/selection` 메서드

**검증**
- Reduce Motion 시스템 설정 시 변환 → 페이드 자동 대체
- 햅틱이 실기기에서 의도대로 작동

**의존성**: D1, D2

---

### Phase D7 — Phase 2 화면 (3~4일, 선택)

**제외 가능 — MVP 외 범위**

- 11 Filter Editor — 파라미터 슬라이더 패널
- 12 Upload Flow — 3단계 스테퍼 + 약관 + 검수 제출
- 메이커 워크플로우 시작

**의존성**: D1, D3

---

## 4. 일정

| Phase | 작업 | 일수 | 누적 |
|---|---|---|---|
| D0 | 토큰 동기화 | 1 | 1일 |
| D1 | 컴포넌트 라이브러리 | 3 | 4일 |
| D2 | 5탭 셸 재구성 | 0.5 | 4.5일 |
| D3 | 메인 화면 8개 | 4 | 8.5일 |
| D4 | 카메라 화면 폴리시 | 1 | 9.5일 |
| D5 | 권한 흐름 | 1.5 | 11일 |
| D6 | 모달/상태/모션 | 1.5 | 12.5일 |
| D7 | Phase 2 화면 (선택) | 3 | 15.5일 |

**MVP 범위 (D0~D6)**: 약 **2~3주** (1인 작업 기준)
**Phase 2 포함 (D0~D7)**: 약 3~4주

---

## 5. 위험 / 완화

| 위험 | 점수 | 완화 |
|---|---|---|
| 기존 Asset Catalog 라이트/다크 variant 누락 | 9 | D0 끝에 모든 컬러 두 모드 모두 검증 |
| Dynamic Type xxxLarge 시 레이아웃 깨짐 | 9 | 컴포넌트마다 dynamicTypeSize Preview |
| Phase 2 화면 (에디터/업로드) 복잡도 | 12 | D7로 분리, MVP 외 |
| 모션 토큰이 실기기 성능 저하 유발 | 6 | D4/D6에서 60FPS 모니터링 |
| `Sources/DesignSystem/DesignTokens.swift` 기존 호출 부분 마이그레이션 누락 | 9 | D0에서 grep으로 모든 사용처 확인, alias 잠시 유지 |

---

## 6. 산출물 요약

### 코드
- `Sources/DesignSystem/{Colors, Typography, Spacing, Radius, Motion, ...}.swift`
- `Sources/DesignSystem/Components/FM*.swift` (12~15 파일)
- `Sources/App/RootShell.swift` (5탭 재구성)
- `Sources/App/{Login, Marketplace, FilterDetail, Search, Profile, Settings, Onboarding, CapturePreview}/*.swift`
- `Sources/App/Permissions/*.swift`
- `Sources/App/Resources/Assets.xcassets/Colors/`

### 문서
- 본 문서 (`DESIGN_INTEGRATION_PLAN.md`)
- 각 Phase 종료 시 상태 업데이트 (체크리스트)

### 추적
- GitHub Issues — D0~D7을 마일스톤 또는 라벨로
- 기존 `IMPLEMENTATION_PLAN.md`의 라벨 체계와 정합

---

## 7. 진행 추적

| Phase | 상태 | 시작일 | 완료일 | 비고 |
|---|---|---|---|---|
| D0 | ✅ Done | 2026-05-06 | 2026-05-06 | `Sources/DesignSystem/Tokens/` 8개 파일 + 레거시 `DesignTokens.swift` deprecated alias 유지. Asset Catalog 미채택 — `Color(light:dark:)` 코드 정의로 JSON 과 1:1 정합. |
| D1 | ✅ Done | 2026-05-06 | 2026-05-06 | `Sources/DesignSystem/Components/` 12 컴포넌트 (`FMButton`, `FMCard`, `FMTextField`, `FMTag`/`FMChip`, `FMSlider`, `FMToast`/`FMBanner`, `FMSkeleton`, `FMEmptyState`, `FMTabBar`, `FMSegmentedControl`, `FMAvatar`, `FMFilterTile`) + 타이포그래피 단축 alias. Light/Dark + Dynamic Type Preview 포함. |
| D2 | ✅ Done | 2026-05-06 | 2026-05-06 | `RootShell` 5탭 + 중앙 셔터 ZStack 셸 (`FMTabBar` 적용). `SearchScreen` / `SavedScreen` placeholder 신규. `FilterLibraryScreen` 제거. `CameraScreen` `.fullScreenCover` 진입 + 닫기 버튼 + 다크 강제. 진입 화면 마켓으로 변경. |
| D3 | ✅ Done (8/8) | 2026-05-06 | 2026-05-06 | Batch 1: `LoginScreen` (02), `MarketplaceScreen` (06), `FilterDetailScreen` (07). Batch 2: `ProfileScreen` (09), `SettingsScreen` (10), `SearchScreen` (08). Batch 3: `OnboardingScreen` (01) — `Sources/App/Onboarding/` 신설, 4 페이지 swipe 캐러셀 (`TabView .page`) + 카드-스택 일러스트 + 페이지 인디케이터 (활성 골드 capsule) + 건너뛰기/다음·시작하기 CTA + `@AppStorage("hasOnboarded")` 통합 (MooditApp `.fullScreenCover`); `CapturePreviewScreen` (05) — `Sources/App/Camera/` 신설, 다크 강제 풀스크린 + 사진 placeholder (cinematic 그라디언트 + vignette) + frosted 헤더 (닫기·비율·더보기) + 메타 핀 (필터명·강도) + frosted 하단 컨트롤 (재촬영·필터변경·편집·삭제) + 저장/공유 CTA + 삭제 confirmationDialog. 기존 `CameraScreen` 의 `CaptureResultScreen` (sheet) 은 통합 부담을 피해 그대로 유지하며, 후속 phase 에서 점진 전환할 수 있는 별도 파일로 추가. |
| D4 | ✅ Done | 2026-05-06 | 2026-05-06 | `CameraScreen` 시각 폴리시: frosted blur top bar (xmark/AUTO pill/aspect menu/flip), 좌우 스와이프 제스처 (30% 또는 500pt/s threshold + medium impact + `.fmSpringSwipe`) 로 인접 필터 전환, 좌/우 인접 필터 라벨 힌트, 필터 캐러셀 (64×64 chip + 골드 외곽선 + scrollTo center), `FMSlider` 기반 강도 frosted card, 셔터 76pt 골드 + 흰 링, 1/3 컴포지션 그리드. 결과 화면은 `CapturePreviewHost` 어댑터로 `CapturePreviewScreen` (D3) 를 `.fullScreenCover` 로 띄우고 `PhotoLibrarySaver` + `UIActivityViewController` 공유 + 저장 banner (success/error 햅틱) 통합. 카메라 로직 (Metal/AVFoundation/PhotoKit) 무변경. |
| D5 | ✅ Done | 2026-05-06 | 2026-05-06 | `Sources/App/Permissions/` 신설: `PermissionCoordinator` (4 권한 + 비동기 request/openSettings) + 8 SwiftUI 화면 (Camera/Photos/Notifications/Location × Priming/Denied) + 공통 `PermissionScaffold` (라이트 강제, 96pt 일러스트, `PermissionStepsCard` 1·2·3 단계, `FMButton` 기반 CTA). `Info.plist` 갱신 (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSLocationWhenInUseUsageDescription` — 한국어 카피). 통합: `CameraScreen` 진입 시 `notDetermined` → priming, `denied/restricted` → denied 화면, `authorized` → 기존 카메라 surface. 기존 `CameraSession`/`PhotoLibrarySaver` 권한 로직은 무변경. |
| D6 | ✅ Done | 2026-05-06 | 2026-05-06 | `Sources/DesignSystem/Modals/` 신설 — `FMBottomSheet`/`FMConfirmationDialog`/`FMAlert`/`FMShareSheet` 4종 wrapper (View extension 형태, presentationDetents·cornerRadius·destructive alert 단축 API). `Sources/DesignSystem/HapticEngine.swift` — `FMHaptic` enum (light/medium/heavy/rigid/soft, success/warning/error, selection) + `fmHaptic(_:)` 함수형 단축. `Sources/DesignSystem/ReduceMotion.swift` — `Animation.reducedIfNeeded(_:)` + `View.fmAnimation(_:value:)` modifier + `AnyTransition.fmReducible`. 적용: `CameraScreen`/`CapturePreviewScreen`/`SettingsScreen`/`FilterDetailScreen`/`ProfileScreen`/`OnboardingScreen`/`RootShell`/`PermissionScaffold` 의 inline `UIImpactFeedbackGenerator`/`UISelectionFeedbackGenerator`/`UINotificationFeedbackGenerator` 직접 호출을 `FMHaptic.x.play()` 로 통일 (`FMButton`/`FMSlider` 컴포넌트 포함). `CameraScreen` 의 inline `CaptureShareSheet` 삭제 → `FMShareSheet` 로 교체. `SettingsScreen` 의 `.alert` 2종 → `fmDestructiveAlert` 로 교체. `CapturePreviewScreen` 의 `.confirmationDialog` → `fmConfirmationDialog` 로 교체. CameraScreen/OnboardingScreen 의 swipe/scrollTo 애니메이션에 `@Environment(\\.accessibilityReduceMotion)` 분기 적용 (`reduceMotion ? .fmFast : .fmSpringSwipe`). focus reticle 의 inline `.easeOut(duration: 0.16)` → `.fmFast`. |
| D7 | ⏳ Pending | — | — | MVP 외 |

### MVP (D0~D6) 완료 요약 — 2026-05-06

| Phase | 핵심 산출 |
|---|---|
| D0 토큰 | `Sources/DesignSystem/Tokens/` 8 파일 + 라이트/다크 듀얼 + 레거시 alias |
| D1 컴포넌트 | `Sources/DesignSystem/Components/` 12 컴포넌트 + Preview 풀 변형 |
| D2 셸 | 5탭 + 중앙 셔터, `RootShell` `.fullScreenCover` 진입, `Search`/`Saved` placeholder |
| D3 화면 | 8 화면 (Login/Marketplace/FilterDetail/Profile/Settings/Search/Onboarding/CapturePreview) |
| D4 카메라 | frosted blur + 좌우 스와이프 + 필터 캐러셀 + `FMSlider` 강도 + `CapturePreviewHost` 통합 |
| D5 권한 | `PermissionCoordinator` + 8 priming/denied 화면 + `Info.plist` 한국어 카피 |
| D6 모달·모션·햅틱 | 4 모달 wrapper + `FMHaptic` + `Reduce Motion` modifier + 전 화면 일관 적용 |

---

## 관련 문서

- [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md) — v1.2 풀 디자인 시스템
- [`DESIGN_TOKENS.json`](./DESIGN_TOKENS.json) — v1.2.0 토큰
- [`MOTION_SPEC.md`](./MOTION_SPEC.md) — 모션 스펙
- [`EMPTY_STATES.md`](./EMPTY_STATES.md) — 빈 상태 명세
- [`PERMISSIONS_FLOW.md`](./PERMISSIONS_FLOW.md) — 권한 흐름
- [`MODAL_PATTERNS.md`](./MODAL_PATTERNS.md) — 모달 결정 가이드
- [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) — GitHub 이슈 운영 가이드
- [`PRD.md`](./PRD.md) · [`SYSTEM_DESIGN.md`](./SYSTEM_DESIGN.md) · [`ARCHITECTURE.md`](./ARCHITECTURE.md)
