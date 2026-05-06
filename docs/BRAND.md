# Moodit — Brand Guide

> 버전: v0.3 · 작성일: 2026-05-06 · 상태: 초안 (피드백 후 v0.4)
>
> 이 문서는 Moodit의 로고·심볼·워드마크 사용 규칙이다. 자산 파일은 [`../mockups/brand/`](../mockups/brand/)에 있고, 시각 카탈로그는 [`brand/preview.html`](../mockups/brand/preview.html)을 브라우저에서 열어 확인한다.

---

## 1. 컨셉 — "Twin Lens"

`moodit`이라는 이름의 한가운데에 있는 `oo`. 이 두 개의 원을 그대로 들어올린 것이 심볼이다.

| 원 | 의미 |
|---|---|
| **외곽선 (`fill: none`, gold stroke)** | 보는 눈 — 사진을 감상하는 사람, 큐레이터, 마켓의 둘러보는 사용자 |
| **채움 (gold solid)** | 담는 눈 — 셔터를 누른 사람, 메이커, 결정의 순간 |

두 원이 짝을 이루는 형태는 메이커×촬영자 양면 마켓 컨셉을 한 시각 단위로 압축한다.

### 두 원의 시각 크기 일치 (v0.3 보정)

외곽선 원은 SVG의 stroke가 반경 외부로 절반(0.5 × stroke-width)만큼 추가로 그려지므로, 같은 `r` 값이라도 채움 원보다 시각적으로 커 보인다. v0.3에서는 외곽선 원의 `r`을 (stroke-width ÷ 2)만큼 줄여 **두 원의 시각적 외곽 지름이 정확히 같도록** 맞췄다.

| 컨텍스트 | 외곽선 원 | 채움 원 | 시각 외곽 지름 |
|---|---|---|---|
| 64u 심볼 | r=9.75, stroke=2.5 | r=11 | 22u |
| 120u 락업 | r=12.5, stroke=3 | r=14 | 28u |
| 1024u 앱 아이콘 | r=162, stroke=36 | r=180 | 360u |

---

## 2. 자산 파일

| 파일 | 용도 | viewBox |
|---|---|---|
| `symbol.svg` | 가로형 심볼 (기본) | `0 0 64 32` |
| `symbol-square.svg` | 정방형 컨테이너용 | `0 0 64 64` |
| `symbol-mono.svg` | `currentColor` 단색 (다크/포일/스탬프) | `0 0 64 32` |
| `wordmark.svg` | "moodit" 단독 | `0 0 360 90` |
| `lockup-horizontal.svg` | 심볼 + 워드마크 가로 (기본) | `0 0 480 120` |
| `lockup-vertical.svg` | 심볼 + 워드마크 세로 | `0 0 320 240` |
| `app-icon-light.svg` | iOS 앱 아이콘 라이트 | `0 0 1024 1024` |
| `app-icon-dark.svg` | iOS 앱 아이콘 다크 | `0 0 1024 1024` |
| `app-icon-tinted.svg` | iOS 18+ Tinted 슬롯 | `0 0 1024 1024` |
| `coin.svg` | Coin 화폐 아이콘 — 골드 디스크 + 흰 "M" ([CURRENCY_DESIGN.md](./CURRENCY_DESIGN.md)) | `0 0 24 24` |

PNG 변환은 빌드 시:

```bash
brew install librsvg
for variant in light dark tinted; do
  rsvg-convert -w 1024 -h 1024 \
    mockups/brand/app-icon-${variant}.svg \
    -o build/AppIcon-${variant}.png
done
```

---

## 3. 색

| 토큰 | HEX | 용도 |
|---|---|---|
| `accent (light)` | `#B8853A` | 라이트 컨텍스트의 모든 골드 마크 |
| `accent (dark)` | `#E8B86D` | 다크 컨텍스트의 모든 골드 마크 |
| `text/primary` | `#0F0F0E` | 라이트의 워드마크 색 |
| `bg/0` | `#FAFAF7` | 워드마크 배경(메인 캔버스) |
| `bg/1` | `#F5F4EF` | 앱 아이콘 라이트 배경 |
| `#000000` | — | 앱 아이콘 다크 배경 |

