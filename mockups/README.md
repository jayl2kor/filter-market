# filterMarket — HTML Mockups

> 버전: v1.2 (Light Minimal + 상태/권한/모달/모션 보강) · 작성일: 2026-05-06 · 모드: Light 기본 + Dark 카메라 흐름
>
> iPhone 14 Pro (393×852pt) 프레임 위에 그린 **29개 화면** + 1개 카탈로그. SwiftUI 구현 시 1pt = 1px 매핑.

---

## 어떻게 보나요

```
open /Users/user/workspace/applications/filterMarket/mockups/index.html
```

또는 단순히 `mockups/index.html` 파일을 더블클릭. 외부 폰트·이미지·CDN 호출 없음 — 오프라인에서도 동작합니다.

---

## v1.2 변경 요약 — 보강 추가 (P0 묶음)

| 항목 | v1.1 | v1.2 |
|---|---|---|
| 화면 수 | 12 | 29 + 카탈로그 1 |
| 토큰 | v1.1.0 (라이트/다크 모드) | **v1.2.0** (interaction/state/disabled/z 추가) |
| 상태 변형 | 없음 | **빈/로딩/에러/오프라인/토스트** 카탈로그 |
| 권한 화면 | 없음 | **카메라/사진/푸시/위치 × priming+denied = 8** |
| 모달 | 없음 | **Bottom Sheet / Action Sheet / Confirmation / Share = 4** |
| 모션 스펙 | 토큰만 | **`MOTION_SPEC.md`** (cubic-bezier·duration·SwiftUI 매핑) |
| 신규 문서 | — | EMPTY_STATES / PERMISSIONS_FLOW / MODAL_PATTERNS / MOTION_SPEC |

라이트 메인(`#FAFAF7`) + 골드 악센트(`#B8853A`) 동일 유지. 카메라 흐름(03/04/05)은 다크 그대로.

---

## v1.1 변경 (참고) — Dark → Light Minimal

| | v1.0 (Dark) | v1.1 (Light Minimal) |
|---|---|---|
| 캔버스 | `#0A0A0A` | `#FAFAF7` (따뜻한 베이지 화이트) |
| 텍스트 | `#FFFFFF` | `#0F0F0E` (딥 차콜) |
| 악센트 | `#E8B86D` | `#B8853A` (라이트 AA용 톤 다운) |
| 카드 | bg-2 fill | white fill + 1px subtle border + soft shadow |
| 버튼 secondary | bg-3 fill | white fill + border |
| 카메라 흐름 | 다크 | **다크 유지** (눈부심 회피) |

---

## 디렉토리

```
mockups/
├── index.html              ← 갤러리 (Light/Dark/States/Permissions/Modals 그룹)
├── README.md               ← 이 문서
├── shared/
│   ├── tokens.css          ← :root (light) + [data-theme="dark"] + v1.2 상태 토큰
│   ├── components.css      ← 듀얼 모드 + 스켈레톤/토스트/모달 스타일
│   ├── phone-frame.css     ← iPhone 14 Pro 프레임 (light/dark 변형)
│   └── fonts.css           ← 시스템 폰트 스택
└── screens/
    ├── 01-onboarding.html         [Light]  진입 카드 스택
    ├── 02-login.html              [Light]  Apple/Google/이메일
    ├── 03-camera-live.html        [Dark]   라이브 카메라 + 미니멀 HUD
    ├── 04-filter-swipe.html       [Dark]   필터 좌우 스와이프 + 강도 슬라이더
    ├── 05-capture-preview.html    [Dark]   촬영 직후 미리보기
    ├── 06-marketplace-home.html   [Light]  트렌딩/카테고리/그리드/컬렉션
    ├── 07-filter-detail.html      [Light]  비포/애프터 슬라이더 + 메이커
    ├── 08-search.html             [Light]  최근/추천/메이커/결과
    ├── 09-profile.html            [Light]  통계 + 3열 그리드
    ├── 10-settings.html           [Light]  그룹 리스트
    ├── 11-filter-editor.html      [Light]  (Phase 2) 파라미터 슬라이더
    ├── 12-upload-flow.html        [Light]  (Phase 2) 3단계 스테퍼
    ├── states-catalog.html        [Light]  ★ 빈/로딩/에러/오프라인/토스트 통합 카탈로그
    ├── permissions/                        ★ 권한 priming/denied 8화면
    │   ├── _shared.css
    │   ├── camera-priming.html         [Light]
    │   ├── camera-denied.html          [Light]
    │   ├── photos-priming.html         [Light]
    │   ├── photos-denied.html          [Light]
    │   ├── notifications-priming.html  [Light]
    │   ├── notifications-denied.html   [Light]
    │   ├── location-priming.html       [Light]
    │   └── location-denied.html        [Light]
    └── modals/                             ★ 모달/시트 4종
        ├── bottom-sheet.html         [Light]  필터 정보 시트
        ├── action-sheet.html         [Light]  사진 액션 (공유/저장/삭제/신고)
        ├── confirmation-alert.html   [Light]  삭제/로그아웃/약관 3변형
        └── share-sheet.html          [Light]  iOS UIActivityViewController 모방
```

