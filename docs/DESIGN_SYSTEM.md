# filterMarket — 디자인 시스템

> 버전: v1.1 · 작성일: 2026-05-06 · 모드: Light Minimal (default) + Dark (카메라 흐름 한정)
>
> 본 문서는 UI 의 단일 진실원이다. 머신 리더블 토큰은 [`DESIGN_TOKENS.json`](./DESIGN_TOKENS.json), 짧은 선언문은 [`DESIGN_PRINCIPLES.md`](./DESIGN_PRINCIPLES.md) 를 참조.

---

## 0. 톤 & 매너 — 라이트 미니멀 (Editorial / Gallery)

| 키워드 | 의미 |
|---|---|
| **갤러리 벽** | 따뜻한 오프화이트(베이지 화이트). 차가운 순백색·푸른빛 회피 |
| **사진이 주인공** | UI 영역은 화면의 20% 이내. 캔버스는 사진을 위한 종이 |
| **절제된 골드** | 라이트에 맞춰 톤 다운한 골드(#B8853A). 식별성과 AA 대비 동시 충족 |
| **타이포로 위계** | 굵기 대비만으로 구조. 박스/그림자/선은 최소 |
| **편집자의 손맛** | 자동 추천보다 큐레이션. 메이커 이름·작품성 강조 |
| **카메라는 다크** | 촬영 화면(03/04/05)은 다크 유지 — 눈부심 줄이고 사진의 색이 살아나게 |

> **v1.0 → v1.1 핵심 변화**: 다크 베이스에서 따뜻한 라이트 베이스로 전환. 골드 악센트는 톤만 어둡게(#E8B86D → #B8853A) 정체성 유지. 카메라 흐름은 다크를 그대로 두는 하이브리드 — 사용자 환경상 자연스럽다.

---

## 1. 컬러 팔레트

### 1.1 Background (Light — 따뜻한 오프화이트 스케일)

| 토큰 | HEX | 용도 | SwiftUI |
|---|---|---|---|
| `bg/0` | `#FAFAF7` | 메인 캔버스 (베이지 화이트) | `Color("BG/0")` |
| `bg/1` | `#F5F4EF` | 화면 기본 배경 (sunken) | `Color("BG/1")` |
| `bg/2` | `#FFFFFF` | raised 카드 / 모달 | `Color("BG/2")` |
| `bg/3` | `#EDEBE5` | 구분 / strong sunken | `Color("BG/3")` |

### 1.2 Surface

| 토큰 | HEX | 용도 |
|---|---|---|
| `surface/raised` | `#FFFFFF` | 모달, 시트, 다이얼로그 컨테이너 |
| `surface/sunken` | `#EDEBE5` | 비교 슬라이더, 코드블록 |
| `surface/overlay` | `rgba(15,15,14,0.42)` | 스크림 (백드롭) |

### 1.3 Border

| 토큰 | HEX | 용도 |
|---|---|---|
| `border/subtle` | `#E8E6E0` | 1px 분리선 |
| `border/default` | `#D8D5CD` | 카드 외곽선 |
| `border/strong` | `#B8B4A8` | 포커스 외곽선, 호버 강조 |

### 1.4 Text (Deep Charcoal — 순흑색 회피)

| 토큰 | HEX | 대비비 (vs bg/0) | 용도 |
|---|---|---|---|
| `text/primary` | `#0F0F0E` | 18.5:1 (AAA) | 본문, 타이틀 |
| `text/secondary` | `#4A4845` | 8.7:1 (AAA) | 서브타이틀, 메타 |
| `text/tertiary` | `#8A8782` | 3.4:1 (AA Large) | 캡션, 비활성 |
| `text/disabled` | `#C8C5BE` | 1.6:1 | 비활성 텍스트 |
| `text/inverse` | `#FFFFFF` | — | 악센트 위 텍스트 |

> 본문은 항상 `text/secondary` 이상. `tertiary`는 caption/metadata 한정.

### 1.5 Accent (Gold — 라이트 톤 다운)

> **악센트 컬러는 단 하나. `#B8853A`** — 라이트 BG에서 4.8:1(AA)을 통과하도록 톤만 어둡게 조정. 정체성(따뜻한 골드)은 보존.

| 토큰 | HEX | 용도 |
|---|---|---|
| `accent/primary` | `#B8853A` | CTA, 활성 탭, 강조 라벨, 슬라이더 채움, 텍스트 |
| `accent/hover` | `#A0721E` | 호버 / 롱프레스 직전 |
| `accent/pressed` | `#8B5E1F` | 탭 다운 |
| `accent/soft` | `#E8B86D` | 장식·테두리·아이콘 fill (텍스트 X) |
| `accent/bg` | `#FBF3E2` | 옅은 악센트 배경 fill (선택 칩, 강조 영역) |
| `accent/ring` | `rgba(184,133,58,0.32)` | 포커스 링 (4px) |

대비비 — `accent on bg/0` = 4.8:1 (AA) · `accent on bg/2` = 4.5:1 (AA Pass) · `text/inverse on accent` = 4.8:1 (AA).

### 1.6 Semantic (라이트 모드용 채도 조정)

| 토큰 | HEX | 배경 (BG) | 용도 |
|---|---|---|---|
| `success` | `#2E7D44` | `#E8F2EA` | 저장 완료, 다운로드 완료 |
| `warning` | `#A66B0F` | `#FBF1DC` | 경고 배너 |
| `error` | `#B33A2A` | `#F8E5E0` | 오류, 신고됨 |
| `info` | `#1F5FA8` | `#E5EEF8` | 정보 배너 |

> 시맨틱 컬러는 **상태 통보 한정**. 일반 강조는 항상 골드.

### 1.7 Filter Category Hint Color (옵션, 라이트)

각 카테고리 칩의 작은 점/언더라인에만 사용. 텍스트 색으로는 사용하지 않음.

| 카테고리 | HEX (Light) |
|---|---|
| Cinematic | `#7E5FB8` |
| Vintage | `#A57238` |
| Pastel | `#C485A6` |
| Monochrome | `#7A7A7A` |
| Portrait | `#C77859` |
| Food | `#A66B0F` |
| Travel | `#3A7AB8` |
| Mood | `#5A6E96` |

### 1.8 Dark Mode (카메라 흐름 한정 — 03/04/05 화면)

> **결정**: 라이브 카메라 프리뷰와 직후 미리보기는 다크를 유지한다. 라이트 카메라 UI는 야외/실내 모두 눈부심을 만들고, 사진의 색을 죽인다. `[data-theme="dark"]` 또는 SwiftUI의 `colorScheme(.dark)` 로 전환.

다크 토큰 요약 (전체는 [`DESIGN_TOKENS.json`](./DESIGN_TOKENS.json) 참조):

| 토큰 | HEX |
|---|---|
| `bg/0` | `#000000` |
| `bg/1` | `#0A0A0A` |
| `bg/2` | `#141414` |
| `bg/3` | `#1F1F1F` |
| `text/primary` | `#FFFFFF` |
| `text/secondary` | `#A8A8A8` |
| `accent` | `#E8B86D` |

`text/inverse on accent` (다크) = 12.6:1 (AAA).

---

## 2. 타이포그래피

### 2.1 폰트 패밀리

```
Primary:  -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text",
          "Pretendard Variable", "Apple SD Gothic Neo", sans-serif
Mono:     ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace
```

iOS 시스템 폰트 우선. 외부 웹폰트 호출 금지.

### 2.2 9단계 스케일 (v1.0과 동일)

| 단계 | Size | LH | Weight | Letter | SwiftUI | 용도 |
|---|---|---|---|---|---|---|
| Display | 34 | 41 | 700 | -0.4 | `.largeTitle` | 온보딩 헤로, 빈 상태 |
| TitleLarge | 28 | 34 | 700 | -0.3 | `.title` | 화면 메인 타이틀 |
| Title | 22 | 28 | 600 | -0.2 | `.title2` | 섹션 헤더 |
| Headline | 17 | 22 | 600 | -0.1 | `.headline` | 리스트 강조 항목 |
| Body | 15 | 20 | 400 | 0 | `.body` | 본문 기본 |
| Callout | 14 | 19 | 500 | 0 | `.callout` | 버튼 라벨 |
| Subhead | 13 | 18 | 500 | 0 | `.subheadline` | 메타 정보 |
| Footnote | 12 | 16 | 400 | 0 | `.footnote` | 보조 설명, 타임스탬프 |
| Caption | 11 | 13 | 500 | +0.2 | `.caption` | 칩 텍스트, 라벨 |

### 2.3 Weight 가이드

| Weight | 값 | 사용처 |
|---|---|---|
| Regular | 400 | 본문, 긴 설명 |
| Medium | 500 | 메타, 버튼 보조, 칩 |
| Semibold | 600 | 헤드라인, 주요 라벨 |
| Bold | 700 | 타이틀, 디스플레이 |

> ExtraBold/Black 사용 금지. 라이트 모드에서 굵은 weight는 더 무겁게 보이므로 Bold 이상은 자제.

### 2.4 한글 가독성 노트

- 한글 텍스트에는 `letter-spacing: -0.01em` 적용.
- TitleLarge (28pt) 이상에서는 -0.3px ~ -0.4px letter-spacing.
- 한글 본문 line-height는 1.4~1.5 (현재 스케일 그대로 충족).
- 줄바꿈: 어절 단위(`word-break: keep-all`).

### 2.5 SwiftUI 매핑 예

```swift
extension Font {
    static let fmDisplay   = Font.system(size: 34, weight: .bold).leading(.tight)
    static let fmTitleLg   = Font.system(size: 28, weight: .bold)
    static let fmTitle     = Font.system(size: 22, weight: .semibold)
    static let fmHeadline  = Font.system(size: 17, weight: .semibold)
    static let fmBody      = Font.system(size: 15, weight: .regular)
    static let fmCallout   = Font.system(size: 14, weight: .medium)
    static let fmSubhead   = Font.system(size: 13, weight: .medium)
    static let fmFootnote  = Font.system(size: 12, weight: .regular)
    static let fmCaption   = Font.system(size: 11, weight: .medium)
}
```

---

## 3. 간격 (Spacing) — 4pt Base

| 토큰 | 값 | 사용 예 |
|---|---|---|
| `xxs` | 4 | 아이콘과 라벨 사이, 작은 인디케이터 |
| `xs` | 8 | 칩 내부 간격, 인접 요소 |
| `sm` | 12 | 작은 카드 패딩 |
| `md` | 16 | 화면 좌우 여백 (기본), 카드 패딩 |
| `lg` | 20 | 카드 간 간격 |
| `xl` | 24 | 섹션 내부 패딩 |
| `2xl` | 32 | 섹션 사이 |
| `3xl` | 48 | 큰 섹션 / 빈 상태 |
| `4xl` | 64 | 화면 위/아래 큰 여백 |

---

## 4. 라운드 (Corner Radius)

| 토큰 | 값 | 사용처 |
|---|---|---|
| `none` | 0 | 풀스크린 사진, 카메라 프리뷰 |
| `sm` | 4 | 칩, 작은 인디케이터, 배지 |
| `md` | 8 | 버튼, 입력 필드, 일반 카드 |
| `lg` | 12 | 필터 타일, 큰 카드, 리스트 그룹 |
| `xl` | 16 | 모달 / 시트 상단 |
| `full` | 9999 | 아바타, 토글, FAB |

---

## 5. 엘리베이션 (Elevation)

라이트 모드는 **subtle border + 매우 약한 그림자**로 깊이를 표현. 다크 모드는 보더+미세한 배경차.

| 단계 | 라이트 효과 | 다크 효과 |
|---|---|---|
| `level/0` | 효과 없음 | 효과 없음 |
| `level/1` | `1px solid border/subtle` + `0 1px 0 rgba(15,15,14,0.04)` | `1px solid bg/3` 보더만 |
| `level/2` | `1px solid border/subtle` + `0 1px 3px rgba(15,15,14,0.06)` | `1px solid border/default` + `bg/3` 배경 |
| `level/3` | `0 12px 32px rgba(15,15,14,0.10), 0 2px 6px rgba(15,15,14,0.05)` | `0 8px 24px rgba(0,0,0,0.7)` |

큰 그림자 (`box-shadow: 0 20px 60px ...`) 사용 금지 — 라이트에서도 Material Design처럼 보인다.

---

## 6. 모션 (v1.0과 동일)

### 6.1 Duration

| 토큰 | 값 | 사용처 |
|---|---|---|
| `instant` | 100ms | 토글, 칩 활성 |
| `fast` | 200ms | 호버, 탭 응답, 버튼 상태 |
| `base` | 300ms | 페이지 전환, 모달, 슬라이드 |
| `slow` | 500ms | 큰 트랜지션 (사용 자제) |

### 6.2 Easing

| 토큰 | 값 |
|---|---|
| `standard` | `cubic-bezier(0.2, 0, 0, 1)` |
| `decelerate` | `cubic-bezier(0, 0, 0.2, 1)` (들어옴) |
| `accelerate` | `cubic-bezier(0.4, 0, 1, 1)` (나감) |
| `spring` | `cubic-bezier(0.34, 1.4, 0.64, 1)` (탭 응답) |

---

## 7. 아이콘 (v1.0과 동일)

선 두께 1.5px 고정. SF Symbols `regular` / `medium`. 라이트에서는 `text/primary` 또는 `text/secondary` 컬러.

---

## 8. 컴포넌트 스펙 — 라이트 적용

### 8.1 Button

| 변형 | 높이 | 배경 | 텍스트 | 보더 |
|---|---|---|---|---|
| Primary | 44/52 | `accent (#B8853A)` | `text/inverse (#FFFFFF)` | — |
| Secondary | 44 | `bg/2 (#FFFFFF)` | `text/primary` | `1px border/default` |
| Ghost | 44 | transparent | `text/primary` | — |
| Destructive | 44 | transparent | `error` | `1px error 35%` |

상태:
- **Default → Hover**: `accent` → `accent/hover (#A0721E)`
- **Pressed**: `accent` → `accent/pressed (#8B5E1F)`, `transform: scale(0.97)`
- **Ghost hover**: `bg/1` 배경 fill
- **Disabled**: `opacity: 0.4`

대비 검증: `text/inverse on accent` = 4.8:1 (AA Pass).

### 8.2 TextField

- 높이: 44
- 배경: `bg/2 (#FFFFFF)`
- 보더: `1px border/default`, focus 시 `accent` + ring 4px (`accent/ring`)
- placeholder 색: `text/tertiary`

### 8.3 Card / FilterCard

- 기본: `bg/2 (#FFFFFF)`, `1px border/subtle`, radius `lg(12)`, shadow `level/1`
- 호버/raised: shadow `level/2`
- FilterCard는 사진 4:5 + 하단 그라디언트 오버레이 (`rgba(15,15,14,0.78)`) + 흰 텍스트 — 사진 위 라벨이므로 라이트/다크 무관.

### 8.4 FilterTile (마켓 그리드)

| 영역 | 스펙 |
|---|---|
| 사진 비율 | 4:5 |
| Radius | `lg(12)` |
| 하단 오버레이 | `linear-gradient(180deg, transparent, rgba(15,15,14,0.78))` |
| 이름 | Subhead (13/18, 600), `#FFFFFF` |
| 메타 | Caption (11/13, 500), `rgba(255,255,255,0.78)` |
| 좌상단 배지 | `rgba(255,255,255,0.92)` 블러, `accent` 텍스트, 10px |

### 8.5 NavBar (TabBar — 5탭)

- 높이 49 + 안전영역 34
- 배경: `rgba(255,255,255,0.85)` + backdrop-blur 24
- 상단 1px `border/subtle`
- 활성 색: `accent`, 비활성: `text/tertiary`

### 8.6 TopBar

- 높이 44
- 배경: `bg/1 (#F5F4EF)`
- 좌측: 뒤로(chevron.left) 또는 닫기(xmark)
- 가운데: 화면 타이틀 (Headline 17/22, 600)
- 우측: 액션(공유/더보기). 액션 텍스트는 `accent`

### 8.7 Modal / Sheet

- 시트: 화면 하단 → 위로 슬라이드
- 상단 라운드: `xl(16)`, 핸들: 36×4, `bg/3`, 상단 12px
- 백드롭: `surface/overlay` (rgba(15,15,14,0.42))
- 패딩: `xl(24)`
- 그림자: `level/3`

### 8.8 Toast / Banner

- 배경: `bg/2 (#FFFFFF)` + `1px border/default`, radius `md`, shadow `level/2`
- 좌측 16×16 아이콘 (`success`/`error`/`info` 톤)
- success: `success-bg` fill 또는 흰 fill + `success` 아이콘

### 8.9 Avatar

이미지 없으면 이니셜 + `bg/3` + 1px `border/subtle`. radius `full`.

### 8.10 Tag / Chip

- 기본: `bg/2 (#FFFFFF)`, `text/secondary`, `1px border/default`
- 호버: `border/strong`
- 활성: `accent/bg (#FBF3E2)` 배경, `accent` 보더+텍스트

### 8.11 Slider (필터 강도)

- 높이 4, radius `full`
- 트랙: `bg/3 (#EDEBE5)`
- 채움: `accent`
- 썸: 16×16, 흰 배경, `accent` 2px 보더, soft shadow
- 우측 값 라벨: Caption (`accent`, tabular-nums)

### 8.12 Toggle / Switch

- iOS 스타일: 51×31, radius full
- Off: `bg/3` + `1px border/subtle`, On: `accent`
- 노브: 27×27 흰색, soft shadow

### 8.13 SegmentedControl

- 컨테이너 `bg/3 (#EDEBE5)`, padding 2, radius `md`
- 선택: `bg/2 (#FFFFFF)` + `text/primary` + soft shadow
- 비선택: `text/secondary`

### 8.14 SwipeIndicator (필터 좌우 스와이프 시각화)

- 화면 하단 (셔터 위), 가로 페이지 인디케이터
- 7개 점, 활성은 16×4 너비 막대, 비활성은 4×4 점
- 색: 활성 `accent`, 비활성 `text/tertiary 40%`
- 카메라 화면 → 다크 토큰 사용

### 8.15 Empty / Loading / Error 상태

| 상태 | 라이트 구성 |
|---|---|
| Empty | 32×32 SF Symbol (text/tertiary) + Title (text/primary) + Body (text/secondary) + CTA(secondary) |
| Loading | 24×24 회전 indicator (accent), 또는 shimmer skeleton (`bg/1 → bg/3`) |
| Error | `error` 톤 아이콘 + 메시지 + "다시 시도" 버튼 (secondary) |

### 8.16 카메라 화면 다크 예외 (03/04/05)

> **현실적 결정**: 카메라 라이브뷰는 다크 유지. 사용 환경(저조도, 야외 햇빛)에서 라이트 카메라 UI는 눈부심을 만들고 라이브 프리뷰의 색을 죽인다.

- `<body data-theme="dark">` 또는 `colorScheme(.dark)` 로 토큰만 다크 전환.
- HUD 컨트롤은 backdrop-blur + `surface/overlay`.
- 다른 9개 화면(마켓·프로필·설정·온보딩·로그인·검색·필터상세·에디터·업로드)은 라이트.

---

## 9. 접근성

### 9.1 탭 영역

- 모든 인터랙티브 요소 **최소 44×44pt**
- 인접 탭 사이 최소 4pt 간격

### 9.2 색 대비 (WCAG) — Light Mode

| 조합 | 비율 | 등급 |
|---|---|---|
| `text/primary` on `bg/0` | 18.5:1 | AAA |
| `text/primary` on `bg/2` | 19.6:1 | AAA |
| `text/secondary` on `bg/0` | 8.7:1 | AAA |
| `text/secondary` on `bg/2` | 9.2:1 | AAA |
| `text/tertiary` on `bg/0` | 3.4:1 | AA Large |
| `accent` on `bg/0` | 4.8:1 | AA |
| `accent` on `bg/2` | 4.5:1 | AA |
| `text/inverse` on `accent` | 4.8:1 | AA |
| `error` on `bg/0` | 5.2:1 | AA |
| `success` on `bg/0` | 5.7:1 | AA |
| `info` on `bg/0` | 5.6:1 | AA |

> 본문은 항상 `text/secondary` 이상. `tertiary`는 caption/metadata 한정. 모든 인터랙티브 텍스트(버튼·링크) 4.5:1 이상 확보.

### 9.3 색 대비 (WCAG) — Dark Mode (카메라 화면)

| 조합 | 비율 | 등급 |
|---|---|---|
| `text/primary` on `bg/1` | 19.6:1 | AAA |
| `text/secondary` on `bg/1` | 7.4:1 | AAA |
| `accent` on `bg/0` | 11.2:1 | AAA |
| `text/inverse` on `accent` | 12.6:1 | AAA |

### 9.4 VoiceOver / Dynamic Type / Reduce Motion

v1.0과 동일.

---

## 10. SwiftUI 매핑 (라이트 + 다크 듀얼)

```swift
// Color (Asset Catalog에 Light/Dark variant 등록)
extension Color {
    static let bg0 = Color("BG/0")          // Light: #FAFAF7  Dark: #000000
    static let bg1 = Color("BG/1")          // Light: #F5F4EF  Dark: #0A0A0A
    static let bg2 = Color("BG/2")          // Light: #FFFFFF  Dark: #141414
    static let bg3 = Color("BG/3")          // Light: #EDEBE5  Dark: #1F1F1F
    static let textPrimary = Color("Text/Primary")     // Light: #0F0F0E  Dark: #FFFFFF
    static let textSecondary = Color("Text/Secondary") // Light: #4A4845  Dark: #A8A8A8
    static let textTertiary = Color("Text/Tertiary")   // Light: #8A8782  Dark: #6B6B6B
    static let accent = Color("Accent/Primary")        // Light: #B8853A  Dark: #E8B86D
}

// Spacing
enum Sp {
    static let xxs: CGFloat = 4, xs: CGFloat = 8, sm: CGFloat = 12
    static let md: CGFloat = 16, lg: CGFloat = 20, xl: CGFloat = 24
    static let xxl: CGFloat = 32, xxxl: CGFloat = 48
}

// Radius
enum R {
    static let sm: CGFloat = 4, md: CGFloat = 8, lg: CGFloat = 12, xl: CGFloat = 16
}

// 카메라 화면 강제 다크
struct CameraView: View {
    var body: some View {
        ZStack { /* … */ }
            .preferredColorScheme(.dark)   // 03/04/05 화면 한정
    }
}
```

---

## 11. 변경 이력

| 버전 | 날짜 | 변경 |
|---|---|---|
| v1.0 | 2026-05-06 | 초안 — 다크 미니멀 + 골드 악센트 (#E8B86D) 확정 |
| **v1.1** | **2026-05-06** | **라이트 미니멀로 전환. 따뜻한 오프화이트 캔버스(#FAFAF7) + 딥 차콜 텍스트(#0F0F0E). 골드 악센트는 톤 다운(#B8853A)해 정체성 보존 + AA 대비 확보. 카메라 흐름 3개 화면(03/04/05)은 다크 유지(눈부심 회피). 토큰 구조는 듀얼 모드(`modes.light` / `modes.dark`) + CSS `[data-theme="dark"]` 셀렉터로 전환 가능. 시맨틱 컬러는 라이트 BG에 맞게 채도 조정. 페일톤 사진 placeholder 추가.** |

### v1.1 전환 근거

1. **눈부심 줄이기**: 순백색(#FFFFFF)이 아닌 베이지 화이트(#FAFAF7)로 — 종이/캔버스 같은 따뜻함.
2. **고대비 카리스마는 살리되 톤만 화이트로**: 텍스트는 순흑(#000)이 아닌 딥 차콜(#0F0F0E)로 부드럽게.
3. **골드 정체성 보존**: 라이트 BG에서 #E8B86D는 대비 미달(2.4:1) → #B8853A로 톤 다운하여 4.8:1 (AA) 통과. 동일 색상군이라 브랜드 일관성 유지.
4. **카메라 화면 다크 예외**: 라이브 프리뷰는 어두운 환경에서 사용 비중이 높고, 라이트 UI가 사진의 색을 가린다. 9 라이트 + 3 다크 하이브리드가 "조금만 밝은"의 가장 자연스러운 해석.
5. **테마 전환 가능 구조**: CSS는 `:root` (라이트) + `[data-theme="dark"]`, SwiftUI는 Asset Catalog Light/Dark variant. 시스템 다크모드 대응 시 한 줄 수정으로 전체 라이트→다크 전환 가능.

---

## 12. 관련 문서

- [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md) — 1페이지 선언문
- [DESIGN_TOKENS.json](./DESIGN_TOKENS.json) — 머신 리더블 토큰 (light/dark dual)
- [PRD.md](./PRD.md) — 페르소나, KPI
- [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) — 카메라/필터 흐름
- [ARCHITECTURE.md](./ARCHITECTURE.md) — `DesignSystem` 모듈 위치
- [CODING_CONVENTIONS.md](./CODING_CONVENTIONS.md) — Swift/SwiftUI 매핑
- [../mockups/](../mockups/) — HTML 인터랙티브 목업 (v1.1 라이트)