> **단일 액센트 원칙** ([`DESIGN_PRINCIPLES.md`](./DESIGN_PRINCIPLES.md) §3): 골드 외 다른 강조색을 절대 추가하지 않는다. 두 번째 색은 식별성을 흐린다.

---

## 4. 사용 규칙

### 4.1 클리어 스페이스

- 심볼/로고 주변에 **심볼 높이의 1배** 만큼 비워두기.
- 다른 텍스트, 사진 가장자리, 스크롤 가능한 콘텐츠가 이 영역에 침범하지 않는다.

### 4.2 최소 크기

| 자산 | 최소 표시 크기 |
|---|---|
| 심볼 단독 | **16px** (rendering 가능 한계) |
| 워드마크 | **80px width** (글자 깨짐 방지) |
| 가로 락업 | **120px width** |
| 세로 락업 | **80px width** |

미만 크기에서는 심볼만 사용하고, 워드마크는 별도 라인에 노출.

### 4.3 회전·기울이기 금지

심볼은 항상 수평. 회전·기울임·미러링 금지. 어떤 변형도 브랜드 일관성을 깨뜨린다.

### 4.4 색 대체 금지

- 골드 외 다른 색으로 마크 채우기 금지 (단, 단색 컨텍스트의 `currentColor` 모노 변형은 허용).
- 그라디언트, 글로우, 외곽선 추가 금지.
- 사진 위 합성은 허용되되 **반드시 충분한 contrast**가 있는 영역에 한함.

### 4.5 워드마크 변형 금지

- "moodit"는 항상 소문자.
- 글자 사이 간격, 굵기, 폰트 변경 금지.
- "Moodit" 같은 첫글자 대문자 표기는 산문에서만 (UI 자산에서는 lowercase 고수).

---

## 5. 컨텍스트별 권장

| 컨텍스트 | 자산 |
|---|---|
| iOS 앱 아이콘 | `app-icon-light.svg` / `dark` / `tinted` (Asset Catalog 3개 슬롯) |
| 스플래시 화면 | `lockup-vertical.svg` (가운데 정렬) |
| 마켓 헤더 / TopBar 좌측 | `lockup-horizontal.svg` 작게 (44pt 높이 기준) |
| 사진 워터마크 | `symbol.svg` 우하단 4% 영역 (60% opacity) |
| 공유 카드 (OG 이미지) | `lockup-horizontal.svg` 중앙 + bg-1 배경 |
| Apple Watch | `symbol-square.svg` (centerline 정렬) |
| 즐겨찾기 / 단축어 아이콘 | `symbol-square.svg` (정사각 컨테이너 안) |
| 다크 컨텍스트 임베드 | `symbol-mono.svg` (`color: var(--accent-soft)`) |

---

## 6. 워드마크 타이포 디테일

| 속성 | 값 |
|---|---|
| 폰트 패밀리 | `-apple-system, "SF Pro Display", "Pretendard Variable", "Apple SD Gothic Neo", system-ui, sans-serif` |
| 굵기 | 700 (Bold) |
| 케이스 | 모두 lowercase |
| 트래킹 | -3 (SVG 단위) ≈ -0.054em at 56px |
| 베이스라인 | y=62 in 90 viewBox |
| 색 | `text/primary (#0F0F0E)` (라이트) / `#FFFFFF` (다크) / `text/inverse (#FFFFFF)` (악센트 위) |

> **향후 작업**: v1.0에서 커스텀 글리프 (특히 `oo` 자체를 심볼과 일치시키는 ligature)로 전환 검토. 현재는 시스템 폰트로 시작.

---

## 7. 다음 단계

- [ ] PNG 라스터 (1024×1024 + 512×512 + 180×180 + 120×120) 생성 → `Sources/App/Resources/Assets.xcassets/AppIcon.appiconset/`
- [ ] 워드마크 OG 이미지 (1200×630) 생성 → `mockups/brand/og-image-{light,dark}.svg`
- [ ] 명함·이메일 서명 템플릿 작성 (별도 문서)
- [ ] (v1.0) 커스텀 워드마크 글리프 — `moodit`의 `oo`를 심볼과 같은 비율로
- [ ] (v1.0) 음수 공간(negative space) 변형 — 채움 원의 안쪽이 비어 있는 변형으로 갤러리 톤 강화

