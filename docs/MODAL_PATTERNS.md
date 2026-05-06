# moodit — 모달 패턴 가이드

> 버전: v1.2 · 작성일: 2026-05-06
> `mockups/screens/modals/` 4개 화면과 1:1 매핑.
> iOS 17+, SwiftUI+UIKit 기준. 모션 상세는 [`MOTION_SPEC.md §2`](./MOTION_SPEC.md) 참조.

---

## 개요

moodit 에서 사용하는 4종 모달 패턴:

| 패턴 | SwiftUI API | 용도 |
|---|---|---|
| Bottom Sheet | `.sheet` | 부가 정보, 빠른 액션 |
| Action Sheet | `.confirmationDialog` | 옵션 선택 (3~6개) |
| Confirmation Alert | `.alert` | 중요 확인 (파괴적 액션) |
| Share Sheet | `ShareLink` / `UIActivityViewController` | 시스템 공유 |

---

## 사용 결정 기준

모달 종류 결정이 어려울 때 아래 표를 따른다.

| 상황 | 선택 |
|---|---|
| 상세 정보를 보여주거나 빠른 액션이 필요 | Bottom Sheet |
| 3~6개 선택지 중 하나를 고르는 경우 | Action Sheet |
| 파괴적 액션(삭제, 신고)의 확인이 필요 | Confirmation Alert |
| 외부 앱·서비스로 공유하는 경우 | Share Sheet |
| 상황이 여전히 불분명한 경우 | Bottom Sheet (가장 유연) |

**모달이 필요 없는 경우**: 간단한 상태 변경(토글, 즐겨찾기)은 인라인 처리. 정보만 보여준다면 새 화면 push 를 고려.

---

## M-01. Bottom Sheet

> `mockups/screens/modals/bottom-sheet.html`

### 용도

- 필터 상세 요약 정보 표시 (구매 전 미리보기)
- 빠른 액션 패널 (저장, 공유, 신고)
- 부가 설정 (필터 강도, 적용 옵션)
- 메이커 프로필 미리보기

### 구조

```
[Drag Handle — 36×4pt, 가운데 정렬]
[콘텐츠 영역]
  ├── 헤더 (제목 + 닫기 버튼, 선택적)
  ├── 본문
  └── 액션 버튼 (선택적)
[Home Indicator 여백]
```

### 명세

| 속성 | 값 |
|---|---|
| 배경 | `surface/raised (#FFFFFF)`, `border/subtle` 보더 |
| 상단 모서리 | `radius xl (16pt)` |
| Drag handle | 36×4pt, `border/strong (#B8B4A8)`, `radius full` |
| Detent | `.medium` (기본) / `.large` (긴 콘텐츠) |
| 스크림 배경 | `surface/overlay (rgba(15,15,14,0.42))` |
| Dismiss | 스크림 탭, 드래그 다운, 시스템 제스처 |
| 진입 모션 | 350ms spring (MOTION_SPEC §2.2) |

### 접근성

- 포커스는 시트 내부에 trap. 시트 닫힘 시 트리거 요소로 복귀.
- `role="dialog"`, `aria-modal="true"`, `aria-label` 필수.
- VoiceOver: 시트 첫 요소로 자동 포커스 이동.
- Escape 키 (외장 키보드): dismiss.

### SwiftUI 의사코드

```swift
.sheet(isPresented: $showFilterSheet) {
    FilterDetailSheet(filter: selectedFilter)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(16)  // iOS 16.4+
}

struct FilterDetailSheet: View {
    let filter: Filter
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.md) {
                // 필터 미리보기 + 이름 + 메이커
                FilterPreviewRow(filter: filter)
                // 빠른 액션 버튼들
                SheetActionRow(filter: filter)
            }
            .padding(Sp.md)
        }
    }
}
```

---

## M-02. Action Sheet

> `mockups/screens/modals/action-sheet.html`

### 용도

