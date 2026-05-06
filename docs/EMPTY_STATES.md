# moodit — 빈 상태 명세

> 버전: v1.2 · 작성일: 2026-05-06
> `mockups/screens/states-catalog.html` §1 Empty States 와 1:1 매핑.
> 컬러·타이포·간격 토큰은 [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md) 참조.

---

## 개요

빈 상태는 "콘텐츠가 없음"을 단순 통보하는 것이 아니라 **다음 행동으로 안내하는 진입점**이다.

공통 구조:
```
[일러스트 — 골드 악센트 선화]
[헤드라인 — 17px Semibold]
[서브텍스트 — 15px Regular, text/secondary]
[CTA 버튼 — 선택적]
```

공통 규칙:
- 일러스트 높이: 96~120pt
- 헤드라인: `fmHeadline` (17/22, Semibold), `text/primary`
- 서브텍스트: `fmBody` (15/20, Regular), `text/secondary`, 최대 2줄, `word-break: keep-all`
- CTA: Primary 버튼 (선택적), 반드시 골드(`accent`)
- 전체 컨테이너: 화면 세로 중앙 정렬, 좌우 패딩 `sp/2xl (32pt)`

---

## ES-01. 빈 마켓플레이스

### 트리거 조건

- 필터가 하나도 등록되지 않은 초기 서버 상태 (서비스 런칭 초기)
- 선택한 카테고리 칩 내에 아직 필터가 없음
- 네트워크 오류로 필터 목록 로드 실패

### 헤드라인

> 아직 올라온 필터가 없어요

### 서브텍스트

> 첫 메이커가 되어보세요.\n독창적인 필터를 만들고 세상에 선보이세요.

### CTA

- Primary: **필터 만들기** → 필터 에디터(11) 화면으로 이동
- Ghost: **나중에** → 해당 상태에서 벗어남

### 일러스트 설명

비어 있는 5×5 그리드 프레임 (필터 타일 자리), 가운데 골드 카메라 아이콘 (SF Symbols: `camera.fill`). 그리드 선은 `border/subtle`, 카메라는 `accent`.

### SwiftUI View extension 의사코드

```swift
extension View {
    func emptyMarketplace(onMake: @escaping () -> Void) -> some View {
        overlay {
            if /* 필터 배열이 비어 있음 */ {
                EmptyStateView(
                    illustration: "empty-marketplace",   // SF Symbol or asset
                    headline: "아직 올라온 필터가 없어요",
                    subtext: "첫 메이커가 되어보세요.\n독창적인 필터를 만들고 세상에 선보이세요.",
                    cta: ("필터 만들기", onMake)
                )
            }
        }
    }
}
```

---

## ES-02. 검색 무결과

### 트리거 조건

- 검색어를 입력했으나 서버 응답 결과가 0건
- 적용된 필터(카테고리·가격·정렬) 조합에 맞는 결과 없음

### 헤드라인

> "{{검색어}}"에 맞는 필터가 없어요

### 서브텍스트

> 다른 검색어를 시도하거나\n카테고리에서 둘러볼까요?

### CTA

- Primary: **카테고리 둘러보기** → 마켓 홈(06)으로 이동
- Ghost: **검색 초기화** → 검색창 비우기

### 일러스트 설명

돋보기 아이콘 (`magnifyingglass`) 아래 슬래시 선 (`line.diagonal`). 전체 색조는 `text/tertiary`, 돋보기 원 내부에 `accent` 작은 점. 검색어가 없는 상태의 막힌 느낌을 전달.

### SwiftUI View extension 의사코드

```swift
extension View {
    func emptySearchResults(query: String, onBrowse: @escaping () -> Void, onClear: @escaping () -> Void) -> some View {
        overlay {
            if /* 검색 결과 배열이 비어 있음 && query.isEmpty == false */ {
                EmptyStateView(
                    illustration: "empty-search",
                    headline: ""\(query)"에 맞는 필터가 없어요",
                    subtext: "다른 검색어를 시도하거나\n카테고리에서 둘러볼까요?",
                    cta: ("카테고리 둘러보기", onBrowse),
                    secondaryCta: ("검색 초기화", onClear)
                )
            }
        }
    }
}
```

---

## ES-03. 빈 프로필 (필터 0개)

### 트리거 조건

- 신규 메이커가 아직 필터를 등록하지 않음
- 자신의 프로필 탭에서 "내 필터" 탭을 처음 열었을 때

### 헤드라인

> 아직 만든 필터가 없어요

### 서브텍스트

> 나만의 감성을 담은 첫 필터를 만들어보세요.\n메이커로서의 여정을 시작하는 순간입니다.

### CTA

- Primary: **첫 필터 만들기** → 필터 에디터(11) 화면
- Ghost: **나중에**

### 일러스트 설명

필터 슬라이더 3개가 겹쳐진 선화 (`slider.horizontal.3`), 빈 상태라 흐릿하게 처리(`text/tertiary`). 우측 상단 골드 별 아이콘 하나 — "아직 빛을 발하지 않은 상태" 암시.

> **타인 프로필 방문 시**: 헤드라인을 "{{메이커명}}의 필터가 곧 공개돼요"로 변경, CTA 없음.

### SwiftUI View extension 의사코드

```swift
extension View {
    func emptyProfile(isOwnProfile: Bool, makerName: String = "", onMake: @escaping () -> Void) -> some View {
        overlay {
            if /* filters.isEmpty */ {
                EmptyStateView(
                    illustration: "empty-profile",
                    headline: isOwnProfile
                        ? "아직 만든 필터가 없어요"
                        : "\(makerName)의 필터가 곧 공개돼요",
                    subtext: isOwnProfile
                        ? "나만의 감성을 담은 첫 필터를 만들어보세요.\n메이커로서의 여정을 시작하는 순간입니다."
                        : nil,
                    cta: isOwnProfile ? ("첫 필터 만들기", onMake) : nil
                )
            }
        }
    }
}
```