---

## 8. 관련 문서

- [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md) — 색·간격·타이포 토큰
- [`DESIGN_PRINCIPLES.md`](./DESIGN_PRINCIPLES.md) — 절제·골드 단일 등 원칙
- [`DESIGN_TOKENS.json`](./DESIGN_TOKENS.json) — 머신 리더블 토큰
- [`../mockups/brand/preview.html`](../mockups/brand/preview.html) — 시각 카탈로그

---

## 9. iOS 통합

### 9.1 Asset Catalog 위치

`Sources/App/Resources/Assets.xcassets/` — `moodit` 앱 타깃의 resources build phase 에 자동 포함 (xcodegen 인식). `project.yml` 에서 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` 설정.

### 9.2 자산 카탈로그 구조

| 슬롯 | 종류 | 원본 | 비고 |
|---|---|---|---|
| `AppIcon.appiconset` | iOS 17+ 단일 1024×1024 PNG | `mockups/brand/app-icon-{light,dark,tinted}.svg` | iOS 18 Light/Dark/Tinted 3 슬롯, `tools/render-app-icon.swift` 가 Core Graphics 로 생성 |
| `MooditSymbol.imageset` | 벡터 SVG | `symbol.svg` | `preserves-vector-representation: true` |
| `MooditSymbolMono.imageset` | 벡터 SVG | `symbol-mono.svg` | template-rendering — `.foregroundStyle()` 으로 색 지정 |
| `MooditWordmark.imageset` | 벡터 SVG | `wordmark.svg` | "moodit" 글자 로고 |
| `MooditLockupHorizontal.imageset` | 벡터 SVG | `lockup-horizontal.svg` | TopBar 등 가로 헤더용 |
| `MooditLockupVertical.imageset` | 벡터 SVG | `lockup-vertical.svg` | 스플래시·로그인 중앙 정렬 |

> Asset Catalog 안의 SVG 는 `mockups/brand/` 의 단일 진실원에서 **복사**해 둔 것이다. 디자인 변경 시 mockups/brand/ 를 수정한 뒤 image set 안의 사본을 갱신한다.

### 9.3 SwiftUI 사용 예

```swift
// 워드마크 (라이트 컨텍스트)
Image("MooditWordmark")
    .resizable()
    .scaledToFit()
    .frame(height: 28)

// 가로 락업 — 마켓 헤더
Image("MooditLockupHorizontal")
    .resizable()
    .scaledToFit()
    .frame(height: 32)

// 세로 락업 — 로그인 / 스플래시
Image("MooditLockupVertical")
    .resizable()
    .scaledToFit()
    .frame(maxWidth: 220, maxHeight: 160)

// 단색 심볼 — 사용자 색에 맞춰 틴트
Image("MooditSymbolMono")
    .renderingMode(.template)
    .resizable()
    .scaledToFit()
    .frame(width: 24, height: 12)
    .foregroundStyle(FMColors.Accent.primary)
```

### 9.4 App Icon PNG 재생성

```bash
swift tools/render-app-icon.swift light  Sources/App/Resources/Assets.xcassets/AppIcon.appiconset/app-icon-light.png
swift tools/render-app-icon.swift dark   Sources/App/Resources/Assets.xcassets/AppIcon.appiconset/app-icon-dark.png
swift tools/render-app-icon.swift tinted Sources/App/Resources/Assets.xcassets/AppIcon.appiconset/app-icon-tinted.png
```

`rsvg-convert` (Homebrew librsvg) 가 설치돼 있다면 SVG 직접 변환도 가능하지만, 현재 도구는 Core Graphics 로 두 원을 직접 그려 외부 의존성이 없다. SVG 디자인이 바뀌면 `tools/render-app-icon.swift` 의 좌표·반지름·색을 함께 갱신.

### 9.5 통합된 화면

| 화면 | 자산 | 위치 |
|---|---|---|
| `LoginScreen` | `MooditLockupVertical` | 중앙 brand section (이전 SF Symbol placeholder 대체) |
| `OnboardingScreen` | `MooditWordmark` | TopBar 좌측 (높이 20pt) |