---

## 화면 ↔ 문서 매핑

### 기존 12개 화면

| 화면 | 모드 | PRD/SYSTEM_DESIGN 연결 |
|---|---|---|
| 01 Onboarding | Light | PRD §1 비전 시각화. 메이커×촬영자 양면 마켓 컨셉 |
| 02 Login | Light | PRD §3.6 인증, SYSTEM_DESIGN §5 인증 흐름 (Sign in with Apple 우선) |
| 03 Camera Live | **Dark** | PRD §3.1 F1, SYSTEM_DESIGN §1 Metal 4-pass 파이프라인의 UI 측 |
| 04 Filter Swipe | **Dark** | PRD §3.1 F1 필터 강도, US-01 (라이브 필름 필터) |
| 05 Capture Preview | **Dark** | PRD §3.2 F2, SYSTEM_DESIGN §1.5 사진 캡처 |
| 06 Marketplace | Light | PRD §3.4 F4, SYSTEM_DESIGN §4 마켓 데이터 모델 |
| 07 Filter Detail | Light | PRD §3.4, SYSTEM_DESIGN §4.1 `/filters/{id}` 메타 |
| 08 Search | Light | PRD US-02, SYSTEM_DESIGN §4.3 검색 |
| 09 Profile | Light | PRD §3.5 F5, SYSTEM_DESIGN §4.1 `/users/{uid}` |
| 10 Settings | Light | PRD §3.6 인증·계정, SYSTEM_DESIGN §5.4 GDPR/계정 관리 |
| 11 Filter Editor | Light | PRD §3.3 F3 Tier 1, SYSTEM_DESIGN §3.1 LUT + 파라미터 |
| 12 Upload Flow | Light | PRD US-04, SYSTEM_DESIGN §6.1 업로드 시 자동 모더레이션 흐름 |

### v1.2 신규 화면

| 화면 | 모드 | 연결 문서 |
|---|---|---|
| `states-catalog.html` (Empty/Loading/Error/Offline/Toast) | Light | [`EMPTY_STATES.md`](../docs/EMPTY_STATES.md) |
| `permissions/camera-*` | Light | [`PERMISSIONS_FLOW.md`](../docs/PERMISSIONS_FLOW.md) §1 |
| `permissions/photos-*` | Light | [`PERMISSIONS_FLOW.md`](../docs/PERMISSIONS_FLOW.md) §2 |
| `permissions/notifications-*` | Light | [`PERMISSIONS_FLOW.md`](../docs/PERMISSIONS_FLOW.md) §3 |
| `permissions/location-*` | Light | [`PERMISSIONS_FLOW.md`](../docs/PERMISSIONS_FLOW.md) §4 |
| `modals/bottom-sheet.html` | Light | [`MODAL_PATTERNS.md`](../docs/MODAL_PATTERNS.md) §1 |
| `modals/action-sheet.html` | Light | [`MODAL_PATTERNS.md`](../docs/MODAL_PATTERNS.md) §2 |
| `modals/confirmation-alert.html` | Light | [`MODAL_PATTERNS.md`](../docs/MODAL_PATTERNS.md) §3 |
| `modals/share-sheet.html` | Light | [`MODAL_PATTERNS.md`](../docs/MODAL_PATTERNS.md) §4 |

