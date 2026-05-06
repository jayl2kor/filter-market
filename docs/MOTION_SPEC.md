# moodit — 모션 스펙

> 버전: v1.2 · 작성일: 2026-05-06
> 본 문서는 moodit 의 모든 모션·전환·햅틱 동작의 단일 진실원이다.
> 컬러/타이포/간격은 [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md), 토큰은 [`DESIGN_TOKENS.json`](./DESIGN_TOKENS.json) 참조.

---

## §1. 모션 원칙

moodit 의 모션은 **세 단어**로 요약된다: **절제, 명료, 즉각**.

| 원칙 | 의미 | 위반 예 |
|---|---|---|
| **절제** | 모션은 사진의 감상을 방해하지 않는다 | 요소가 날아다니거나 튀는 bounce |
| **명료** | 모션이 의미를 전달한다 — "어디서 왔고 어디로 가는가"를 보여준다 | 기능 없이 화려함만을 위한 애니메이션 |
| **즉각** | 탭에 바로 반응한다 — 사용자가 기다리지 않게 한다 | 인터랙션 시작 전 딜레이 없이 |

### 1.1 듀레이션 가이드라인

- **평균 지속 시간**: 200~300ms
- **절대 상한선**: 500ms — 이를 초과하면 앱이 무거워 보인다
- **탭 피드백**: 항상 100ms 이내에 시각적 응답

### 1.2 기본 이징

- **기본 이징**: ease-out (`cubic-bezier(0, 0, 0.2, 1)`) — 요소가 자연스럽게 제동하며 멈춤
- **나가는 요소**: ease-in (`cubic-bezier(0.4, 0, 1, 1)`) — 빠르게 치고 나감
- **스프링**: 탭 응답, snap, 물리적 느낌이 필요한 곳 한정

```css
/* tokens.css 에 정의된 이징 토큰 */
--ease-standard:   cubic-bezier(0.2, 0, 0, 1);
--ease-decelerate: cubic-bezier(0, 0, 0.2, 1);   /* 들어오는 요소 */
--ease-accelerate: cubic-bezier(0.4, 0, 1, 1);   /* 나가는 요소 */
--ease-spring:     cubic-bezier(0.34, 1.4, 0.64, 1); /* 탭 응답 */
```

---

## §2. 화면 전환

### 2.1 Push (네비게이션 드릴다운)

목록에서 상세로, 혹은 계층 아래로 이동하는 전환.

| 속성 | 값 |
|---|---|
| Duration | 300ms |
| Easing | `cubic-bezier(0, 0, 0.2, 1)` (decelerate) |
| 진입 화면 | 오른쪽에서 슬라이드 인 (`translateX(100%)` → `translateX(0)`) |
| 부모 화면 | `translateX(0)` → `translateX(-30%)` + `opacity: 1` → `0.7` |

```css
/* 진입 화면 */
.screen-enter {
  animation: push-enter 300ms cubic-bezier(0, 0, 0.2, 1) both;
}
@keyframes push-enter {
  from { transform: translateX(100%); }
  to   { transform: translateX(0); }
}

/* 부모 화면 (push 시 뒤로 밀림) */
.screen-parent-push {
  animation: push-parent 300ms cubic-bezier(0, 0, 0.2, 1) both;
}
@keyframes push-parent {
  from { transform: translateX(0);    opacity: 1;   }
  to   { transform: translateX(-30%); opacity: 0.7; }
}
```

**SwiftUI 매핑**

```swift
// NavigationStack 이 기본으로 제공하는 push 전환을 그대로 사용.
// 커스텀이 필요한 경우:
NavigationStack {
    FilterDetailView()
        .navigationTransition(.push(from: .trailing))
}
```

**팝(back) 전환**: push 의 역방향. duration 동일, easing 은 `accelerate`.

---

### 2.2 Modal Sheet (바텀 시트)

필터 상세 요약, 설정 옵션, 빠른 액션 패널.

