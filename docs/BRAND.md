# Moodit — Brand Guide

> 버전: v0.1 · 작성일: 2026-05-06 · 상태: 초안 (피드백 후 v0.2)
>
> 이 문서는 Moodit의 로고·심볼·워드마크 사용 규칙이다. 자산 파일은 [`../mockups/brand/`](../mockups/brand/)에 있고, 시각 카탈로그는 [`brand/preview.html`](../mockups/brand/preview.html)을 브라우저에서 열어 확인한다.

---

## 1. 컨셉 — "Twin Lens"

`moodit`이라는 이름의 한가운데에 있는 `oo`. 이 두 개의 원을 그대로 들어올린 것이 심볼이다.

| 원 | 의미 |
|---|---|
| 외곽선 (`fill: none`, gold stroke) | **보는 눈** — 사진을 감상하는 사람, 큐레이터, 마켓의 둘러보는 사용자 |
| 채움 (gold solid) | **담는 눈** — 셔터를 누른 사람, 메이커, 결정의 순간 |

두 원이 짝을 이루는 형태는 메이커×촬영자 양면 마켓 컨셉을 한 시각 단위로 압축한다.

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