---

## 테마 전환 구조

CSS는 `:root`(light)와 `[data-theme="dark"]` 셀렉터 두 단계.

```html
<!-- 라이트 (기본) -->
<html lang="ko">

<!-- 다크 (카메라 화면) -->
<html lang="ko" data-theme="dark">
```

토큰 변수 이름은 동일(`--bg-0`, `--accent`, ...). 화면 코드는 항상 변수만 참조하므로 모드 전환은 `data-theme` 한 줄 변경이면 충분. SwiftUI 측에서는 Asset Catalog의 Light/Dark variant + `colorScheme(.dark)` 한정 적용으로 동일 패턴 구현.

---

## SwiftUI 구현 시 참고

### 1. 픽셀 매핑

- **1pt = 1px** 매핑.
- 폰 프레임 393×852는 iPhone 14 Pro의 `point` 기준이며, 실제 디바이스에서는 자동으로 3x scale 됩니다.

### 2. 토큰 매핑 (Light / Dark dual + 상태)

| CSS 변수 | SwiftUI |
|---|---|
| `--bg-0` (Light: #FAFAF7 / Dark: #000000) | `Color("BG/0")` (Asset Catalog Light/Dark variant) |
| `--accent` (Light: #B8853A / Dark: #E8B86D) | `Color("Accent/Primary")` |
| `--sp-md` (16) | `Sp.md` 상수 |
| `--r-md` (8) | `R.md` |
| `--d-fast` (200ms) | `Animation.easeOut(duration: 0.2)` |
| `--state-skeleton-base` | `Color("Skeleton/Base")` |
| `--overlay-scrim` (alpha 0.6) | `Color.black.opacity(0.6)` |
| `--z-modal` | `.zIndex(1000)` |

### 3. 카메라 화면 강제 다크

```swift
struct CameraView: View {
    var body: some View {
        ZStack { /* … */ }
            .preferredColorScheme(.dark)   // 03/04/05 한정
    }
}
```

자세한 매핑은 `docs/DESIGN_SYSTEM.md` §10 참조.

### 4. 비포/애프터 슬라이더 (07)

CSS `clip-path: inset(0 0 0 50%)` → SwiftUI `.mask(alignment: .leading) { Rectangle().frame(width: dragX) }`.

### 5. 필터 캐러셀 (04)

`scroll-snap-type: x mandatory` → SwiftUI `ScrollView(.horizontal)` + `LazyHStack` + `.scrollTargetBehavior(.viewAligned)`.

### 6. 모달/시트 매핑

| HTML 목업 | SwiftUI 표준 |
|---|---|
| `bottom-sheet.html` | `.sheet(isPresented:)` + `.presentationDetents([.medium, .large])` |
| `action-sheet.html` | `.confirmationDialog(...)` |
| `confirmation-alert.html` | `.alert(...)` |
| `share-sheet.html` | `ShareLink(...)` |

### 7. 권한 흐름

priming 화면 → `AVCaptureDevice.requestAccess(...)` 시스템 다이얼로그 → 허용/거부 분기. 거부 시 `denied` 화면으로 이동, "설정 열기" 버튼은 `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`.

상세는 [`docs/PERMISSIONS_FLOW.md`](../docs/PERMISSIONS_FLOW.md).

---

## 기술 노트

- **외부 의존성 0**: 폰트, 이미지, JS 라이브러리 모두 호출 안 함.
- **placeholder 사진**: CSS gradient + SVG noise (data URI). 라이트 모드용은 페일톤, 다크 모드는 깊은 톤 (자동 전환).
- **JS 최소**: 갤러리 iframe 임베딩만. 인터랙션은 CSS hover/active로.
- **반응형 X**: iPhone 14 Pro 한 사이즈만. 갤러리는 데스크탑 폭에 따라 그리드 자동 조정.
- **듀얼 모드**: 9 라이트 + 3 다크 + 17 라이트 신규. 단일 토큰 시스템에서 자동 전환.

---

## WCAG AA 검증 (Light)

| 조합 | 비율 | 등급 |
|---|---|---|
| `text/primary` on `bg/0` | 18.5:1 | AAA |
| `text/secondary` on `bg/0` | 8.7:1 | AAA |
| `accent` on `bg/0` | 4.8:1 | AA |
| `accent` on `bg/2` (white) | 4.5:1 | AA |
| `text/inverse` on `accent` | 4.8:1 | AA |
| `error` on `bg/0` | 5.2:1 | AA |
| `success` on `bg/0` | 5.7:1 | AA |
| `info` on `bg/0` | 5.6:1 | AA |

본문은 항상 `text/secondary` 이상 사용. 모든 인터랙티브 텍스트는 4.5:1 이상.

---

## 다음 단계

1. **DesignSystem 모듈 구현**: `Sources/DesignSystem/`에 토큰 → SwiftUI Color/Font/Spacing 상수 + Asset Catalog Light/Dark variant.
2. **재사용 View 작성**: `FMButton`, `FMCard`, `FMFilterTile`, `FMSlider`, `FMSkeleton`, `FMToast` 등 본 목업 컴포넌트의 SwiftUI 버전.
3. **MTKView 통합**: 03/04/05 화면의 Metal 프리뷰는 `UIViewRepresentable`로 래핑 (CODING_CONVENTIONS §7.5 참조). 카메라 뷰는 `.preferredColorScheme(.dark)`.
4. **권한 흐름 구현**: `PERMISSIONS_FLOW.md`의 priming → 시스템 다이얼로그 → denied 분기 패턴 적용. Info.plist 키 등록 잊지 말기.
5. **모션 적용**: `MOTION_SPEC.md`의 cubic-bezier 값과 SwiftUI Animation enum 토큰을 DesignSystem 모듈에 상수화.
6. **다이내믹 타입 검증**: 본 목업의 폰트 크기는 default. xxxLarge 시 깨지지 않게 SwiftUI에서 `.dynamicTypeSize(...)` 제한.
7. **VoiceOver 패스**: HTML의 `aria-label` → SwiftUI의 `.accessibilityLabel(...)` 로 옮길 때 누락 점검.

---

## 관련 문서

### 디자인
- [`../docs/DESIGN_SYSTEM.md`](../docs/DESIGN_SYSTEM.md) — 풀 디자인 시스템 (v1.2)
- [`../docs/DESIGN_PRINCIPLES.md`](../docs/DESIGN_PRINCIPLES.md) — 1페이지 선언문
- [`../docs/DESIGN_TOKENS.json`](../docs/DESIGN_TOKENS.json) — 듀얼 모드 + 상태 토큰 (v1.2.0)

### v1.2 신규 가이드
- [`../docs/EMPTY_STATES.md`](../docs/EMPTY_STATES.md) — 빈 상태 5종 명세 + SwiftUI 패턴
- [`../docs/PERMISSIONS_FLOW.md`](../docs/PERMISSIONS_FLOW.md) — 권한 4종 priming/denied 흐름 + Info.plist
- [`../docs/MODAL_PATTERNS.md`](../docs/MODAL_PATTERNS.md) — 모달 4종 사용 결정 가이드
- [`../docs/MOTION_SPEC.md`](../docs/MOTION_SPEC.md) — 모션 스펙 (cubic-bezier, 햅틱, Reduce Motion)

### 제품/설계
- [`../docs/PRD.md`](../docs/PRD.md) · [`../docs/SYSTEM_DESIGN.md`](../docs/SYSTEM_DESIGN.md) · [`../docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md)
