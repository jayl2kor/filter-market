# moodit — Comments → Reviews Migration (Phase 2)

> 작성: 2026-05-07 · 상태: Phase 2 채택 · 옵션: A (리뷰 + 메이커 답글 1단계)
>
> moodit 의 소셜 레이어를 Instagram 패턴 (자유 댓글 + @mention + 답글 트리) 에서
> App Store 패턴 (별점 리뷰 + 메이커 1회 답글) 으로 재정의한다.
> 본 문서는 결정 배경, 디자인/카탈로그/코드 영향, 단계별 마이그레이션 절차를 정의한다.

---

## 1. 결정 배경

### 1.1 문제 인식

기존 `mockups/screens/23-comments-list.html` 는 다음 패턴을 사용:
- 자유 텍스트 댓글
- 답글 트리 + `@mention`
- heart count
- typing indicator

이는 **Instagram / TikTok 의 소셜 미디어 컨벤션**이다. moodit 의 정체성 (`BRAND.md`, `DESIGN_PRINCIPLES.md`) 은 "갤러리 벽 / 편집자의 손맛 / 절제된 골드" 인 마켓플레이스 — 두 정체성이 충돌한다.

### 1.2 인접 마켓플레이스 컨벤션

| 플랫폼 | 자유 댓글? | 대신 사용하는 패턴 |
|---|---|---|
| App Store | ❌ | 별점 리뷰 + 개발사 1회 답글 |
| Etsy | ❌ | 리뷰 + Q&A (구매 전 질문) |
| Apple Music / Spotify | ❌ | 좋아요 + 큐레이션 + 플레이리스트 |
| Patreon | ⚪ (창작자 게시물 한정) | 후원 + 멤버십 |
| Instagram / TikTok | ✅ 메인 기능 | (소셜 미디어가 본질) |

moodit 은 App Store + Etsy + Pinterest 자리에 가까우므로 자유 댓글이 부적합.

### 1.3 채택 옵션

옵션 검토:
- **옵션 A** — 리뷰 + 메이커 1회 답글 (App Store 모델) ← **채택**
- 옵션 B — 리뷰 + 작품 월 (Pinterest + App Store 하이브리드) — Phase 3 후보
- 옵션 C — 댓글 reframe — 본질 변하지 않음, 기각

### 1.4 옵션 A 채택 근거

1. **모더레이션 부담 ↓** — 자유 댓글의 1/10 수준. 작은 팀이 운영 가능.
2. **마켓 정체성 강화** — `DESIGN_PRINCIPLES.md` 의 절제 톤과 정합.
3. **메이커 보호** — 별점 분포로 비방/스팸 흡수, 답글 1회로 일대일 응대.
4. **i18n 부담 ↓** — 한↔영 자유 채팅 섞임 / 번역 부담 ↓.
5. **이미 절반 구현됨** — `mockups/screens/24-rating-form.html` + `RatingFormScreen` 이 핵심 형태와 일치. `Comments` 를 통합하면 됨.
6. **Phase 3 확장 여지** — 마켓 신뢰 형성 후 옵션 B (작품 월) 추가 가능.

---

## 2. 새로운 Review 시스템 정의

### 2.1 Review 모델

```
Review
├── id: UUID
├── filterId: Filter.ID
├── authorId: User.ID
├── authorHandle: String  (e.g. "@minji.lab")
├── authorAvatar: URL?
├── stars: Int (1...5)
├── body: String (앱 입력 제한 280자, 서버/Rules 상한 500자)
├── photoUrl: URL? (선택 — 이 필터로 찍은 사진 1장)
├── intensity: Int? (선택 — 0...100, 사용한 강도)
├── lightingTag: LightingTag? (선택 — 카페 / 야외 / 실내 / 야경)
├── createdAt: Date
├── helpfulCount: Int
├── isVerifiedDownload: Bool  (다운로드 후 작성한 경우 true)
└── makerReply: MakerReply?  (옵션, 메이커당 1회)
    ├── body: String (최대 200자)
    └── createdAt: Date
```

### 2.2 작성 규칙

- **다운로드 후만 작성 가능** — `submitReview` callable이 `savedFilters`, `entitlements`, active Pro 상태를 검증하고 `isVerifiedDownload = true`로 작성.
- **1인 1리뷰** — 수정 가능, 삭제 가능.
- **별점 필수**, 본문 / 사진 / 강도 / 조명 태그 모두 선택.
- **메이커 답글 1회** — 자기 자신은 리뷰 작성 불가.
- **모더레이션** — flag 시 검수 큐로.

### 2.3 표시 규칙

- 필터 상세 화면 (07) 에 평균 별점 + "리뷰 N 개" 진입점.
- 리뷰 리스트 (23) 에 별점 분포 막대 + 정렬 (도움됨 / 최신 / 별점높음 / 별점낮음).
- 각 리뷰 카드: 별점 / 사용자 / 본문 + (있으면) 사진 + 강도/조명 태그 + 메이커 답글 + 헬프풀 버튼.

---

## 3. 영향 분석

### 3.1 폐기 / 변경