---

## ES-04. 빈 다운로드

### 트리거 조건

- 사용자가 아직 필터를 구매하거나 무료 다운로드한 적 없음
- 설정(10) 또는 프로필(09)의 "다운로드한 필터" 탭 첫 진입

### 헤드라인

> 다운로드한 필터가 없어요

### 서브텍스트

> 마켓에서 마음에 드는 필터를 찾아보세요.\n다운로드하면 오프라인에서도 사용할 수 있어요.

### CTA

- Primary: **마켓 둘러보기** → 마켓 홈(06)

### 일러스트 설명

아래 방향 화살표(`arrow.down.circle`) 선화. 원 내부는 비어 있는 상태로, 보더만 `border/default`. 화살표는 `accent` 골드. 간결하고 직관적.

### SwiftUI View extension 의사코드

```swift
extension View {
    func emptyDownloads(onBrowse: @escaping () -> Void) -> some View {
        overlay {
            if /* downloadedFilters.isEmpty */ {
                EmptyStateView(
                    illustration: "empty-downloads",
                    headline: "다운로드한 필터가 없어요",
                    subtext: "마켓에서 마음에 드는 필터를 찾아보세요.\n다운로드하면 오프라인에서도 사용할 수 있어요.",
                    cta: ("마켓 둘러보기", onBrowse)
                )
            }
        }
    }
}
```

---

## ES-05. 빈 댓글

### 트리거 조건

- 필터 상세(07) 화면의 댓글 섹션, 아직 댓글이 없음
- 필터 신규 등록 직후 또는 댓글이 전혀 없는 필터

### 헤드라인

> 첫 번째 댓글을 남겨보세요

### 서브텍스트

> 메이커에게 감상을 전해주세요.\n사진과 함께 남기면 더욱 생생하게 전달돼요.

### CTA

- Primary: **댓글 쓰기** → 댓글 입력 필드로 포커스 이동
- CTA 없음 (비로그인 상태): 서브텍스트를 "댓글을 남기려면 로그인이 필요해요."로 대체

### 일러스트 설명

말풍선 두 개 겹침 (`bubble.left.and.bubble.right`) 선화, 내부 비어 있음. 색조 `text/tertiary`. 오른쪽 말풍선 꼬리 부분에 골드 점 하나 — "기다리는 첫 마디" 표현.

### SwiftUI View extension 의사코드

```swift
extension View {
    func emptyComments(isLoggedIn: Bool, onWrite: @escaping () -> Void, onLogin: @escaping () -> Void) -> some View {
        overlay {
            if /* comments.isEmpty */ {
                EmptyStateView(
                    illustration: "empty-comments",
                    headline: "첫 번째 댓글을 남겨보세요",
                    subtext: isLoggedIn
                        ? "메이커에게 감상을 전해주세요.\n사진과 함께 남기면 더욱 생생하게 전달돼요."
                        : "댓글을 남기려면 로그인이 필요해요.",
                    cta: isLoggedIn
                        ? ("댓글 쓰기", onWrite)
                        : ("로그인", onLogin)
                )
            }
        }
    }
}
```

---

## EmptyStateView 공통 컴포넌트 의사코드

```swift
struct EmptyStateView: View {
    let illustration: String         // SF Symbol 이름 또는 asset 키
    let headline: String
    let subtext: String?
    let cta: (String, () -> Void)?
    let secondaryCta: (String, () -> Void)?

    var body: some View {
        VStack(spacing: Sp.xl) {  // 24pt 간격
            Image(systemName: illustration)
                .font(.system(size: 56))
                .foregroundStyle(Color("Accent/Primary"))
                .frame(height: 96)

            VStack(spacing: Sp.xs) {  // 8pt 간격
                Text(headline)
                    .font(.fmHeadline)
                    .foregroundStyle(Color("Text/Primary"))
                    .multilineTextAlignment(.center)

                if let subtext {
                    Text(subtext)
                        .font(.fmBody)
                        .foregroundStyle(Color("Text/Secondary"))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }

            if let (label, action) = cta {
                Button(label, action: action)
                    .buttonStyle(FMPrimaryButtonStyle())
                    .frame(maxWidth: 240)
            }

            if let (label, action) = secondaryCta {
                Button(label, action: action)
                    .buttonStyle(FMGhostButtonStyle())
            }
        }
        .padding(.horizontal, Sp.twoXL)  // 32pt
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

---

## states-catalog.html §1 매핑표

| 명세 ID | states-catalog.html 섹션 | 화면 위치 |
|---|---|---|
| ES-01 빈 마켓플레이스 | §1 Empty States · 마켓플레이스 빈 상태 | 06-marketplace-home (필터 없음) |
| ES-02 검색 무결과 | §1 Empty States · 검색 무결과 | 08-search (결과 없음) |
| ES-03 빈 프로필 | §1 Empty States · 빈 프로필 | 09-profile (필터 0개) |
| ES-04 빈 다운로드 | §1 Empty States · 빈 다운로드 | 10-settings (다운로드 탭) |
| ES-05 빈 댓글 | §1 Empty States · 빈 댓글 | 07-filter-detail (댓글 섹션) |

---

> 관련 문서: [`DESIGN_SYSTEM.md §8 컴포넌트`](./DESIGN_SYSTEM.md) · [`MOTION_SPEC.md §5 스켈레톤`](./MOTION_SPEC.md)