- 사진 저장 옵션 (저장 / 공유 / 삭제)
- 필터 관련 액션 (다운로드 / 신고 / 숨기기)
- 업로드 옵션 선택

### 구조

iOS `.confirmationDialog` 는 하단 그룹 버튼으로 표시된다.

```
[제목 (선택적) — 회색 소형 텍스트]
[그룹 1]
  ├── 액션 1
  ├── 액션 2
  └── 액션 3 (파괴적 — 빨간색)
[취소]
```

### 명세

| 속성 | 값 |
|---|---|
| 옵션 수 | 3~6개. 6개 초과 시 Bottom Sheet로 전환 |
| 파괴적 액션 | 반드시 마지막, `role: .destructive` |
| 취소 | 항상 마지막 독립 그룹 |
| 배경 | 시스템 기본 (iOS `UIAlertController` 스타일) |
| 스크림 | 시스템 처리 |

### 접근성

- 시스템 제공 컴포넌트이므로 기본 접근성 보장.
- `title` 파라미터로 콘텍스트 제공.
- 파괴적 액션에 `.destructive` role 명시.

### SwiftUI 의사코드

```swift
.confirmationDialog(
    "방금 촬영한 사진",
    isPresented: $showActionSheet,
    titleVisibility: .visible
) {
    Button("사진에 저장") { saveToPhotos() }
    Button("공유") { showShareSheet = true }
    Button("삭제", role: .destructive) { deletePhoto() }
    Button("취소", role: .cancel) { }
}
```

### 안티패턴

- 7개 이상 옵션: Bottom Sheet 사용
- 입력 필드 포함: Bottom Sheet 사용 (Action Sheet 는 입력 불가)
- 확인이 필요한 파괴적 액션: Confirmation Alert 추가

---

## M-03. Confirmation Alert

> `mockups/screens/modals/confirmation-alert.html`

### 용도

파괴적이거나 되돌릴 수 없는 액션을 실행 전 사용자에게 한 번 더 확인.

- 필터 삭제
- 계정 탈퇴
- 구매 확인 (선택적)
- 신고 제출

### 구조

```
[제목 — Semibold, 중앙 정렬]
[본문 — 1~2줄, 부연 설명]
[확인 버튼 — 파괴적 색(error) 또는 primary]
[취소 버튼]
```

### 명세

| 속성 | 값 |
|---|---|
| 제목 | 간결하게 — "정말 삭제할까요?" |
| 본문 | 1~2줄. 결과를 명확히 설명 — "삭제한 필터는 복구할 수 없어요." |
| 파괴적 확인 버튼 | `role: .destructive` → 시스템 빨간색 |
| 취소 버튼 | 항상 포함. `role: .cancel` |
| 기본 버튼 | 취소를 기본으로 → 실수 방지 |
| 배경 | 시스템 UIAlertController (`.alert` 스타일) |

### 접근성

- Alert 등장 시 VoiceOver 자동 포커스.
- 취소를 키보드 Enter 기본값으로 설정 (`preferredAction` 미설정 시 자동).
- 파괴적 버튼에 `.destructive` role 명시.

### SwiftUI 의사코드

```swift
.alert(
    "정말 삭제할까요?",
    isPresented: $showDeleteAlert
) {
    Button("삭제", role: .destructive) { deleteFilter() }
    Button("취소", role: .cancel) { }
} message: {
    Text("삭제한 필터는 복구할 수 없어요.")
}
```

### 안티패턴

- 파괴적이지 않은 일반 확인에 Alert 남용: 흐름을 끊음 — 인라인 처리 권장
- 제목에 긴 설명 포함: `message` 파라미터 사용
- 확인 버튼을 기본 포커스로: 실수 방지 원칙 위반
- 너무 자주 사용: 1회 세션 중 2회 이상은 최소화

---

## M-04. Share Sheet

> `mockups/screens/modals/share-sheet.html`

### 용도

- 촬영한 사진 외부 공유 (Instagram, 카카오톡, 메시지 등)
- 필터 링크 공유 (메이커가 자신의 필터 홍보)
- 업로드 이미지 공유

