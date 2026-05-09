# Firestore Triggers

> 단일 소스: `functions/src/triggers/index.ts`
> 모든 트리거는 `asia-northeast3` 리전, gen 2 (`firebase-functions/v2/firestore`).
> 책임: 카운터 fan-out, 통계 재계산, 향후 알림/검색 인덱싱.

---

## 1. 트리거 일람

| 함수 | 이벤트 | 문서 경로 | 책임 |
|---|---|---|---|
| `onFilterPublished` | onUpdate | `/filters/{filterId}` | status 전이 `* → published` 감지 (현재 stub — TODO) |
| `onReportCreated` | onCreate | `/filters/{filterId}/reports/{reportId}` | 신고 카운터 + 모더레이터 큐 라우팅 (현재 stub — TODO) |
| `onFollowCreated` | onCreate | `/follows/{edgeId}` | followerCount/followingCount 동시 +1 |
| `onFollowDeleted` | onDelete | `/follows/{edgeId}` | followerCount/followingCount 동시 -1 |
| `onReviewCreated` | onCreate | `/filters/{filterId}/reviews/{reviewId}` | reviewCount + ratingAvg 재계산 |
| `onReviewUpdated` | onUpdate | `/filters/{filterId}/reviews/{reviewId}` | stars 또는 status 변경 시 재계산 |
| `onReviewDeleted` | onDelete | `/filters/{filterId}/reviews/{reviewId}` | reviewCount + ratingAvg 재계산 |
| `onSampleCreated` | onCreate | `/filters/{filterId}/samples/{sampleId}` | sampleCount +1 |
| `onSampleDeleted` | onDelete | `/filters/{filterId}/samples/{sampleId}` | sampleCount -1 |
| `onFilterLikeCreated` | onCreate | `/filters/{filterId}/likes/{uid}` | likeCount +1 |
| `onFilterLikeDeleted` | onDelete | `/filters/{filterId}/likes/{uid}` | likeCount -1 |

---

## 2. 상세 동작

### 2.1 `onFilterPublished` (TODO)
- 트리거 조건: `before.status !== "published" && after.status === "published"`.
- 계획된 작업:
  1. `/users/{ownerUid}.filterCount` `FieldValue.increment(1)`
  2. 메이커에게 FCM 발송 (승인 알림)
  3. 검색 인덱스(Firestore copy doc 또는 Algolia, Phase 4) 반영

### 2.2 `onReportCreated` (TODO)
- 계획된 작업:
  1. `/filters/{filterId}.reportCount` 증가
  2. 임계치 도달 시 `flaggedForReview = true` 세팅
  3. 옵션: Cloud Vision SafeSearch 호출

### 2.3 `onFollowCreated` / `onFollowDeleted`
- 입력 문서 키: `actorUid`, `targetUid` (둘 다 string).
- 가드: `actorUid !== targetUid` (자기 팔로우 무시).
- 양쪽 사용자 문서를 `Promise.all`로 동시 머지 set:
  - `users/{actorUid}.followingCount += ±1`
  - `users/{targetUid}.followerCount += ±1`

### 2.4 `recalculateReviewStats(filterId)`
- 호출 트리거: review create / update(stars or status change) / delete.
- 동작:
  1. `/filters/{id}/reviews` 중 `status ∈ ["active", "published"]` 전부 read.
  2. `totalStars` 합산 + `reviewCount` = snapshot size.
  3. `ratingAvg = round(total/count * 10) / 10` (소수 첫째자리, count==0 → null).
  4. `/filters/{id}` 머지 set.

> **주의**: 현재 단순 재계산이라 리뷰가 매우 많은 필터에 대해서는 비용 부담. Phase 후반부 샤드 카운터 또는 누적 증감 로직으로 전환 검토.

### 2.5 `onSampleCreated/Deleted`, `onFilterLikeCreated/Deleted`
- 단순 `FieldValue.increment(±1)` + `updatedAt`.
- 트랜잭션 미사용 — `increment`는 commit 시 서버에서 atomic 적용.

---

## 3. 호출 방향성

| 클라이언트 직접 쓰기 | 트리거 fan-out | 함수 내부 처리 |
|---|---|---|
| `follows`, `likes` (own uid 한정) | followerCount, likeCount, sampleCount, reviewCount/ratingAvg | useCount, helpfulCount, reportCount, balance/ledger |
| `users/{uid}/favorites`, `savedFilters`, `collections`, `captures`, `editorDrafts`, `makerDrafts`, `feedActions`, `reviewHelpful`, `devices` | (개인 데이터, fan-out 없음) | — |

---

## 4. 멱등성 / 중복 트리거

Firebase 트리거는 **at-least-once** 보장 — 동일 이벤트가 재시도될 수 있다.
- `FieldValue.increment(±1)`은 **멱등하지 않음** (중복 호출 시 카운터 누적).
- 현 구현은 정확한 중복 방지를 하지 않으므로, 운영 중 카운터 드리프트 발생 시 주기적인 reconcile 작업이 필요할 수 있음. (RC: TODO — review 트리거처럼 전체 재계산 패턴이 안전하나 비용↑.)

---

## 5. 미연결/계획됨 (Phase 후반부)

- FCM 알림 fan-out (`onFilterPublished`, 신고 처리, 새 리뷰)
- 검색 인덱싱 (Algolia 또는 Firestore copy)
- Cloud Vision SafeSearch (NSFW 게이트)
- 메이커 earnedCoins fan-out (구매 트랜잭션 트리거)
- Pro 자동 코인 적립 (`pro_grant`) — 월 1회 스케줄러
