# moodit · Roadmap (Phase 1 ~ 6)

> **단일 진행 기준**: Product Phase 1~4. Phase 5/6은 후보(범위 외).
> **As of**: 2026-05-10. 원본 진행 추적: [`../../docs/PHASE_ROADMAP_STATUS.md`](../../docs/PHASE_ROADMAP_STATUS.md).
>
> 과거에 사용된 `Phase A/B/C/D/E/F`는 제품 Phase가 아니라 *UI Work Package*다 (`docs/PHASE_ROADMAP_STATUS.md` §1 참고). 본 문서는 Product Phase 1~4 + 후보 5·6만 다룬다.

## 1. 한눈에 보기

| Phase | 주제 | 현재 | 완료 게이트 |
|---|---|---|---|
| **Phase 1** | MVP — Camera / Filters / Market Download | In Progress | TestFlight Internal 가능 |
| **Phase 2** | Filter Editor / Maker Upload | In Progress | 메이커 LUT→.fmpkg→검수 end-to-end |
| **Phase 3** | Auth / Reviews / Social / Search | In Progress | 리뷰·팔로우·검색 실제 API 연결 |
| **Phase 4** | Recommendation / Search Advanced / Android Gate | Not Started | For You 실데이터 + Android ADR |
| Phase 5 (후보) | Safety / Moderation 자동화 | Later | 신고 자동 처리 + 24h SLA |
| Phase 6 (후보) | Monetization (Coin / Pro / Payout) | Later (callable는 Done) | 메이커 출금 실제 KRW 환전 |

> **현재 완료된 Phase는 0개**. Phase 1~3이 동시에 In Progress인 이유: UI 작업(skeleton)이 모든 Phase에 걸쳐 먼저 진행됐고, 이제 *실제 데이터 path / API / 실기기 검증*으로 닫는 단계.

## 2. Phase 1 — MVP Camera & Market Download

**목표**: 사용자가 필터를 찾고, 다운로드하고, 카메라/사진 편집에 적용한다.

### Done
- 카메라 HUD(grid/zoom/flash/aspect/timer), 사진 가져오기·편집, 내장 필터 라이브러리
- 다운로드 진행/완료 후 적용 *로컬 흐름*
- E2E: `AppUITests/PhaseAE2ETests` 5개 통과

### 남은 작업 (P0/P1/P2)
| 우선순위 | 작업 |
|---|---|
| P0 | 실제 `.fmpkg` 다운로드/cache/적용 path (현재 mock fallback) |
| P0 | 실기기 카메라 FPS · thermal · 색상 검증 |
| P0 | 다운로드한 필터를 라이브 카메라 + 사진 편집 렌더러에 실제로 연결 |
| P1 | Firestore/R2/Cloud Functions `/recordUse` 카운터 persistence |
| P1 | Apple/Google 실연결 + 게스트 분기 정리 |
| P1 | Photo save/share 권한 edge case 처리 |
| P2 | TestFlight 준비 (App Store Connect, privacy 라벨, beta) |

### Done = 게이트
- 실제 package 다운로드/캐시 동작
- 카메라/사진 편집 렌더러에 적용 결과 반영
- 실기기 성능 기준 만족(평균 FPS ≥ 30, A14+ ≥ 60)
- 회귀 테스트 안정 통과
- TestFlight Internal 베타 준비 완료

## 3. Phase 2 — Filter Editor & Maker Upload

**목표**: 메이커가 LUT/파라미터 기반으로 필터를 만들고, 초안 저장 후 업로드/검수까지 진행한다.

### Done
- 에디터 UI(parameters/LUT import/draft) + 업로드 UI(cover/tags/TOS/pending)
- mock 상태(`MakerFilterDraft`, `UploadStep`, `MakerFilterStatus`)
- Reviews migration 문서·목업

### 남은 작업
| 우선순위 | 작업 |
|---|---|
| P0 | `.cube` parser 안정화 |
| P0 | LUT bake / parameter bake 결정론적 렌더링 |
| P0 | 에디터 미리보기 ↔ 실제 적용 결과 일치 |
| P1 | `.fmpkg` packaging / manifest builder + 검증 |
| P1 | Draft repository(저장/복구 persistence) |
| P1 | Upload job API(진행률/재개/실패 처리) |
| P2 | 커버 picker / 자동 Before-After 생성 |
| P2 | Moderation pending/rejected 실제 상태 변환 |

### Done = 게이트
- 메이커가 LUT/파라미터 필터를 실제로 만들고
- 미리보기와 적용 결과가 일치하며
- `.fmpkg`가 빌드/검증/저장되고
- 초안→업로드→검수 제출이 backend와 연결된다

## 4. Phase 3 — Auth / Reviews / Social / Search

**목표**: 계정 관리 + 리뷰·팔로우·알림·검색 실제 backend 연결. Comments 중심 UX → Reviews 중심으로 전환 마무리.

