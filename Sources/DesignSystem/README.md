# DesignSystem

moodit 의 디자인 토큰과 컴포넌트 라이브러리.
단일 진실원: [`docs/DESIGN_TOKENS.json`](../../docs/DESIGN_TOKENS.json) v1.2.0 (라이트/다크 듀얼).

## 토큰 구조

`Sources/DesignSystem/Tokens/` 아래에 도메인별로 분리.

| 파일 | 토큰 | 사용 예 |
|---|---|---|
| `Colors.swift` | `FMColors.Background`, `Surface`, `Border`, `Text`, `Accent`, `Semantic`, `Category`, `Skeleton`, `Overlay`, `Empty` | `FMColors.Background.bg0`, `FMColors.Accent.primary` |
| `Typography.swift` | `FMTypography.{display, titleLarge, title, headline, body, callout, subhead, footnote, caption}`, `Font.fmBody` | `Text("Hi").fmTypography(.body)` 또는 `.font(.fmBody)` |
| `Spacing.swift` | `Sp.{xxs, xs, sm, md, lg, xl, xxl, xxxl, xxxxl}`, `FMLayout` | `VStack(spacing: Sp.md)` |
| `Radius.swift` | `R.{none, sm, md, lg, xl, full}` | `RoundedRectangle(cornerRadius: R.md)` |
| `Motion.swift` | `Animation.fmEaseOut/fmFast/fmSpring/...`, `FMMotion.Spring`, `FMMotion.Shimmer`, `FMMotion.shouldReduce` | `withAnimation(.fmSpring) { … }` |
| `Iconography.swift` | `IconSize.{xs..xxl}`, `IconStroke.default/bold` | `Image(systemName:"x").frame(width: IconSize.md, height: IconSize.md)` |
| `State.swift` | `Opacity.{hover, pressed, selected, textDisabled, fillDisabled, borderDisabled}`, `FocusRing` | `.opacity(isPressed ? 1 - Opacity.pressed : 1)` |
| `ZIndex.swift` | `Z.{base, dropdown, sticky, modal, popover, tooltip, toast}` | `.zIndex(Z.modal)` |

## 라이트/다크 듀얼 모드

컬러는 `Color(light:dark:)` 헬퍼로 정의되며, 시스템 또는 `.preferredColorScheme(.dark)` 에 따라 자동 전환된다.
Asset Catalog 는 사용하지 않는다 — 토큰 정의가 Swift 코드에 그대로 있어 JSON 과 1:1 비교가 쉽다.

```swift
// 카메라 화면처럼 강제 다크가 필요한 경우
struct CameraView: View {
    var body: some View {
        ZStack { /* ... */ }
            .background(FMColors.Background.bg0)
            .preferredColorScheme(.dark)
    }
}
```

## 모션 + Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

withAnimation(reduceMotion ? .fmFast : .fmSpring) {
    isExpanded.toggle()
}
```

## 컴포넌트 (Phase D1)

`Sources/DesignSystem/Components/` 아래에 12 컴포넌트가 들어있다.
모든 컴포넌트는 `public` API + 하나 이상의 `#Preview` (라이트/다크/Dynamic Type 변형 포함).

| 파일 | 컴포넌트 | 핵심 사용 예 |
|---|---|---|
| `FMButton.swift` | `FMButton` (primary/secondary/ghost/destructive × sm/md/lg, loading/disabled) | `FMButton("저장", variant: .primary, size: .lg) { save() }` |
| `FMCard.swift` | `FMCard` + `.fmCard()` modifier | `FMCard { content }` 또는 `view.fmCard()` |
| `FMTextField.swift` | `FMTextField` (plain/password/search/multiline + label/helper/error) | `FMTextField("이메일", text: $email)` · `FMTextField.search(text: $q)` |
| `FMTag.swift` | `FMTag` (정적 라벨) + `FMChip` (인터랙티브 토글) | `FMChip("Cinematic", isSelected: true) { ... }` |
| `FMSlider.swift` | `FMSlider` (라벨 + 값 표시 + 0/50/100 햅틱 anchor) | `FMSlider(value: $intensity, label: "강도")` |
| `FMToast.swift` | `FMToast` / `FMBanner` (success/warning/error/info) + `.fmToastOverlay(toast:)` | `toast = FMToastMessage(.success, "저장됐어요")` |
| `FMSkeleton.swift` | `FMSkeleton` (line/rect/circle, 시머 1.5s, Reduce Motion 정적 fallback) | `FMSkeleton.line(width: 120, height: 14)` |
| `FMEmptyState.swift` | `FMEmptyState` (5종 — 마켓/검색/프로필/다운로드/댓글) | `FMEmptyState(.emptyMarket) { create() }` |
| `FMTabBar.swift` | `FMTabBar` (5탭 + 중앙 56pt 셔터, lift -12pt) | `FMTabBar(selection: $tab) { showCamera = true }` |
| `FMSegmentedControl.swift` | `FMSegmentedControl<Option: Hashable>` (matched geometry 슬라이딩) | `FMSegmentedControl(selection: $sort, options: [...])` |
| `FMAvatar.swift` | `FMAvatar` (xs/sm/md/lg/xl, image/url/initials/symbol) | `FMAvatar(initials: "유나", size: .md)` |
| `FMFilterTile.swift` | `FMFilterTile` (4:5 사진 + 그라디언트 + 카테고리 점) | `FMFilterTile(data: tile) { open() }` |
| `FMTypographyShorthand.swift` | `FMTypography.Style` 정적 alias | `view.fmTypography(.headline)` |