| 속성 | 값 |
|---|---|
| Duration | 350ms |
| 물리 모델 | 스프링 (damping 0.85, response 0.45) |
| 진입 | `translateY(100%)` → `translateY(0)`, spring |
| 퇴장 | `translateY(0)` → `translateY(100%)`, 200ms ease-in |
| 스크림 | `opacity: 0` → `0.42`, 250ms ease-out |

```css
/* 시트 등장 */
.sheet {
  animation: sheet-enter 350ms cubic-bezier(0.34, 1.4, 0.64, 1) both;
}
@keyframes sheet-enter {
  from { transform: translateY(100%); }
  to   { transform: translateY(0); }
}

/* 스크림 */
.scrim {
  animation: scrim-in 250ms cubic-bezier(0, 0, 0.2, 1) both;
}
@keyframes scrim-in {
  from { opacity: 0; }
  to   { opacity: 0.42; }
}
```

**SwiftUI 매핑**

```swift
.sheet(isPresented: $showSheet) {
    FilterDetailSheet()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
// 스프링은 SwiftUI .sheet 가 기본 처리.
// 커스텀 스프링이 필요한 경우:
withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
    showSheet = true
}
```

---

### 2.3 Full-screen Present (전체 화면 모달)

온보딩, 카메라 화면 진입처럼 맥락 전환이 큰 경우.

| 속성 | 값 |
|---|---|
| Duration | 400ms |
| Easing | `cubic-bezier(0.2, 0, 0, 1)` (standard) |
| 진입 | `scale(1.05) opacity(0)` → `scale(1) opacity(1)` |
| 퇴장 | `scale(1) opacity(1)` → `scale(0.95) opacity(0)`, 300ms |

```css
@keyframes fullscreen-enter {
  from { transform: scale(1.05); opacity: 0; }
  to   { transform: scale(1);    opacity: 1; }
}
@keyframes fullscreen-exit {
  from { transform: scale(1);    opacity: 1; }
  to   { transform: scale(0.95); opacity: 0; }
}
```

**SwiftUI 매핑**

```swift
.fullScreenCover(isPresented: $showCamera) {
    CameraView()
        .transition(
            .asymmetric(
                insertion: .scale(scale: 1.05).combined(with: .opacity),
                removal:   .scale(scale: 0.95).combined(with: .opacity)
            )
        )
}
```

---

### 2.4 탭 전환 (Tab Bar)

앱 하단 탭 간 이동.

| 속성 | 값 |
|---|---|
| Duration | 200ms |
| Easing | `cubic-bezier(0.2, 0, 0, 1)` |
| 효과 | Cross-fade — 이전 탭 `opacity: 0`, 신규 탭 `opacity: 1` |

슬라이드 금지 — 탭 간 이동은 공간적 계층이 없으므로 방향 있는 전환은 혼란을 준다.

```css
.tab-view-content {
  animation: tab-crossfade 200ms cubic-bezier(0.2, 0, 0, 1) both;
}
@keyframes tab-crossfade {
  from { opacity: 0; }
  to   { opacity: 1; }
}
```

**SwiftUI 매핑**

```swift
TabView(selection: $selectedTab) {
    MarketView().tabItem { Label("마켓", systemImage: "storefront") }.tag(0)
    CameraView().tabItem { Label("카메라", systemImage: "camera") }.tag(1)
}
.animation(.easeInOut(duration: 0.2), value: selectedTab)
```

---

## §3. 인터랙션 피드백

### 3.1 버튼 탭

사용자가 탭을 시작한 순간 즉시 scale 변화로 응답한다.

| 단계 | 값 | 시간 |
|---|---|---|
| 탭 다운 (`touchDown`) | `scale(0.97)` | 100ms ease-out |
| 탭 업 (`touchUpInside`) | `scale(1)` | 200ms spring |
| 취소 (`touchUpOutside`) | `scale(1)` | 150ms ease-out |

```css
.btn:active {
  transform: scale(0.97);
  transition: transform 100ms cubic-bezier(0, 0, 0.2, 1);
}
/* 탭 업은 JS 또는 SwiftUI 에서 처리 */
```

