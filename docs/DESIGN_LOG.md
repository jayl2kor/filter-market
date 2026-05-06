# moodit — Design Reinforcement Log

> 작성: 2026-05-07 · 상태: Active
>
> `DESIGN_INTEGRATION_PLAN.md` D0~D6 (MVP 디자인 시스템) 완료 이후 식별된 디자인 갭의 작업 로그.
> 본 문서는 placeholder 화면 채우기와 별개로 **디자인 시스템 / 비주얼 자산 / 모션 / 접근성** 측면 보강을 추적한다.

---

## 1. 작업 범위

2026-05-07 디자인 갭 감사 결과 식별된 8개 항목:

| # | 항목 | 우선 | 상태 |
|---|---|---|---|
| 1 | App Icon iOS 18 Light/Dark/Tinted variant | P0 | ✅ 기존 완료 (Contents.json + 3 PNG) |
| 2 | 시드 필터 커버 이미지 (5종) | P0 | ⏳ |
| 3 | Empty state 5종 일러스트 | P0 | ⏳ |
| 4 | Launch Screen 설정 | P0 | ⏳ |
| 5 | Localizable.xcstrings 도입 | P1 | ⏳ |
| 6 | FMSwipeIndicator + FMToggle 컴포넌트 | P1 | 🟡 In Progress |
| 7 | Skeleton/Loading 적용 점검 | P1 | ⏳ |
| 8 | Push 화면 전환 모션 | P2 | ⏳ |

---

## 2. 진행 로그

### #1 App Icon iOS 18 variant — ✅ 2026-05-07 검증 완료

**상태**: 기존 작업으로 완료.

**확인 내용**:
- `Sources/App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` 가 `appearances` 키로 `dark` / `tinted` 변형 매핑.
- 자산 파일: `app-icon-light.png` (1024×1024), `app-icon-dark.png`, `app-icon-tinted.png` 모두 존재.
- iOS 18+ Home/App Switcher 에서 시스템 설정 (light/dark/tinted) 따라 자동 변환.

**후속**:
- 실기기에서 다크 / tinted 변형 시각 검증 필요 (M0 device validation 시 포함).

---

### #6 FMSwipeIndicator + FMToggle 컴포넌트 — 🟡 In Progress

**파일 추가**:
- `Sources/DesignSystem/Components/FMSwipeIndicator.swift`
  - `DESIGN_SYSTEM.md` §8.14 정합 — 7-dot, 활성 16×4 막대, 비활성 4×4 점.
  - `Mode.light` / `Mode.dark` enum (카메라 흐름 vs 일반 화면).
  - `count` / `activeIndex` 인자, dynamic 범위.
- `Sources/DesignSystem/Components/FMToggle.swift`
  - `DESIGN_SYSTEM.md` §8.12 정합 — 51×31, 27×27 노브, soft shadow.
  - Off: `bg/3` + 1px subtle border. On: `accent` fill.
  - `FMToggle("title", isOn:)` 단축 init + `FMToggle(isOn:label:)` trailing closure.
  - 탭 시 `FMHaptic.selection` 햅틱.

**향후 적용처**:
- `NotificationSettingsScreen` (현재 stock `Toggle` 사용) 에 `FMToggle` 으로 교체.
- `EditProfileScreen` 의 비공개 / 공개 옵션.
- `CameraScreen` 의 필터 페이지 인디케이터 (현재 인라인) → `FMSwipeIndicator`.
- `OnboardingScreen` 의 페이지 인디케이터 (현재 inline capsule).

---

### #2~#8 — 진행 중

(작성 중인 항목은 완료 시점에 본 로그 추가)

---

## 3. 산출물 요약 (계속 갱신)

| 영역 | 신규 파일 / 변경 |
|---|---|
| DesignSystem 컴포넌트 | `FMSwipeIndicator.swift`, `FMToggle.swift` (#6) |
| Resources / Asset | (예정: 시드 필터 커버, empty state 일러스트, launch screen) |
| Localization | (예정: `Localizable.xcstrings`) |
| Motion | (예정: `Sources/DesignSystem/Modifiers/PushTransition.swift`) |
| Documentation | 본 `DESIGN_LOG.md` |

---

## 4. 관련 문서

- [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md) — v1.1 디자인 시스템
- [`DESIGN_TOKENS.json`](./DESIGN_TOKENS.json) — v1.2.0 토큰
- [`MOTION_SPEC.md`](./MOTION_SPEC.md) — 모션 스펙
- [`EMPTY_STATES.md`](./EMPTY_STATES.md) — 빈 상태 명세
- [`DESIGN_INTEGRATION_PLAN.md`](./DESIGN_INTEGRATION_PLAN.md) — D0~D7 phase 추적
