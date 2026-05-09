# Firestore Schema

> 단일 소스: `firestore.rules`, `firestore.indexes.json`, `functions/src/types/*.ts`, `functions/src/http/*.ts`
>
> 본 문서는 Firestore 컬렉션 트리, 문서 스키마, 보안 룰 요약, 인덱스를 정리한다.
> Firebase Storage는 사용하지 않으며(`storage.rules`는 전체 deny), 미디어는 Cloudflare R2 객체 키 + 공개 URL을 Firestore에 저장한다.

---

## 1. 컬렉션 트리

```
/filters/{filterId}                                — 필터 메타 (root)
  /reviews/{authorUid}                             — 1인 1건 리뷰 (key=uid로 강제)
    /reports/{auto}                                — 리뷰 신고
  /samples/{sampleId}                              — 사용자 업로드 샘플
  /uses/{uid}                                      — recordUse 쿨다운 트래커 (server-only)
  /likes/{uid}                                     — 좋아요 edge
  /reports/{auto}                                  — 필터 신고
  /moderation/{auto}                               — 모더레이션 결정 로그 (types/moderation.ts)

/users/{uid}                                       — 프로필 + 카운터
  /savedFilters/{filterId}                         — 라이브러리 저장
  /favorites/{filterId}                            — 즐겨찾기
  /collections/{collectionId}                      — 사용자 컬렉션
  /captures/{captureId}                            — 카메라 캡처 메타
  /exportRequests/{requestId}                      — GDPR export 요청
  /makerDrafts/{draftId}                           — 메이커 드래프트
  /editorDrafts/{draftId}                          — 에디터 드래프트
  /feedActions/{filterId}                          — 피드 액션 기록
  /reviewHelpful/{filterId_reviewId}               — 도움됨 edge (멱등성)
  /wallet/{doc}                                    — 코인 잔액 ("balance")
  /walletLedger/{entryId}                          — 코인 거래 원장
  /entitlements/{filterId}                         — 필터 엔터블먼트
  /proStatus/{doc}                                 — Pro 상태 ("status")
  /refundRequests/{reqId}                          — 환불 요청
  /notifications/{notifId}                         — 푸시 알림 inbox
  /devices/{deviceId}                              — FCM 토큰
  /reports/{auto}                                  — 사용자 신고

/follows/{actorUid_targetUid}                      — 팔로우 edge
/blocks/{actorUid_targetUid}                       — 차단 edge (private)
/handles/{handle}                                  — 핸들 클레임 인덱스

/wallets/{uid}                                     — (legacy/types) read-only
/transactions/{txId}                               — (legacy/types) read-only
/payouts/{payoutId}                                — (Phase 6 placeholder)
/topupIntents/{intentId}                           — read/write 모두 deny

/walletReceipts/{originalTransactionId}            — IAP 영수증 멱등 키 (server-only)
/proReceipts/{originalTransactionId}               — Pro 구독 영수증 (server-only)

/config/{doc}                                      — 공개 설정 (clients read)
/_ratelimit/{bucket:key}                           — 레이트리밋 윈도우 (server-only)
```

---

## 2. 핵심 도큐먼트 스키마