**SwiftUI 매핑**

```swift
struct FMButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(
                configuration.isPressed
                    ? .easeOut(duration: 0.1)
                    : .spring(response: 0.2, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}
```

---

### 3.2 카드 탭

필터 타일, 목록 행 — 버튼보다 약하게.

| 단계 | 값 | 시간 |
|---|---|---|
| 탭 다운 | `scale(0.985)` + `opacity: 0.9` | 80ms ease-out |
| 탭 업 | `scale(1)` + `opacity: 1` | 200ms spring |

---

### 3.3 토글 (온/오프)

| 속성 | 값 |
|---|---|
| Duration | 200ms |
| Easing | spring (damping 0.7, response 0.25) |
| 트랙 색 전환 | `accent/bg` → `accent` 200ms |
| 썸 이동 | spring — 약간의 오버슈트 허용 (자연스러운 물리감) |
| 햅틱 | `UISelectionFeedbackGenerator().selectionChanged()` |

**SwiftUI 매핑**: 시스템 `Toggle` 사용. 커스텀 스타일이 필요한 경우만 `ToggleStyle` 구현.

---

### 3.4 Pull to Refresh

| 구간 | 동작 |
|---|---|
| 0~44pt 당김 | 인디케이터 `opacity: 0` → `1`, 회전 없음 |
| 44pt~80pt | 인디케이터 회전 시작 (0° → 180°), 360ms/cycle |
| 80pt 해제 | 스피너 전환 + 콘텐츠 로드 시작 |
| 로드 완료 | 인디케이터 fade-out 300ms + 콘텐츠 fade-in 200ms |

---

## §4. 필터 스와이프 (핵심 인터랙션)

필터 스와이프는 moodit 의 **핵심 인터랙션**이다. 사용자가 카메라 라이브뷰 위에서 좌우로 스와이프해 실시간으로 필터를 전환한다.

```
┌─────────────────────────────┐
│  [이전 필터 미리보기 15%]    │
│  ←  현재 필터 라이브뷰  →   │
│           [다음 필터 미리보기 15%]  │
└─────────────────────────────┘
```

### 4.1 드래그 추적

| 속성 | 값 |
|---|---|
| 추적 시작 | 즉시 (0ms 딜레이) — 손가락 위치를 정확히 따라감 |
| 1:1 추적 | 드래그 거리 = 화면 이동 거리 |
| 마찰 | 없음 — rubber banding 은 첫/마지막 필터 경계에서만 |

### 4.2 Snap Threshold (전환 결정)

아래 두 조건 중 하나를 만족하면 다음 필터로 snap:

| 조건 | 기준값 |
|---|---|
| 이동 거리 | 화면 너비(393pt)의 **30%** — 약 118pt |
| 드래그 속도 | **500pt/s** 이상 (속도 우선, 거리 미달 가능) |

threshold 미달 시 현재 필터로 되돌아온다 (snap back).

### 4.3 Snap 애니메이션

| 동작 | 값 |
|---|---|
| Snap 전환 | 350ms spring, damping 0.8, response 0.4 |
| Snap back | 300ms spring, damping 0.85, response 0.35 |

```swift
// 전환 snap
withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
    currentFilterIndex = nextIndex
    dragOffset = .zero
}

// 되돌아오기
withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
    dragOffset = .zero
}
```

### 4.4 다음 필터 미리보기

드래그하는 동안 양옆 필터가 부분적으로 노출된다:

| 속성 | 값 |
|---|---|
| 미리보기 너비 | 화면 너비의 **15%** (약 59pt) |
| 미리보기 진입 | 드래그 진행도에 비례 (선형) |
| 완전 노출 | snap 완료 시 100% |

```swift
// 드래그 중 다음 필터 offset 계산
let previewOffset = screenWidth * 0.85 + dragOffset  // 오른쪽 필터
let prevOffset    = -screenWidth * 0.85 + dragOffset // 왼쪽 필터
```

### 4.5 햅틱 피드백