### 구조

iOS 시스템 `UIActivityViewController`. moodit 커스텀 UI 없음.

### 명세

| 속성 | 값 |
|---|---|
| 트리거 | 항상 명시적 사용자 액션 (버튼 탭)으로만 |
| 공유 아이템 | `[UIImage]` / `[URL]` / `[String]` |
| `excludedActivityTypes` | 필요 시 불필요한 액티비티 제외 |
| 완료 처리 | `completionWithItemsHandler` 에서 성공/취소 분기 |

### 접근성

시스템 컴포넌트이므로 기본 접근성 보장. 트리거 버튼에 `accessibilityLabel("공유")` 명시.

### SwiftUI 의사코드

```swift
// ShareLink — iOS 16+ 권장
ShareLink(
    item: capturedImage,
    preview: SharePreview(
        "필터: \(filter.name)",
        image: Image(uiImage: capturedImage)
    )
) {
    Label("공유", systemImage: "square.and.arrow.up")
}

// UIActivityViewController (이미지 + URL 복합 공유)
func shareFilter(_ filter: Filter, image: UIImage) {
    let items: [Any] = [image, filter.shareURL as Any]
    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    vc.excludedActivityTypes = [.assignToContact, .addToReadingList]
    present(vc, animated: true)
}
```

---

## 공통 접근성 체크리스트

모든 모달에 적용:

| 항목 | 설명 |
|---|---|
| Focus trap | 모달 열린 동안 포커스는 모달 내부에 갇힘 |
| 복귀 포커스 | 닫힘 후 트리거 버튼으로 포커스 복귀 |
| Escape 키 | 외장 키보드 Escape → dismiss (시스템 기본 처리) |
| Scrim 탭 dismiss | Bottom Sheet 한정. Alert/Action Sheet 는 scrim 탭으로 dismiss 불가 |
| `role="dialog"` | HTML 목업에서 aria role 명시 |
| `aria-modal="true"` | 스크린 리더가 배경 콘텐츠 무시하도록 |
| `aria-labelledby` | 제목 요소와 연결 |
| VoiceOver 첫 포커스 | 모달 첫 의미 있는 요소로 자동 이동 |

---

## 안티패턴

| 안티패턴 | 대안 |
|---|---|
| 모달 위에 모달 (중첩) | 두 번째 요청은 첫 번째 모달 내에서 처리하거나 순서 변경 |
| Alert 남용 (확인 아닌 정보 전달) | 토스트 / 배너 사용 |
| Action Sheet 에 7개+ 옵션 | Bottom Sheet 로 전환 |
| 비파괴적 액션에 Confirmation Alert | 인라인 처리 or 토스트 |
| 자동(사용자 액션 없이) Share Sheet 호출 | 항상 명시적 사용자 탭으로만 |
| 너무 좁은 tap target | 모달 버튼 최소 44pt 유지 |
| dismiss 방법 불명확 | 항상 명시적 닫기 경로 제공 (취소, X 버튼, 드래그) |

---

## 화면 ↔ 명세 매핑

| 파일명 | 패턴 | 시나리오 |
|---|---|---|
| `modals/bottom-sheet.html` | M-01 Bottom Sheet | 마켓 필터 빠른 정보 + 액션 |
| `modals/action-sheet.html` | M-02 Action Sheet | 촬영 사진 저장/공유/삭제 |
| `modals/confirmation-alert.html` | M-03 Confirmation Alert | 필터 삭제 확인 |
| `modals/share-sheet.html` | M-04 Share Sheet | 사진 또는 필터 링크 공유 |

---

> 관련 문서: [`MOTION_SPEC.md §2.2 Modal Sheet`](./MOTION_SPEC.md) · [`DESIGN_SYSTEM.md §8 컴포넌트`](./DESIGN_SYSTEM.md) · [`DESIGN_TOKENS.json`](./DESIGN_TOKENS.json)