### Done
- 계정 삭제·프로필 편집·Universal Link Landing·데이터 내보내기·알림 설정 UI
- 댓글/평점/팔로우/피드 화면 + E2E
- Reviews migration 문서/키/목업

### 남은 작업
| 우선순위 | 작업 |
|---|---|
| P0 | 전체 회귀 테스트 재실행 (`./scripts/test.sh`) |
| P0 | Comments → Reviews Swift route/screen/notification naming 정리 |
| P0 | Social repository/API: follow/review/rating/feed가 실제 source와 연결 |
| P1 | Review persistence(1인 1리뷰, verified download, maker reply) |
| P1 | Follow/block state persistence |
| P1 | 검색 backend (prefix/category/tag/정렬) |
| P1 | Notification resolver / push (APNs/FCM) |
| P2 | Universal Link payload parser → route/apply |
| P2 | Profile 편집/조회 persistence |

### Done = 게이트
- 리뷰/팔로우/알림/검색 모두 실제 API 연결
- Comments→Reviews 용어 정리 완료
- 회귀 테스트 안정 통과

## 5. Phase 4 — Recommendation, Search Advanced, Android Gate

**목표**: 개인화 추천 + 고도화 검색 도입. Android 진출 의사결정.

### 남은 작업
| 우선순위 | 작업 |
|---|---|
| P0 | 검색·추천 기술 ADR (Algolia vs Typesense vs 자체) |
| P0 | 이벤트 로그 schema (recommendation/download/search) |
| P1 | 검색 인덱서 worker (filter/user/tag) |
| P1 | 추천 v1: 인기 + 최신성 가중 |
| P1 | 추천 v2: co-occurrence / item-item |
| P1 | For You feed backend 연결 (mock 제거) |
| P2 | BigQuery export (분석/추천 학습) |
| P2 | **Android 진출 ADR** (Kotlin / Compose MP / iOS only) |

### Done = 게이트
- 검색 p95 + 추천 CTR 측정 가능
- For You가 실제 추천 결과 사용
- Android 진출 ADR 작성 완료(Phase 4 게이트)

## 6. Phase 5 — Safety / Moderation 자동화 (후보)

- 온디바이스 Vision (NSFW/얼굴) 1차 + Cloud Vision SafeSearch 2차
- 신고 임계값 도달 → 자동 검토 큐 + FCM 알림
- 모더레이터 Web Admin
- 24h SLA 모니터링
- App Attest, 인증서 핀닝

## 7. Phase 6 — Monetization (후보)

- IAP 코인 충전 (callable Done)
- Pro 구독 (callable Done)
- 메이커 60% 적립
- 출금: Stripe Connect 통한 KRW 환전 (5,000 코인 임계, KYC, 세무)
- 환불: 7일 정책 (callable Done)
- 닫혀있는 작업: **출금 정산 UI + Stripe Connect onboarding**, **세금 보고서 자동 생성**

## 8. 다음 30일 권장 실행 순서

1. **회귀 테스트 재실행** — `./scripts/test.sh` 결과 baseline 갱신.
2. **Phase 3** Comments → Reviews Swift 마이그레이션 마무리.
3. **Phase 1** 실제 .fmpkg 다운로드/캐시/적용 path 구현.
4. **Phase 1** 실기기 FPS/thermal 측정 (iPhone 12 mini, 13, 15 Pro 최소).
5. **Phase 3** Social/Review repository/API 계약 작성.
6. **Phase 2** `.cube parser → LUT bake → package builder → upload API`.
7. **Phase 4** 검색/추천 기술 ADR 작성.

이유: UI 두께(skeleton)는 충분히 들어왔으므로 이제 *Phase 완료 조건*인 실제 data path / API / 성능 검증으로 전환해야 한다. TestFlight 가능성을 만들려면 Phase 1의 실제 다운로드/적용 경로가 가장 먼저 닫혀야 한다.

## 9. 의사결정 게이트

| 게이트 | 시점 | 결정자 | 결정 내용 |
|---|---|---|---|
| TestFlight Beta 진입 | Phase 1 완료 시 | PM + iOS 리드 | Internal → External 확장 시점 |
| App Store Production | Phase 3 완료 시 | PM + 법무 + iOS 리드 | 모더레이션 자동화 + 개인정보 라벨 검토 |
| Android 진출 | Phase 4 완료 시 | PM + 창립자 | 옵션 A(Kotlin) / B(Compose MP) / C(iOS only) |
| 수익화 활성 | Phase 5 안정 후 | PM + 재무 | Coin 충전 + Pro 동시 활성 vs 단계 활성 |
| Stripe Connect 출금 활성 | Phase 6 후반 | PM + 법무 + 세무 | KYC 운영 SOP 확정 후 |

자세한 마일스톤: [`MILESTONES.md`](./MILESTONES.md)