| 이벤트 | 햅틱 |
|---|---|
| Snap 성공 (필터 전환) | `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` |
| Snap back (경계 도달) | `UIImpactFeedbackGenerator(style: .light).impactOccurred()` |
| 첫 번째/마지막 경계 rubber band | `UIImpactFeedbackGenerator(style: .rigid).impactOccurred()` |

### 4.6 필터 강도 슬라이더

라이브뷰 하단의 강도 슬라이더:

| 속성 | 값 |
|---|---|
| 드래그 | 1:1 즉시 추적 |
| 값 변경 햅틱 | 0%, 50%, 100% 위치에서 `UISelectionFeedbackGenerator().selectionChanged()` |
| 시각 피드백 | 슬라이더 트랙 채움 색 `accent` (`#E8B86D` — 다크 모드) |

---

## §5. 스켈레톤 시머 (로딩 상태)

콘텐츠 로드 전 자리 표시자로 사용. 빈 회색 블록이 아니라 움직이는 광택으로 "로딩 중"을 명확히 전달.

### 5.1 시머 명세

| 속성 | 값 |
|---|---|
| 하이라이트 폭 | 전체 요소 폭의 **30%** |
| 기울기 | **5도** (약간 기울어진 광택 효과) |
| 한 사이클 | **1.5초** |
| 사이클 사이 정지 | **200ms** — 자연스러운 호흡감 |
| 이징 | `ease-in-out` |
| 색 | `bg/3 (#EDEBE5)` 베이스, `bg/2 (#FFFFFF)` 하이라이트 |

```css
.skeleton {
  background: var(--bg-3);
  border-radius: var(--r-md);
  overflow: hidden;
  position: relative;
}
.skeleton::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(
    105deg,               /* 5도 기울기 */
    transparent 25%,
    rgba(255,255,255,0.7) 50%,
    transparent 75%
  );
  background-size: 300% 100%;  /* 폭 30% 하이라이트 */
  animation: shimmer 1.5s ease-in-out 0.2s infinite;
}
@keyframes shimmer {
  0%   { background-position: 200% center; }
  100% { background-position: -200% center; }
}
```

**SwiftUI 매핑**

```swift
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color("BG/2").opacity(0.7), .clear],
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint:   .init(x: phase + 0.3, y: 1)
                )
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .delay(0.2)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
```

### 5.2 스켈레톤 사용 규칙

- 첫 로드에만 사용. 새로고침은 기존 콘텐츠를 흐리게 유지 (스켈레톤으로 대체 금지).
- 0.3초 이내에 로드될 것이 확실한 경우 스켈레톤 생략 — flash of skeleton 방지.
- 텍스트 스켈레톤 높이는 해당 폰트 라인 하이트와 동일하게.

---

## §6. 토스트 & 배너

### 6.1 일반 토스트 (저장 완료, 에러 등)

화면 상단 또는 하단에서 등장해 자동으로 사라지는 단기 알림.

| 속성 | 값 |
|---|---|
| 진입 | 300ms ease-out, 위에서 슬라이드 다운 + opacity 0 → 1 |
| 퇴장 | 200ms ease-in, 위로 슬라이드 업 + opacity 1 → 0 |
| 자동 dismiss | **4초** (일반) |
| 수동 dismiss | 스와이프 업 |

```css
@keyframes toast-enter {
  from { transform: translateY(-100%); opacity: 0; }
  to   { transform: translateY(0);     opacity: 1; }
}
@keyframes toast-exit {
  from { transform: translateY(0);     opacity: 1; }
  to   { transform: translateY(-100%); opacity: 0; }
}
```

### 6.2 성공 배너 (다운로드 완료 등)

| 속성 | 값 |
|---|---|
| 자동 dismiss | **2.5초** — 성공은 빠르게 사라져야 흐름이 끊기지 않음 |
| 햅틱 | `UINotificationFeedbackGenerator().notificationOccurred(.success)` |

### 6.3 에러 배너