### 2.1 `/filters/{id}`
```ts
{
  authorUid: string,                       // 작성자 uid (생성 시 기록)
  author?: { uid?: string, displayName?: string },
  title: string,
  description?: string,
  category: string,
  tags: string[],
  status: "uploading" | "pending_review_pre" | "pending_review"
        | "approved" | "rejected" | "taken_down",
  version: string,                          // semver, default "0.0.1"
  packageBytes: number,
  objectKey: string,                        // R2 키: filters/{uid}/{filterId}.fmpkg
  sha256?: string|null,                     // uploadFinalize 시점 R2 HEAD에서 추출
  signatureSampleURL?: string|null,
  priceCoins: 0|30|50|80|120,               // pricing.ts 화이트리스트
  coverURL?: string|null,
  useCount: number,                         // recordUse 트랜잭션 증감
  downloadCount?: number,
  ratingAvg?: number|null,                  // recalculateReviewStats가 갱신
  reviewCount: number,
  likeCount: number,                        // onFilterLikeCreated/Deleted가 fan-out
  sampleCount: number,                      // onSampleCreated/Deleted가 fan-out
  reportCount?: number,
  flaggedForReview?: boolean,
  tosOriginal?: boolean, tosPolicy?: boolean, tosCommercial?: boolean,
  uploadedAt?: Timestamp,
  submittedAt?: Timestamp,
  publishedAt?: Timestamp,
  rejectedAt?: Timestamp,
  rejectionReason?: string,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 2.2 `/filters/{id}/reviews/{authorUid}`
```ts
{
  filterId: string,                         // 부모와 동일
  authorUid: string,                        // 문서 ID와 일치 (rules에서 강제)
  authorHandle: string,                     // "@..." 표기
  authorDisplayName?: string,
  authorName?: string,
  status: "active" | "published" | "hidden" | "removed",
  stars: 1..5,                              // int
  body: string,                             // 1..500
  photoUrl?: string|null,
  photoObjectKey?: string,
  intensity?: 0..100,
  lightingTag?: string,
  isVerifiedDownload: boolean,              // 생성 시 hasReviewEntitlement 결과
  helpfulCount: number,                     // markReviewHelpful이 ±1
  flagCount?: number,
  reportCount?: number,
  makerReply?: { body: string, createdAt: Timestamp } | null,
  createdAt: Timestamp,
  updatedAt?: Timestamp
}
```

**불변/조건**:
- 생성 시 `helpfulCount: 0`, `makerReply: null|undefined`.
- 작성자 update 허용 키: `stars`, `body`, `photoUrl`, `intensity`, `lightingTag`, `updatedAt`.
- `helpfulCount`는 누구든 ±1 (트랜잭션 가드 X — 클라 토글은 `users/{uid}/reviewHelpful/{filterId_reviewId}`로 멱등).
- `makerReply`는 필터 작성자만, 1회만 첨부 가능.

### 2.3 `/filters/{id}/samples/{sampleId}`
```ts
{
  id: string,
  kind: "user" | "official",
  authorUid: string,
  categoryHint?: string,
  coverURL: string,                         // R2 public URL
  thumbnailURL?: string,
  objectKey: string,                        // samples/{filterId}/{uid}/...
  featured: boolean,
  status?: "active" | "hidden" | "removed",
  createdAt: Timestamp
}
```

### 2.4 `/users/{uid}`
```ts
{
  handle?: string,                          // setHandle이 갱신
  displayName?: string,
  bio?: string,
  website?: string,
  avatarUrl?: string,
  avatarVariant?: 0..64,
  avatarObjectKey?: string,
  photoURL?: string,
  makerPageVisible?: boolean,
  photoSharingAllowed?: boolean,
  isMaker?: boolean,
  isModerator?: boolean,                    // role 클레임 미러 (display 용)
  filterCount?: number,                     // onFilterPublished (TODO)
  followerCount?: number,                   // onFollowCreated/Deleted
  followingCount?: number,
  reportCount?: number,
  deletedAt?: Timestamp,                    // soft delete 마커
  createdAt?: Timestamp,
  updatedAt: Timestamp
}
```

### 2.5 `/users/{uid}/wallet/balance`
```ts
{ value: number, updatedAt: Timestamp }
```
> **클라이언트 직접 쓰기 차단**. 모든 잔액 변경은 `purchaseFilter` / `creditCoinsFromIAP` 트랜잭션 경유.

### 2.6 `/users/{uid}/walletLedger/{entryId}`
```ts
{
  kind: "purchase" | "topup" | "earn" | "withdraw" | "refund" | "bonus" | "pro_grant",
  amount: number,                           // signed (+credit / -debit)
  relatedItemTitle?: string,
  relatedFilterId?: string,
  relatedTransactionId?: string,
  createdAt: Timestamp
}
```

### 2.7 `/users/{uid}/entitlements/{filterId}`
```ts
{
  filterId: string,
  grantedAt: Timestamp,
  pricePaid: number
}
```

### 2.8 `/users/{uid}/proStatus/status`
```ts
{
  active: boolean,
  productId: "com.jayl2kor.moodit.pro.monthly" | "com.jayl2kor.moodit.pro.yearly",
  expiresAt?: number|null,                  // epoch ms
  revokedAt?: number|null,
  updatedAt: Timestamp
}
```

### 2.9 `/handles/{handle}`
```ts
{ uid: string, claimedAt: Timestamp }
```

### 2.10 `/walletReceipts/{originalTransactionId}` (server-only)
```ts
{
  uid: string,
  productId: string,
  amount: number,
  createdAt: Timestamp
}
```

### 2.11 `/proReceipts/{originalTransactionId}` (server-only)
```ts
{
  uid: string,
  productId: string,
  active: boolean,
  expiresDate?: number|null,
  revocationDate?: number|null,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 2.12 `/follows/{actorUid_targetUid}` / `/blocks/{...}`
```ts
{ actorUid: string, targetUid: string, createdAt: Timestamp }
```

### 2.13 `/users/{uid}/devices/{deviceId}`
```ts
{
  fcmToken: string,
  platform: "ios",                          // 룰에서 강제
  deviceId: string,                         // 문서 ID와 일치
  // 기타 메타 (modelName, appVersion, locale 등 — 클라가 자유로 추가)
}
```

---

## 3. 보안 룰 요약 (`firestore.rules`)

### 3.1 헬퍼 함수
| 함수 | 의미 |
|---|---|
| `isAuthenticated()` | `request.auth != null` |
| `isOwner(uid)` | 인증 + `request.auth.uid == uid` |
| `role()` | `request.auth.token.role` (없으면 `"user"` / 비인증은 `"guest"`) |
| `isModerator()` | role ∈ {`moderator`, `admin`} |
| `isAdmin()` | role == `admin` |
| `isFilterMaker(filterId)` | 인증 + `/filters/{filterId}.authorUid == auth.uid` |
| `hasReviewEntitlement(filterId)` | `savedFilters/{filterId}` ∨ `entitlements/{filterId}` ∨ `proStatus/status.active==true` |

### 3.2 컬렉션별 정책

| 경로 | read | create | update | delete |
|---|---|---|---|---|
| `/filters/{id}` | public | ❌ | ❌ | ❌ |
| `/filters/{id}/reviews/{uid}` | public | owner + validReviewCreate | (a) self stars/body / (b) anyone helpfulCount±1 / (c) maker attaches reply | self OR moderator |
| `/filters/{id}/uses/{uid}` | self | ❌ (server only) | ❌ | ❌ |
| `/filters/{id}/likes/{uid}` | public | self + validLikeCreate | ❌ | self |
| `/filters/{id}/samples/{id}` | public | ❌ (server only) | ❌ | ❌ |
| `/follows/{edge}` | authed | self (`actorUid==auth.uid`) | ❌ | self |
| `/blocks/{edge}` | self | self | ❌ | self |
| `/handles/{handle}` | public | ❌ (server only) | ❌ | ❌ |
| `/users/{uid}` | self | ❌ | ❌ | ❌ |
| `/users/{uid}/savedFilters/{id}` | self | self + filterId match | self | self |
| `/users/{uid}/favorites/{id}` | self | self + filterId match | self | self |
| `/users/{uid}/collections/{id}` | self | self + 키 화이트리스트 + 길이/타입 검증 | 동일 | self |
| `/users/{uid}/captures/{id}` | self | self + 키 화이트리스트, source==`"camera"` | ❌ | self |
| `/users/{uid}/exportRequests/{id}` | self | self + status==`"requested"` + format ∈ {JSON, CSV} | ❌ | ❌ |
| `/users/{uid}/makerDrafts/{id}` | self | self + status ∈ {draft,pending,rejected,live} | self | self |
| `/users/{uid}/editorDrafts/{id}` | self | self | self | self |
| `/users/{uid}/feedActions/{id}` | self | self | self | self |
| `/users/{uid}/reviewHelpful/{edge}` | self | self + (filterId, reviewId) string | ❌ | self |
| `/users/{uid}/wallet/{doc}` | self | ❌ | ❌ | ❌ |
| `/users/{uid}/walletLedger/{id}` | self | ❌ | ❌ | ❌ |
| `/users/{uid}/entitlements/{id}` | self | ❌ | ❌ | ❌ |
| `/users/{uid}/proStatus/{doc}` | self | ❌ | ❌ | ❌ |
| `/users/{uid}/refundRequests/{id}` | self | ❌ | ❌ | ❌ |
| `/users/{uid}/notifications/{id}` | self | ❌ | ❌ | ❌ |
| `/users/{uid}/devices/{id}` | self | self + platform==`"ios"` + deviceId match | self | self |
| `/wallets/{uid}` | self | ❌ | ❌ | ❌ |
| `/transactions/{id}` | self (`uid == auth.uid`) | ❌ | ❌ | ❌ |
| `/payouts/{id}` | self | ❌ | ❌ | ❌ |
| `/topupIntents/{id}` | ❌ | ❌ | ❌ | ❌ |
| `/config/{id}` | public | ❌ | ❌ | ❌ |
| `/{**}` (default) | ❌ | ❌ | ❌ | ❌ |

### 3.3 리뷰 검증 함수
- **validReviewCreate**: 필수 키 모두 보유 + filterId/authorUid 일치 + entitlement 보유 + 메이커 아님 + stars 1..5 int + body 1..500 + intensity 0..100 (옵션) + helpfulCount==0 + makerReply 없음.
- **validReviewSelfUpdate**: 변경 가능 키만 변경 (`stars`, `body`, `photoUrl`, `intensity`, `lightingTag`, `updatedAt`) + stars 1..5 + body 1..500.
- **validHelpfulChange**: `helpfulCount`만 변경 + `±1` 정확히.
- **validMakerReplyAttach**: `makerReply`만 변경 + 기존이 null + 새 값 키 `body, createdAt` + body 1..200 + 호출자 == 필터 메이커.

---

## 4. 인덱스 (`firestore.indexes.json`)

```jsonc
[
  // 1. 사용량 정렬 (필터 마켓 인기순)
  { fields: ["status ASC", "useCount DESC"] },
  // 2. 최신순
  { fields: ["status ASC", "createdAt DESC"] },
  // 3. 메이커 페이지 (해당 메이커의 필터 최신순)
  { fields: ["authorUid ASC", "createdAt DESC"] },
  // 4. 카테고리 + 최신
  { fields: ["status ASC", "category ASC", "createdAt DESC"] }
]
```

> 필요 시 컬렉션 그룹 쿼리/추가 인덱스는 `firestore.indexes.json`에 추가하고 `firebase deploy --only firestore:indexes`로 배포.

---

## 5. 카운터 일관성 (Trigger fan-out)

| 카운터 | 원천 이벤트 | 트리거 함수 |
|---|---|---|
| `filters/{id}.likeCount` | `likes/{uid}` create/delete | `onFilterLikeCreated/Deleted` |
| `filters/{id}.sampleCount` | `samples/{id}` create/delete | `onSampleCreated/Deleted` |
| `filters/{id}.reviewCount` + `ratingAvg` | `reviews/{uid}` create/update/delete | `onReviewCreated/Updated/Deleted` (전체 재계산) |
| `users/{uid}.followerCount/followingCount` | `follows/{edge}` create/delete | `onFollowCreated/Deleted` |
| `filters/{id}.useCount` | `recordUse` 트랜잭션 (트리거 X — 함수 내부에서 처리) | — |

> ⚠️ `helpfulCount`, `reportCount`는 함수가 직접 `FieldValue.increment(±1)` 처리. 트리거 미경유.