| 항목 | 변경 | 위치 |
|---|---|---|
| `mockups/screens/23-comments-list.html` | 폐기 (참조 유지, deprecated 표시) | `mockups/` |
| `mockups/screens/23b-comments-compose.html` | 폐기 | `mockups/` |
| `mockups/en/23-...` | 신규 EN 버전은 새 review 화면으로만 작성 | `mockups/en/` |
| `Localizable.xcstrings` `comments.*` 키 | deprecation 표시, `reviews.*` 추가 | catalog |
| `AppRoute.comments(filterId:)` | rename `reviews(filterId:)` | Swift (Phase 2 코드 작업) |
| `AppRoute.commentCompose(filterId:)` | rename `reviewCompose(filterId:)` | Swift |
| `CommentsListScreen` (placeholder) | rename `ReviewsListScreen` | Swift |
| `RatingFormScreen` (mockup 24) | 흡수 → `ReviewComposeScreen` 으로 통합 | Swift |
| Notifications 카테고리 "댓글" | "리뷰" 로 rename | xcstrings + UI |
| `notifications.category.comments` 키 | rename `reviews` 또는 alias | xcstrings |

### 3.2 신규 추가

| 항목 | 위치 |
|---|---|
| `mockups/screens/23-reviews-list.html` | 마켓 (KO) |
| `mockups/screens/23b-review-compose.html` | 마켓 (KO) |
| `mockups/en/23-reviews-list.html` | 마켓 (EN) |
| `mockups/en/23b-review-compose.html` | 마켓 (EN) |
| `Localizable.xcstrings` — `reviews.*` 도메인 (~30 키) | catalog |
| `docs/REVIEWS_MIGRATION.md` | 본 문서 |

### 3.3 24 Rating Form 처리

`mockups/screens/24-rating-form.html` 은 이미 별점 + 280자 + 태그 패턴을 가지고 있어 옵션 A 의 70% 구현. 다음과 같이 통합:

- mockup 24 → `23b-review-compose` 의 sub-pattern 으로 흡수.
- `AppRoute.rating(filterId:)` 라우트는 deprecated, `reviewCompose(filterId:)` 로 통합.
- 기존 mockup 24 는 **참조 보존** (작은 모달 변형 시 재활용 가능).

---

## 4. 마이그레이션 단계

### Phase 2.1 — Design (이번 작업)

- [x] 결정 문서 작성 (본 문서)
- [ ] `23-reviews-list.html` (KO + EN) 신규 작성
- [ ] `23b-review-compose.html` (KO + EN) 신규 작성
- [ ] `Localizable.xcstrings` — `reviews.*` 도메인 추가, `comments.*` deprecated 표시
- [ ] `DESIGN_LOG.md` / `I18N_MIGRATION.md` 갱신
- [ ] EN index 갤러리 갱신

### Phase 2.2 — Code (별도 PR)

- [ ] `AppRoute` rename: `comments` → `reviews`, `commentCompose` → `reviewCompose`
- [ ] `CommentsListScreen` → `ReviewsListScreen` rename + 신규 구현
- [ ] `CommentComposeScreen` → `ReviewComposeScreen` rename + 신규 구현
- [ ] Notifications 카테고리 라벨 갱신
- [ ] 기존 `RatingFormScreen` 코드는 `ReviewComposeScreen` 의 inner pattern 으로 통합
- [ ] 호출처 (FilterDetailScreen 의 "댓글" 링크 등) 수정

### Phase 2.3 — Cleanup

- [ ] `mockups/screens/23-comments-list.html` / `23b-comments-compose.html` deprecate 마킹 (파일 유지, README 에서 안내)
- [ ] `Localizable.xcstrings` 에서 `comments.*` 키 완전 제거 (release N+1)
- [ ] `mockups/screens/24-rating-form.html` README 업데이트 (review compose 의 sub-pattern 으로 흡수됨 명시)

---

## 5. 마이그레이션 부작용 / 위험

| 위험 | 영향 | 완화 |
|---|---|---|
| 기존 사용자가 댓글 데이터 잃음 | M | MVP 출시 전이라 production data 없음 |
| 메이커가 답글 못 다는 미묘한 제약 (1회 한정) | L | 답글 수정 가능. 메이커가 추가 의견 있으면 새 메이커 게시물로 |
| 자유 채팅 욕구 충족 안 됨 | L | Phase 3 작품 월에서 좋아요 / 큐레이션으로 보완 |
| "Q&A" 가 별도 필요한가? | M | Phase 3 검토. 일단 리뷰 본문에 질문 가능, 메이커 답글로 응대 |
| 별점 dispersion 부족 (모두 5점) | M | 별점 강제 정렬 필터 (도움됨 우선), 1~3 별점 유도 카피 |

---

## 6. 영어 톤 가이드 (추가)

- "리뷰" → "Review"
- "메이커 답글" → "Reply from maker" / "Maker's reply"
- "도움이 됐어요" → "Helpful"
- "검증된 다운로드" → "Verified download"
- "사용 강도" → "Used at X% intensity"
- "조명 태그" — Café / Outdoor / Indoor / Night

---

## 7. 관련 문서

- [`DESIGN_LOG.md`](./DESIGN_LOG.md) — 디자인 보강 로그
- [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md) — v1.1 디자인 시스템
- [`I18N_MIGRATION.md`](./I18N_MIGRATION.md) — i18n 가이드
- [`PRD.md`](./PRD.md) — 페르소나 / KPI
- [`SYSTEM_DESIGN.md`](./SYSTEM_DESIGN.md) — 도메인 모델 (review 타입 추가 필요)
- [`MODAL_PATTERNS.md`](./MODAL_PATTERNS.md) — 리뷰 작성 모달 패턴
- 기존 mockups: `mockups/screens/24-rating-form.html` (review compose 의 prior art)