| 속성 | 값 |
|---|---|
| 자동 dismiss | 없음 — 사용자가 직접 닫아야 함 |
| 대기 시간 | 최소 8초 — 사용자가 읽을 시간 확보 |
| 햅틱 | `UINotificationFeedbackGenerator().notificationOccurred(.error)` |

**SwiftUI 매핑**

```swift
// 토스트 진입 트랜지션
.transition(
    .asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity)
                   .animation(.easeOut(duration: 0.3)),
        removal:   .move(edge: .top).combined(with: .opacity)
                   .animation(.easeIn(duration: 0.2))
    )
)
```

---

## §7. 햅틱 가이드

iOS `UIFeedbackGenerator` 를 사용한다. 불필요한 햅틱 남용 금지 — 중요한 이벤트에만.

| 동작 | 햅틱 종류 | API |
|---|---|---|
| 일반 버튼 탭 | light impact | `UIImpactFeedbackGenerator(style: .light)` |
| 중요 버튼 탭 (구매, 저장) | medium impact | `UIImpactFeedbackGenerator(style: .medium)` |
| 파괴적 액션 (삭제, 신고) | heavy impact | `UIImpactFeedbackGenerator(style: .heavy)` |
| 필터 snap 전환 | medium impact | `UIImpactFeedbackGenerator(style: .medium)` |
| 토글 스위치 | selection | `UISelectionFeedbackGenerator()` |
| 칩/탭 선택 변경 | selection | `UISelectionFeedbackGenerator()` |
| 저장 완료, 다운로드 완료 | success notification | `UINotificationFeedbackGenerator()` → `.success` |
| 경고 (네트워크 오류 등) | warning notification | `UINotificationFeedbackGenerator()` → `.warning` |
| 오류 (결제 실패 등) | error notification | `UINotificationFeedbackGenerator()` → `.error` |
| 슬라이더 경계 도달 (0%, 100%) | rigid impact | `UIImpactFeedbackGenerator(style: .rigid)` |
| 당겨서 새로고침 임계 도달 | soft impact | `UIImpactFeedbackGenerator(style: .soft)` |

> **주의**: 햅틱은 메인 스레드에서 실행해야 한다. `DispatchQueue.main.async { generator.impactOccurred() }`.

---

## §8. Reduce Motion 대응

iOS 설정 › 손쉬운 사용 › 모션 줄이기 가 켜진 사용자는 과도한 모션에 민감할 수 있다.
`UIAccessibility.isReduceMotionEnabled` 또는 SwiftUI `@Environment(\.accessibilityReduceMotion)` 로 감지.

### 8.1 대응 원칙

- 이동(translate, scale)이 포함된 전환 → **fade(opacity만)** 로 대체
- duration 은 변경하지 않는다 — 너무 짧으면 변화를 인식 못 함
- 스프링/bounce 완전 제거

### 8.2 원본 → Reduce Motion 대안 표

| 동작 | 원본 | Reduce Motion 대안 |
|---|---|---|
| Push 전환 | slide (300ms) + 부모 -30% | cross-fade (300ms) |
| Modal sheet 진입 | slide up spring (350ms) | fade-in (350ms) |
| Full-screen present | scale 1.05→1 + fade (400ms) | fade-in (400ms) |
| 탭 전환 | cross-fade (200ms) | cross-fade 유지 (변경 없음) |
| 버튼 탭 피드백 | scale 0.97 (100ms) | opacity 0.7 (100ms) |
| 카드 탭 피드백 | scale 0.985 (80ms) | opacity 0.85 (80ms) |
| 필터 스와이프 snap | spring translate (350ms) | cross-fade (350ms) |
| 스켈레톤 시머 | 이동하는 gradient (1.5s) | 정적 펄스 opacity 0.5→1 (1.5s) |
| 토스트 진입 | slide down + fade (300ms) | fade-in (300ms) |

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var pushTransition: AnyTransition {
    reduceMotion
        ? .opacity
        : .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
}
```

---

## §9. SwiftUI 구현 매핑

### 9.1 Animation 토큰 enum

```swift
// Sources/DesignSystem/Animation+FM.swift
import SwiftUI