### 가이드라인

- 모든 컴포넌트는 `public init` + `Sendable` 가능한 곳은 `Sendable`.
- 인터랙티브 컴포넌트엔 `.accessibilityLabel(...)` + 적절한 trait.
- 햅틱은 `FMHaptic` wrapper 사용 — 컴포넌트 내부에서 `FMHaptic.light.play()` 형태로 호출 (Phase D6).
- 외부 의존성 X — SwiftUI / Foundation / UIKit 만 사용.

## 모달 (Phase D6)

`Sources/DesignSystem/Modals/` 아래의 4종 표준 wrapper.
`docs/MODAL_PATTERNS.md` 의 결정 기준에 1:1 대응.

| 파일 | API | 용도 |
|---|---|---|
| `FMBottomSheet.swift` | `.fmBottomSheet(isPresented:detents:) { ... }` | 부가 정보, 빠른 액션, 부가 설정 |
| `FMConfirmationDialog.swift` | `.fmConfirmationDialog(_:isPresented:) { actions } message: { ... }` | 옵션 선택 (3~6개) |
| `FMAlert.swift` | `.fmAlert(...)` 일반 / `.fmDestructiveAlert(...:onConfirm:)` 파괴적 단축 | 중요 확인 (삭제·로그아웃 등) |
| `FMShareSheet.swift` | `.fmShareSheet(isPresented:items:)` + `FMShareLinkButton(item:)` | 시스템 공유 |

`fmDestructiveAlert` 는 destructive 탭 시 자동으로 `FMHaptic.warning.play()` 를 호출한다.

## 햅틱 (Phase D6)

`Sources/DesignSystem/HapticEngine.swift` — `FMHaptic` enum + `fmHaptic(_:)` 함수형 단축.
`docs/MOTION_SPEC.md` §7 의 매핑을 그대로 코드화.

```swift
FMHaptic.light.play()       // 일반 버튼 탭
FMHaptic.medium.play()      // 중요 버튼 탭, 셔터, 스와이프 snap
FMHaptic.heavy.play()       // 파괴적 액션
FMHaptic.success.play()     // 저장/다운로드 완료
FMHaptic.warning.play()     // 사진 삭제 직전
FMHaptic.error.play()       // 저장 실패
FMHaptic.selection.play()   // 토글, 칩, picker 변경

fmHaptic(.light)            // 함수형 단축 — 동일 효과
```

모든 호출은 `@MainActor` 에서 즉시 재생되며 — 화면 단의 inline `UIImpactFeedbackGenerator(style:)` 직접 호출은
본 wrapper 로 통일됨 (Phase D6 검증).

## Reduce Motion (Phase D6)

`Sources/DesignSystem/ReduceMotion.swift` — 시스템 모션 줄이기 설정 자동 분기.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// 변환 spring → reduce motion 시 fade 만 남김
withAnimation(reduceMotion ? .fmFast : .fmSpringSwipe) {
    selectedID = nextID
}

// 또는 modifier 형태
myView.fmAnimation(.fmSpringSwipe, value: selectedID)

// transition 분기
.transition(.fmReducible(.move(edge: .trailing), reduceMotion: reduceMotion))
```

### Preview 한눈에 보기

각 파일을 Xcode 에서 열고 Canvas 를 켜면 Light / Dark / 변형 / 상태 그리드 가 나란히 보인다.
시뮬레이터 없이도 시각 검증 가능 (Xcode Previews 만 필요).

## Legacy 토큰 (deprecated)

기존 `DesignTokens.swift` 의 `FMColor` / `FMSpacing` 은 새 토큰을 가리키는 alias 로 유지되며 deprecation 경고를 발생시킨다.
Phase D1 (컴포넌트 라이브러리) 이후 삭제 예정.

## 마이그레이션 매핑

| 기존 (v1.0) | 신규 (v1.2.0) |
|---|---|
| `FMColor.background` | `FMColors.Background.bg0` |
| `FMColor.surface` | `FMColors.Background.bg2` |
| `FMColor.accent` | `FMColors.Accent.primary` |
| `FMSpacing.xSmall` | `Sp.xxs` |
| `FMSpacing.small` | `Sp.xs` |
| `FMSpacing.medium` | `Sp.sm` |
| `FMSpacing.large` | `Sp.lg` |
| `FMSpacing.xLarge` | `Sp.xxl` |