extension Animation {
    // 기본 전환
    static let fmFast     = Animation.easeOut(duration: 0.2)
    static let fmBase     = Animation.easeOut(duration: 0.3)
    static let fmSlow     = Animation.easeOut(duration: 0.5)

    // 스프링 — 탭 피드백
    static let fmSpringSnap     = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let fmSpringSnapBack = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let fmSpringSheet    = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let fmSpringButton   = Animation.spring(response: 0.2, dampingFraction: 0.7)
}
```

### 9.2 주요 SwiftUI 전환 API

| 목적 | API |
|---|---|
| Push 드릴다운 | `NavigationStack` + `.navigationTransition(.push(from: .trailing))` |
| Modal 시트 | `.sheet(isPresented:)` |
| 전체화면 모달 | `.fullScreenCover(isPresented:)` |
| 커스텀 전환 | `.transition(AnyTransition)` |
| 조건부 애니메이션 | `withAnimation(.fmBase) { ... }` |
| 스프링 | `Spring(response:dampingFraction:)` (iOS 17+) |
| 기하학적 전환 | `.matchedGeometryEffect(id:in:)` — 필터 타일 → 상세 전환 |

### 9.3 matchedGeometryEffect 사용 예 (필터 타일 → 상세)

```swift
// 마켓 그리드에서
FilterTileView(filter: filter)
    .matchedGeometryEffect(id: filter.id, in: namespace)
    .onTapGesture {
        withAnimation(.fmBase) { selectedFilter = filter }
    }

// 상세 화면에서
FilterDetailHero(filter: selectedFilter)
    .matchedGeometryEffect(id: selectedFilter.id, in: namespace)
```

### 9.4 .transition 조합 패턴

```swift
// 비대칭 전환 (들어올 때와 나갈 때 다른 방향)
.transition(.asymmetric(
    insertion: .move(edge: .trailing).combined(with: .opacity),
    removal:   .move(edge: .leading).combined(with: .opacity)
))
```

---

## §10. 성능 가이드

### 10.1 60FPS 목표

모든 전환·스크롤·드래그는 **60FPS** (ProMotion 기기에서 120FPS) 를 목표로 한다.
주요 병목: 불투명 레이어 blend, 복잡한 path, 실시간 blur.

### 10.2 GPU-안전 속성 (항상 선호)

| 안전 | 회피 |
|---|---|
| `opacity` | 복잡한 `mask` |
| `transform` (translate/scale/rotate) | `clipShape` + 복잡한 path |
| `backgroundColor` (단색) | 실시간 `blur` (`material` 제외) |

### 10.3 전환 중 blur 제거

`.ultraThinMaterial` 같은 블러 효과는 전환 중 일시적으로 제거한다:

```swift
// 전환 중에는 blur 비활성화 후 완료 후 복원
.blur(radius: isTransitioning ? 0 : 0)  // 실제 값은 상태에 따라 결정
```

### 10.4 그림자 최적화

전환 중 `shadow` 계산은 비용이 크다:

```swift
// 전환 중에는 그림자 생략, 완료 후 복원
.shadow(radius: isTransitioning ? 0 : 8)
```

### 10.5 Xcode Instruments로 측정

| 도구 | 목적 |
|---|---|
| **Core Animation** instrument | 렌더 루프 히치 감지 |
| **Animation Hitches** | 예상 대비 프레임 손실 측정 |
| **GPU Frame Capture** | Metal 드로우 콜 프로파일링 |

목표 히치율: **< 5%** (Apple HIG 권장).

```
Instruments → 새 세션 → Core Animation 선택 → 프로파일 시작
전환 실행 → 히치 마커 확인 → 문제 레이어 추적
```

---

> 관련 문서: [`DESIGN_SYSTEM.md §6 모션`](./DESIGN_SYSTEM.md) · [`DESIGN_TOKENS.json`](./DESIGN_TOKENS.json)
